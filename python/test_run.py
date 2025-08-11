from codellama_ffi_module import generate_response

response = generate_response("default", "Hello from CodeLLaMA!")
print("Model output:", response)
