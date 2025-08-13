import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

class ModelService {
  late final String _baseModel;
  late final String _modelPath;
  late final String _adapterCheckpoint;
  late final String _ffiLibraryPath;
  late final DynamicLibrary _dylib;

  // FFI function bindings
  late final Pointer<Utf8> Function() _lastError;
  late final Pointer<Void> Function(Pointer<Utf8>, int) _loadModel;
  late final int Function(Pointer<Void>) _unloadModel;
  late final int Function(Pointer<Void>, Pointer<Utf8>) _applyAdapter;
  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    int,
    int,
    double,
    double,
    int
  ) _generate;

  ModelService({String configPath = 'config/model_config.json'}) {
    final config = _readConfig(configPath);
    _baseModel = config['base_model'] as String;
    _modelPath = path.absolute(config['model_path'] as String); // Convert to absolute path
    _adapterCheckpoint = path.absolute(config['adapter_checkpoint'] as String); // Convert to absolute path
    _ffiLibraryPath = path.absolute(config['ffi_library_path'] as String); // Convert to absolute path

    _initializeFFI();
    _validateCheckpoint();
  }

  static Map<String, dynamic> _readConfig(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Config file not found at $path');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  void _initializeFFI() {
    try {
      _dylib = DynamicLibrary.open(_ffiLibraryPath);

      _lastError = _dylib.lookupFunction<
          Pointer<Utf8> Function(),
          Pointer<Utf8> Function()
      >('llama_last_error');

      _loadModel = _dylib.lookupFunction<
          Pointer<Void> Function(Pointer<Utf8>, Int32),
          Pointer<Void> Function(Pointer<Utf8>, int)
      >('llama_load_model');

      _unloadModel = _dylib.lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
      >('llama_unload_model');

      _applyAdapter = _dylib.lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<Utf8>),
          int Function(Pointer<Void>, Pointer<Utf8>)
      >('llama_apply_adapter');

      _generate = _dylib.lookupFunction<
          Int32 Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            Int32,
            Int32,
            Float,
            Float,
            Int32
          ),
          int Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<Utf8>,
            int,
            int,
            double,
            double,
            int
          )
      >('llama_generate');
    } catch (e) {
      throw Exception('Failed to initialize FFI: $e');
    }
  }

  void _validateCheckpoint() {
    final modelFile = File(_modelPath);
    if (!modelFile.existsSync()) {
      throw Exception('Model file not found at $_modelPath');
    }
    final adapterDir = Directory(_adapterCheckpoint);
    if (!adapterDir.existsSync()) {
      throw Exception('Adapter checkpoint directory not found at $_adapterCheckpoint');
    }
    final ffiLib = File(_ffiLibraryPath);
    if (!ffiLib.existsSync()) {
      throw Exception('FFI library not found at $_ffiLibraryPath');
    }
  }

  Future<String> generate({
    required String prompt,
    required String adapterId,
  }) async {
    final modelPathPtr = _modelPath.toNativeUtf8();
    final handle = _loadModel(modelPathPtr, 0); // Assuming no GPU layers
    if (handle.address == 0) {
      final error = _lastError().toDartString();
      malloc.free(modelPathPtr);
      throw Exception('Failed to load model: $error');
    }

    final adapterPathPtr = _adapterCheckpoint.toNativeUtf8();
    final adapterResult = _applyAdapter(handle, adapterPathPtr);
    if (adapterResult != 0) {
      final error = _lastError().toDartString();
      malloc.free(adapterPathPtr);
      malloc.free(modelPathPtr);
      _unloadModel(handle);
      throw Exception('Failed to apply adapter: $error');
    }

    final promptPtr = prompt.toNativeUtf8();
    final outbuf = malloc.allocate<Uint8>(1024 * 1024); // 1MB buffer
    final outbufSize = 1024 * 1024;
    final maxTokens = 512;
    final temperature = 0.7;
    final topP = 0.9;
    final topK = 40;

    try {
      final result = _generate(
        handle,
        promptPtr,
        outbuf.cast(),
        outbufSize,
        maxTokens,
        temperature,
        topP,
        topK,
      );

      if (result < 0) {
        final error = _lastError().toDartString();
        throw Exception('Generation failed: $error');
      }

      final output = outbuf.cast<Utf8>().toDartString();
      return output.substring(0, result);
    } finally {
      malloc.free(promptPtr);
      malloc.free(outbuf);
      malloc.free(adapterPathPtr);
      malloc.free(modelPathPtr);
      _unloadModel(handle);
    }
  }
}
