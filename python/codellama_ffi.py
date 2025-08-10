import cffi
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import threading
import os
import torch

ffi = cffi.FFI()
ffi.cdef("""
    char* generate(const char* prompt, const char* adapter_id, const char* checkpoint_path);
    void free_memory(char* ptr);
""")

base_model_name = "codellama/CodeLlama-7b-hf"
model = None
tokenizer = None
adapter_models = {}
lock = threading.Lock()

def initialize_base_model():
    global model, tokenizer
    if model is None or tokenizer is None:
        hf_token = os.getenv("HF_TOKEN")
        tokenizer = AutoTokenizer.from_pretrained(
            base_model_name,
            token=hf_token,
            trust_remote_code=True
        )
        model = AutoModelForCausalLM.from_pretrained(
            base_model_name,
            token=hf_token,
            trust_remote_code=True,
            device_map="auto",
            torch_dtype=torch.float16,
            offload_folder="./offload_dir"
        )
        model.eval()

def get_adapter_model(checkpoint_path):
    with lock:
        if checkpoint_path not in adapter_models:
            adapter_models[checkpoint_path] = PeftModel.from_pretrained(
                model,
                checkpoint_path,
                is_trainable=False,
                device_map="auto",
                torch_dtype=torch.float16
                offload_folder="./offload_dir" 
            )
            adapter_models[checkpoint_path].eval()
        return adapter_models[checkpoint_path]

@ffi.callback("char* generate(const char* prompt, const char* adapter_id, const char* checkpoint_path)")
def generate(prompt, adapter_id, checkpoint_path):
    try:
        checkpoint_path_str = ffi.string(checkpoint_path).decode('utf-8')
        initialize_base_model()
        adapter_model = get_adapter_model(checkpoint_path_str)

        prompt_str = ffi.string(prompt).decode('utf-8')
        adapter_id_str = ffi.string(adapter_id).decode('utf-8')

        if adapter_id_str in ["test_gen_adapter", "dynamic_documentation_adapter"]:
            inputs = tokenizer(prompt_str, return_tensors="pt").to(next(adapter_model.parameters()).device)
            outputs = adapter_model.generate(**inputs, max_length=512)
            result = tokenizer.decode(outputs[0], skip_special_tokens=True)
        else:
            result = "Adapter not supported: " + adapter_id_str

    except Exception as e:
        result = f"Error: {str(e)}"

    return ffi.new("char[]", result.encode('utf-8'))

@ffi.callback("void free_memory(char* ptr)")
def free_memory(ptr):
    pass

if __name__ == "__main__":
    os.makedirs("./offload_dir", exist_ok=True)
    test_prompt = "Generate unit tests for a Dart function"
    test_adapter = "test_gen_adapter"
    test_checkpoint = "/mnt/data/codellama_7b_test_adapter/checkpoint-1000"
    result = generate(
        ffi.new("char[]", test_prompt.encode('utf-8')),
        ffi.new("char[]", test_adapter.encode('utf-8')),
        ffi.new("char[]", test_checkpoint.encode('utf-8'))
    )
    print(ffi.string(result).decode('utf-8'))
