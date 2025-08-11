#ifndef WRAPPER_H
#define WRAPPER_H

int initialize_python();
char* generate(const char* prompt, const char* adapter_id, const char* checkpoint_path);
void free_memory(char* ptr);
void finalize_python();

#endif
