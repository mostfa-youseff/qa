// wrapper.c  -- shared lib wrapper for Python-backed generate_response
#include <Python.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

// Exported API prototypes (visible symbols)
__attribute__((visibility("default")))
void initialize_python_wrapper();

__attribute__((visibility("default")))
void finalize_python_wrapper();

__attribute__((visibility("default")))
char* generate_response(const char* brand, const char* prompt);

// Provide alias 'generate' because some callers (Dart) look up 'generate'
__attribute__((visibility("default")))
char* generate(const char* brand, const char* prompt);

// Helper for freeing strings allocated inside this lib
__attribute__((visibility("default")))
void free_c_string(char* s);

#ifdef __cplusplus
}
#endif


// ---------- Implementation ----------
static int python_initialized = 0;
static PyObject *pModule_global = NULL;
static PyObject *pFunc_generate = NULL;

void initialize_python_wrapper() {
    if (python_initialized) return;
    Py_Initialize();

    // Note: PyEval_InitThreads() is deprecated since Python 3.9 and not needed.
    // Acquire module and function pointer
    PyObject *pName = PyUnicode_DecodeFSDefault("codellama_ffi_module");
    pModule_global = PyImport_Import(pName);
    Py_DECREF(pName);
    if (!pModule_global) {
        PyErr_Print();
        fprintf(stderr, "Failed to import codellama_ffi_module\n");
        return;
    }
    pFunc_generate = PyObject_GetAttrString(pModule_global, "generate_response");
    if (!pFunc_generate || !PyCallable_Check(pFunc_generate)) {
        PyErr_Print();
        fprintf(stderr, "generate_response not found or not callable\n");
        Py_XDECREF(pFunc_generate);
        pFunc_generate = NULL;
    }
    python_initialized = 1;
}

void finalize_python_wrapper() {
    if (!python_initialized) return;
    if (pFunc_generate) { Py_XDECREF(pFunc_generate); pFunc_generate = NULL; }
    if (pModule_global) { Py_XDECREF(pModule_global); pModule_global = NULL; }
    Py_Finalize();
    python_initialized = 0;
}

char* generate_response(const char* brand, const char* prompt) {
    if (!python_initialized) {
        initialize_python_wrapper();
    }
    if (!pModule_global || !pFunc_generate) {
        fprintf(stderr, "Python module or function not initialized\n");
        return NULL;
    }

    // Acquire GIL for this call (safe if caller is multi-threaded)
    PyGILState_STATE gstate = PyGILState_Ensure();

    PyObject *pBrand = PyUnicode_FromString(brand ? brand : "default");
    PyObject *pPrompt = PyUnicode_FromString(prompt ? prompt : "");
    PyObject *pArgs = PyTuple_Pack(2, pBrand, pPrompt);
    Py_DECREF(pBrand);
    Py_DECREF(pPrompt);

    PyObject *pValue = PyObject_CallObject(pFunc_generate, pArgs);
    Py_DECREF(pArgs);

    char* result = NULL;
    if (pValue) {
        const char* output = PyUnicode_AsUTF8(pValue);
        if (output) {
            result = strdup(output); // caller must call free_c_string
        }
        Py_DECREF(pValue);
    } else {
        PyErr_Print();
    }

    PyGILState_Release(gstate);
    return result;
}

// Alias function to satisfy callers expecting 'generate'
char* generate(const char* brand, const char* prompt) {
    return generate_response(brand, prompt);
}

// Free helper for callers (e.g., Dart) to free allocated string
void free_c_string(char* s) {
    if (s) free(s);
}
