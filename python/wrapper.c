#include <Python.h>
#include <stdio.h>
#include <stdlib.h>

char* generate_response(const char* brand, const char* prompt) {
    Py_Initialize();

    PyObject *pName = PyUnicode_DecodeFSDefault("codellama_ffi_module");
    PyObject *pModule = PyImport_Import(pName);
    Py_DECREF(pName);

    if (!pModule) {
        PyErr_Print();
        Py_Finalize();
        return NULL;
    }

    PyObject *pFunc = PyObject_GetAttrString(pModule, "generate_response");
    if (!pFunc || !PyCallable_Check(pFunc)) {
        PyErr_Print();
        Py_XDECREF(pFunc);
        Py_DECREF(pModule);
        Py_Finalize();
        return NULL;
    }

    PyObject *pArgs = PyTuple_Pack(2, PyUnicode_FromString(brand), PyUnicode_FromString(prompt));
    PyObject *pValue = PyObject_CallObject(pFunc, pArgs);
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

    Py_XDECREF(pFunc);
    Py_DECREF(pModule);
    Py_Finalize();

    return result;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <brand> <prompt>\n", argv[0]);
        return 1;
    }

    char *output = generate_response(argv[1], argv[2]);
    if (output) {
        printf("Model output:\n%s\n", output);
        free(output);
    }
    return 0;
}
