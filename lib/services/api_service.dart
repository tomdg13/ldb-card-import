import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/card_model.dart';

class ApiService {
  String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:2115'});

  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/virtual-cards'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<ImportResult>> importFile({
    required List<int> fileBytes,
    required String fileName,
    required String cifNo,
    required String fullName,
    required String productCode,
  }) async {
    final uri     = Uri.parse('$baseUrl/virtual-cards/issue-file');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    request.fields['cifNo']       = cifNo;
    request.fields['fullName']    = fullName;
    request.fields['productCode'] = productCode;

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body     = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      final err = jsonDecode(body);
      throw Exception(err['message'] ?? 'API error ${streamed.statusCode}');
    }
    final data = jsonDecode(body);
    return (data['cards'] as List).map((c) => ImportResult.fromJson(c)).toList();
  }

  Future<List<VirtualCard>> listCards() async {
    final res = await http
        .get(Uri.parse('$baseUrl/virtual-cards'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Failed to load cards');
    final List data = jsonDecode(res.body);
    return data.map((j) => VirtualCard.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> decryptCard(int cardId) async {
    final res = await http
        .get(Uri.parse('$baseUrl/virtual-cards/$cardId/decrypt'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Decrypt failed');
    return jsonDecode(res.body);
  }

  Future<void> activateCard(int cardId) async {
    final res = await http
        .patch(Uri.parse('$baseUrl/virtual-cards/$cardId/activate'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Activate failed');
    }
  }

  // ── SFTP ──────────────────────────────────────
  Future<Map<String, dynamic>> sftpPost(String endpoint, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/virtual-cards/$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'SFTP error ${res.statusCode}');
    }
    return data;
  }
}
