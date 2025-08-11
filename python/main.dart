import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef generate_native = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);
typedef Generate = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);

typedef free_memory_native = ffi.Void Function(ffi.Pointer<Utf8>);
typedef FreeMemory = void Function(ffi.Pointer<Utf8>);

void main() {
  // هنا اسم المكتبة المشتركة (shared library)
  final dylib = ffi.DynamicLibrary.open('./libcodellama.so');

  final Generate generate = dylib.lookupFunction<generate_native, Generate>('generate');
  final FreeMemory freeMemory = dylib.lookupFunction<free_memory_native, FreeMemory>('free_memory');

  final promptPtr = "Write a Dart function".toNativeUtf8();
  final adapterPtr = "test_gen_adapter".toNativeUtf8();
  final checkpointPtr = "/mnt/data/codellama_7b_test_adapter/checkpoint-1000".toNativeUtf8();

  final resultPtr = generate(promptPtr, adapterPtr, checkpointPtr);

  if (resultPtr == ffi.nullptr) {
    print('Error: generate returned nullptr');
  } else {
    final result = resultPtr.toDartString();
    print('Result from C: $result');
    freeMemory(resultPtr);
  }

  // حرر الميموري المحجوزة
  calloc.free(promptPtr);
  calloc.free(adapterPtr);
  calloc.free(checkpointPtr);
}
