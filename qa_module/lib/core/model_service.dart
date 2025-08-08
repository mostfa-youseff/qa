import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

class ModelService {
  late final String _baseModel;
  late final String _adapterCheckpoint;
  late final String _ffiLibraryPath;
  late final DynamicLibrary _dylib;
  late final Pointer<Utf8> Function(
      Pointer<Utf8> prompt,
      Pointer<Utf8> adapterId,
      Pointer<Utf8> checkpointPath) _generate;

  ModelService({String configPath = 'config/model_config.json'}) {
    final config = _readConfig(configPath);
    _baseModel = config['base_model'] as String;
    _adapterCheckpoint = config['adapter_checkpoint'] as String;
    _ffiLibraryPath = config['ffi_library_path'] as String;

    _initializeFFI();
    _validateCheckpoint();
  }

  static Map<String, dynamic> _readConfig(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Config file not found at $path');
    }
    final content = file.readAsStringSync();
    return jsonDecode(content);
  }

  void _initializeFFI() {
    try {
      final absolutePath = path.absolute(_ffiLibraryPath);
      _dylib = DynamicLibrary.open(absolutePath);
      _generate = _dylib.lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)
      >('generate');
    } catch (e) {
      throw Exception('Failed to load FFI library: $e');
    }
  }

  void _validateCheckpoint() {
    final checkpointDir = Directory(_adapterCheckpoint);
    if (!checkpointDir.existsSync()) {
      throw Exception('Adapter checkpoint not found at $_adapterCheckpoint');
    }
    final requiredFiles = ['adapter_model.bin', 'adapter_config.json'];
    for (final file in requiredFiles) {
      if (!File('${_adapterCheckpoint}/$file').existsSync()) {
        throw Exception('Missing required checkpoint file: $file');
      }
    }
  }

  Future<String> generate({
    required String prompt,
    required String adapterId,
  }) async {
    final promptPtr = prompt.toNativeUtf8();
    final adapterIdPtr = adapterId.toNativeUtf8();
    final checkpointPtr = _adapterCheckpoint.toNativeUtf8();
    try {
      final resultPtr = _generate(promptPtr, adapterIdPtr, checkpointPtr);
      if (resultPtr.address == 0) {
        throw Exception('Model inference failed: null pointer returned');
      }
      final result = resultPtr.toDartString();
      _freeMemory(resultPtr);
      return result;
    } finally {
      malloc.free(promptPtr);
      malloc.free(adapterIdPtr);
      malloc.free(checkpointPtr);
    }
  }

  void _freeMemory(Pointer<Utf8> ptr) {
    _dylib.lookupFunction<Void Function(Pointer<Utf8>), void Function(Pointer<Utf8>)>('free_memory')(ptr);
  }
}

