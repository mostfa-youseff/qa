// wrapper/llama_c_api.cpp
// Updated to match recent llama.cpp public API changes
// Kept the original wrapper behaviour and public C functions, but migrated
// to the modern llama_* names where applicable.

#include "llama.h"
#include <string>
#include <unordered_map>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <mutex>
#include <memory>
#include <chrono>

extern "C" {

// forward-declare llama_eval to avoid "not declared" compile errors
int llama_eval(struct llama_context * ctx, const llama_token * tokens, int n_tokens, int n_past, int n_threads);

// opaque handle type
typedef void* LLAMA_HANDLE;

struct llama_wrapper_handle {
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    std::string model_path;
    int n_ctx = 0;
    std::chrono::steady_clock::time_point loaded_at;
};

// global cache
static std::unordered_map<std::string, llama_wrapper_handle*> g_models;
static std::mutex g_models_mutex;

// last error buffer
static thread_local std::string g_last_error;

static int set_last_error_and_return(const char* msg, int code = -1) {
    g_last_error = msg ? msg : "unknown error";
    return code;
}

const char* llama_last_error() {
    return g_last_error.c_str();
}

int llama_init() {
    return 0;
}

LLAMA_HANDLE llama_load_model(const char* path, int n_gpu_layers) {
    if (!path) {
        set_last_error_and_return("model path is null");
        return nullptr;
    }

    std::string spath(path);
    {
        std::lock_guard<std::mutex> lk(g_models_mutex);
        auto it = g_models.find(spath);
        if (it != g_models.end()) {
            return (LLAMA_HANDLE)it->second;
        }
    }

    llama_wrapper_handle *h = new (std::nothrow) llama_wrapper_handle();
    if (!h) {
        set_last_error_and_return("out of memory when allocating handle");
        return nullptr;
    }

    llama_model_params mparams = llama_model_default_params();
    if (n_gpu_layers > 0) {
        mparams.n_gpu_layers = n_gpu_layers;
    }

    h->model = llama_model_load_from_file(path, mparams);
    if (!h->model) {
        delete h;
        set_last_error_and_return("failed to load model from file");
        return nullptr;
    }

    llama_context_params cparams = llama_context_default_params();
    if (cparams.n_ctx <= 0) cparams.n_ctx = 2048;
    h->n_ctx = cparams.n_ctx;

    h->ctx = llama_init_from_model(h->model, cparams);
    if (!h->ctx) {
        llama_model_free(h->model);
        delete h;
        set_last_error_and_return("failed to create context from model");
        return nullptr;
    }

    h->model_path = spath;
    h->loaded_at = std::chrono::steady_clock::now();

    {
        std::lock_guard<std::mutex> lk(g_models_mutex);
        g_models[spath] = h;
    }

    return (LLAMA_HANDLE)h;
}

int llama_unload_model(LLAMA_HANDLE handle) {
    if (!handle) {
        return set_last_error_and_return("null handle passed to unload", -1);
    }

    llama_wrapper_handle *h = (llama_wrapper_handle*)handle;
    std::string path = h->model_path;

    {
        std::lock_guard<std::mutex> lk(g_models_mutex);
        auto it = g_models.find(path);
        if (it != g_models.end()) g_models.erase(it);
    }

    if (h->ctx) {
#ifdef LLAMA_API_HAS_context_free
        llama_context_free(h->ctx);
#else
        llama_free(h->ctx);
#endif
        h->ctx = nullptr;
    }
    if (h->model) {
        llama_model_free(h->model);
        h->model = nullptr;
    }
    delete h;
    return 0;
}

int llama_reset_context(LLAMA_HANDLE handle) {
    if (!handle) return set_last_error_and_return("null handle in reset_context", -1);
    llama_wrapper_handle *h = (llama_wrapper_handle*)handle;
    if (!h->model) return set_last_error_and_return("model missing in handle", -1);

    if (h->ctx) {
#ifdef LLAMA_API_HAS_context_free
        llama_context_free(h->ctx);
#else
        llama_free(h->ctx);
#endif
        h->ctx = nullptr;
    }

    llama_context_params cparams = llama_context_default_params();
    if (h->n_ctx > 0) cparams.n_ctx = h->n_ctx;
    h->ctx = llama_init_from_model(h->model, cparams);
    if (!h->ctx) return set_last_error_and_return("failed to recreate context", -1);
    return 0;
}

int llama_apply_adapter(LLAMA_HANDLE handle, const char* adapter_path) {
    if (!handle || !adapter_path) return set_last_error_and_return("null argument to apply_adapter", -1);
    llama_wrapper_handle *h = (llama_wrapper_handle*)handle;
    if (!h->model) return set_last_error_and_return("model missing in handle", -1);

    int res = -1;

#ifdef LLAMA_HAVE_MODEL_APPLY_LORA
    res = llama_model_apply_lora_from_file(h->model, adapter_path, 1.0f, 0, 0);
#else
    (void)h;
    (void)adapter_path;
    set_last_error_and_return("llama_model_apply_lora_from_file not available in this llama build");
    return -1;
#endif
    if (res != 0) {
        set_last_error_and_return("failed to apply lora adapter");
    }
    return res;
}

int llama_generate(LLAMA_HANDLE handle,
                   const char* prompt,
                   char* outbuf,
                   int outbuf_size,
                   int max_tokens,
                   float temperature,
                   float top_p,
                   int top_k) {
    if (!handle) return set_last_error_and_return("null handle to generate", -1);
    if (!prompt) return set_last_error_and_return("null prompt", -1);
    if (!outbuf || outbuf_size <= 0) return set_last_error_and_return("invalid output buffer", -1);

    llama_wrapper_handle *h = (llama_wrapper_handle*)handle;
    if (!h->model || !h->ctx) return set_last_error_and_return("model/context missing", -1);

    const llama_vocab * vocab = llama_model_get_vocab(h->model);
    if (!vocab) return set_last_error_and_return("failed to get vocab from model", -1);

    const int TOK_CAP = 8192;
    std::vector<llama_token> tokens(TOK_CAP);
    int ntok = llama_tokenize(vocab, prompt, (int)strlen(prompt), tokens.data(), TOK_CAP, true, false);
    if (ntok <= 0) {
        set_last_error_and_return("tokenize produced empty result");
        return -1;
    }
    tokens.resize(ntok);

    if (llama_eval(h->ctx, tokens.data(), (int)tokens.size(), 0, 0)) {
        set_last_error_and_return("llama_eval failed for prompt");
        return -1;
    }

    std::string result;
    result.reserve(1024);

    llama_sampler * sampler = nullptr;
    if (temperature <= 0.001f) {
#ifdef LLAMA_SAMPLER_GREEDY
        sampler = llama_sampler_init_greedy();
#else
        sampler = nullptr;
#endif
    } else {
#ifdef LLAMA_SAMPLER_DEFAULT
        sampler = llama_sampler_init();
#else
        sampler = nullptr;
#endif
    }

    for (int i = 0; i < max_tokens; ++i) {
        llama_token tok = 0;

        if (sampler) {
            tok = llama_sampler_sample(sampler, h->ctx, -1);
        } else {
#ifdef LLAMA_SAMPLE_TOKEN_GREEDY_AVAILABLE
            tok = llama_sample_token_greedy(h->ctx, nullptr);
#else
            set_last_error_and_return("no sampling API available in this build (greedy/probabilistic)");
            break;
#endif
        }

        if (tok == llama_vocab_eos(vocab)) break;

        char piece_buf[256];
        int got = llama_token_to_piece(vocab, tok, piece_buf, sizeof(piece_buf), 0, false);
        if (got <= 0) break;
        piece_buf[sizeof(piece_buf) - 1] = '\0';
        result.append(piece_buf);

        if (llama_eval(h->ctx, &tok, 1, tokens.size() + i, 0)) {
            set_last_error_and_return("llama_eval failed during generation");
            break;
        }
    }

    if (sampler) {
        llama_sampler_free(sampler);
    }

    strncpy(outbuf, result.c_str(), outbuf_size - 1);
    outbuf[outbuf_size - 1] = '\0';

    return (int)result.size();
}

} // extern "C"
