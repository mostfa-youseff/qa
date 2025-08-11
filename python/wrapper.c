// wrapper.c (modified)
#include <Python.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Global flag + module/function handles
static int python_initialized = 0;
static PyObject *pModule_global = NULL;
static PyObject *pFunc_generate = NULL;

// Call once at process startup
void initialize_python_wrapper() {
    if (python_initialized) return;
    Py_Initialize();
    python_initialized = 1;

    // Import module and cache function pointer
    PyObject *pName = PyUnicode_DecodeFSDefault("codellama_ffi_module");
    pModule_global = PyImport_Import(pName);
    Py_DECREF(pName);

    if (!pModule_global) {
        PyErr_Print();
        fprintf(stderr, "Failed to import codellama_ffi_module\n");
        // keep going: generate_response will handle null module gracefully
        return;
    }

    pFunc_generate = PyObject_GetAttrString(pModule_global, "generate_response");
    if (!pFunc_generate || !PyCallable_Check(pFunc_generate)) {
        PyErr_Print();
        fprintf(stderr, "generate_response not found or not callable\n");
        Py_XDECREF(pFunc_generate);
        pFunc_generate = NULL;
        // We keep the module loaded even if function lookup failed
    }
}

// Call once at process shutdown
void finalize_python_wrapper() {
    if (!python_initialized) return;
    // DECREF function & module
    if (pFunc_generate) {
        Py_XDECREF(pFunc_generate);
        pFunc_generate = NULL;
    }
    if (pModule_global) {
        Py_XDECREF(pModule_global);
        pModule_global = NULL;
    }
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

    // Build args tuple
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
            result = strdup(output);
        }
        Py_DECREF(pValue);
    } else {
        PyErr_Print();
    }

    return result;
}

int main(int argc, char *argv[]) {
    // Initialize once
    initialize_python_wrapper();

    if (argc < 3) {
        fprintf(stderr, "Usage: %s <brand> <prompt>\n", argv[0]);
        finalize_python_wrapper();
        return 1;
    }

    char *output = generate_response(argv[1], argv[2]);
    if (output) {
        printf("Model output:\n%s\n", output);
        free(output);
    } else {
        fprintf(stderr, "No output from model\n");
    }

    // Finalize once at exit
    finalize_python_wrapper();
    return 0;
}
