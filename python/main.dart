import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C function signature in the .so file
typedef GenerateResponseNative = Pointer<Utf8> Function(
    Pointer<Utf8> prompt, Int32 maxTokens, Float temperature);
typedef GenerateResponseDart = Pointer<Utf8> Function(
    Pointer<Utf8> prompt, int maxTokens, double temperature);

class CodeLlamaFFI {
  late DynamicLibrary _lib;
  late GenerateResponseDart _generateResponse;

  CodeLlamaFFI() {
    final scriptDir = Directory.current.path;
    _lib = DynamicLibrary.open('$scriptDir/../libffi/libcodellama.so');

    _generateResponse = _lib
        .lookup<NativeFunction<GenerateResponseNative>>('generate_response')
        .asFunction();
  }

  String generate(String prompt, {int maxTokens = 256, double temperature = 0.7}) {
    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = _generateResponse(promptPtr, maxTokens, temperature);
    final response = resultPtr.toDartString();
    calloc.free(promptPtr);
    return response;
  }
}

void main() {
  final llama = CodeLlamaFFI();
  final prompt = "Write a Python function to check if a number is prime:";
  print("🔹 Prompt: $prompt");
  final response = llama.generate(prompt);
  print("🔹 Response: $response");
}
