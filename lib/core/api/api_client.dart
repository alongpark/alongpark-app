import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiClient {
  // Serveur Cloud de Production hébergé sur Railway
  static const String baseUrl = 'https://web-production-cdcfb.up.railway.app';

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60)); // 60s pour l'analyse IA (images lourdes)

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Réponse API inattendue (pas un objet JSON)');
    }
    // Extrait le message d'erreur si possible
    try {
      final err = jsonDecode(res.body);
      final msg = err['detail'] ?? err['message'] ?? res.body;
      throw Exception('API ${res.statusCode}: $msg');
    } catch (_) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
  }

  static Future<dynamic> getJson(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('API ${res.statusCode}: ${res.body}');
  }

  /// Retourne un objet JSON (Map)
  static Future<Map<String, dynamic>> get(String path) async {
    final decoded = await getJson(path);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Réponse API inattendue (pas un objet JSON)');
  }

  /// Retourne une liste JSON
  static Future<List<dynamic>> getList(String path) async {
    final decoded = await getJson(path);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded.containsKey('items')) return decoded['items'] as List;
    throw Exception('Réponse API inattendue (pas une liste JSON)');
  }

  /// Encode une image en base64 pour l'estimation Claude Vision
  static Future<String> imageToBase64(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return base64Encode(bytes);
  }
}
