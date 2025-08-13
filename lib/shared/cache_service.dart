import 'dart:convert';
import 'dart:io';
import 'package:redis/redis.dart';
import 'package:http/http.dart' as http;

class CacheService {
  final String _redisHost = Platform.environment['REDIS_HOST'] ?? '10.150.30.3';
  final int _redisPort =
      int.tryParse(Platform.environment['REDIS_PORT'] ?? '6378') ?? 6378;

  final String? _redisUsername = Platform.environment['REDIS_USERNAME'];
  final String? _redisPassword = Platform.environment['REDIS_PASSWORD'];
  final String _redisCaCertificate =
      Platform.environment['REDIS_CA_CERTIFICATE'] ?? '';

  final String _qdrantUrl =
      'http://localhost:6333/collections/qa_module/points';

  Future<Command> _connectSecure() async {
    if (_redisCaCertificate.isEmpty) {
      throw StateError(
          'REDIS_CA_CERTIFICATE is empty. Set the CA PEM in the environment.');
    }

    final String pem = _redisCaCertificate.contains(r'\n')
        ? _redisCaCertificate.replaceAll(r'\n', '\n')
        : _redisCaCertificate;

    final SecurityContext ctx = SecurityContext(withTrustedRoots: false);
    ctx.setTrustedCertificatesBytes(utf8.encode(pem));

    final SecureSocket socket = await SecureSocket.connect(
      _redisHost,
      _redisPort,
      context: ctx,
    );

    final RedisConnection conn = RedisConnection();
    final Command command = await conn.connectWithSocket(socket);

    if ((_redisPassword != null && _redisPassword!.isNotEmpty) ||
        (_redisUsername != null && _redisUsername!.isNotEmpty)) {
      if (_redisUsername != null &&
          _redisUsername!.isNotEmpty &&
          _redisPassword != null &&
          _redisPassword!.isNotEmpty) {
        await command.send_object(['AUTH', _redisUsername!, _redisPassword!]);
      } else if (_redisPassword != null && _redisPassword!.isNotEmpty) {
        await command.send_object(['AUTH', _redisPassword!]);
      }
    }

    return command;
  }

  Future<String?> get(String key) async {
    try {
      final command = await _connectSecure();
      final value = await command.get(key);
      await command.get_connection().close();
      return value as String?;
    } catch (e) {
      print('Redis TLS get error: $e');
      return null;
    }
  }

  Future<void> set(String key, String value) async {
    try {
      final command = await _connectSecure();
      await command.set(key, value);
      await command.get_connection().close();
    } catch (e) {
      print('Redis TLS set error: $e');
    }
  }

  Future<void> storeEmbedding(String key, List<double> embedding) async {
    try {
      await http.put(
        Uri.parse(_qdrantUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'points': [
            {'id': key, 'vector': embedding}
          ]
        }),
      );
    } catch (e) {
      print('Qdrant store error: $e');
    }
  }
}
