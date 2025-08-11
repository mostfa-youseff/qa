
#include <Python.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static PyObject *pModule = NULL;
static PyObject *pFuncGenerate = NULL;

int initialize_python() {
    setenv("PYTHONPATH", "/home/myouseff_aortem_io/qa/python", 1); // ضبط PYTHONPATH
    if (!Py_IsInitialized()) {
        Py_Initialize();
    }
    printf("Python version: %s\n", Py_GetVersion());
    pModule = PyImport_ImportModule("codellama_ffi_module");
    if (!pModule) {
        fprintf(stderr, "Error: Failed to load codellama_ffi_module\n");
        PyErr_Print();
        return -1;
    }
    printf("Successfully loaded codellama_ffi_module\n");
    pFuncGenerate = PyObject_GetAttrString(pModule, "generate_text");
    if (!pFuncGenerate || !PyCallable_Check(pFuncGenerate)) {
        fprintf(stderr, "Error: Failed to load generate_text function\n");
        PyErr_Print();
        Py_XDECREF(pModule);
        return -2;
    }
    printf("Successfully loaded generate_text function\n");
    return 0;
}

char* generate(const char* prompt, const char* adapter_id, const char* checkpoint_path) {
    if (!pFuncGenerate) {
        fprintf(stderr, "Error: pFuncGenerate is NULL\n");
        return NULL;
    }
    PyObject *pArgs = PyTuple_New(3);
    if (!pArgs) {
        fprintf(stderr, "Error: Failed to create PyTuple\n");
        return NULL;
    }
    PyTuple_SetItem(pArgs, 0, PyUnicode_FromString(prompt));
    PyTuple_SetItem(pArgs, 1, PyUnicode_FromString(adapter_id));
    PyTuple_SetItem(pArgs, 2, PyUnicode_FromString(checkpoint_path));

    PyObject *pValue = PyObject_CallObject(pFuncGenerate, pArgs);
    Py_DECREF(pArgs);

    if (!pValue) {
        fprintf(stderr, "Error: PyObject_CallObject failed\n");
        PyErr_Print();
        return NULL;
    }

    const char* result_cstr = PyUnicode_AsUTF8(pValue);
    if (!result_cstr) {
        fprintf(stderr, "Error: PyUnicode_AsUTF8 failed\n");
        PyErr_Print();
        Py_DECREF(pValue);
        return NULL;
    }

    char* ret = strdup(result_cstr);
    Py_DECREF(pValue);
    return ret;
}

void free_memory(char* ptr) {
    free(ptr);
}

void finalize_python() {
    Py_XDECREF(pFuncGenerate);
    Py_XDECREF(pModule);
    if (Py_IsInitialized()) {
        Py_Finalize();
    }
}
