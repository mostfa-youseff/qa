import 'package:redis/redis.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CacheService {
  final _redisConnection = RedisConnection();
  final String _redisHost = '127.0.0.1';
  final int _redisPort = 6380;
  final String _qdrantUrl = 'http://localhost:6333/collections/qa_module/points';

  Future<String?> get(String key) async {
    try {
      final command = await _redisConnection.connect(_redisHost, _redisPort);
      final value = await command.get(key);
      await command.get_connection().close();
      return value as String?;
    } catch (e) {
      print('Redis get error: $e');
      return null;
    }
  }

  Future<void> set(String key, String value) async {
    try {
      final command = await _redisConnection.connect(_redisHost, _redisPort);
      await command.set(key, value);
      await command.get_connection().close();
    } catch (e) {
      print('Redis set error: $e');
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
