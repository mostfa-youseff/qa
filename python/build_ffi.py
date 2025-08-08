import cffi
import os
import shutil

# Define C interface
ffi = cffi.FFI()
ffi.cdef("""
    char* generate(const char* prompt, const char* adapter_id, const char* checkpoint_path);
    void free_memory(char* ptr);
""")

# Compile to shared library with dummy implementations
ffi.set_source("codellama_ffi", """
    #include <Python.h>
    #include <stdlib.h>
    #include <string.h>

    // Dummy implementation of generate
    char* generate(const char* prompt, const char* adapter_id, const char* checkpoint_path) {
        const char* msg = "Hello from generate";
        char* result = (char*) malloc(strlen(msg) + 1);
        strcpy(result, msg);
        return result;
    }

    // Implementation to free allocated memory
    void free_memory(char* ptr) {
        free(ptr);
    }
""", extra_compile_args=["-fPIC"], libraries=["python3.12"])

if __name__ == "__main__":
    ffi.compile(target="libcodellama.so", verbose=True)
    os.makedirs("../libffi", exist_ok=True)
    shutil.move("libcodellama.so", "../libffi/libcodellama.so")
