import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Production Backend URL
  static const String baseUrl = 'https://smcc-backend.onrender.com/api';

  // Legacy dynamic URL logic removed as per request for seamless valid login
  static Future<void> init() async {}

  // Wake up Render server early
  static Future<void> warmup() async {
    try {
      // Hit the base domain (without /api) /ping
      String pingUrl = baseUrl.replaceAll('/api', '');
      http.get(Uri.parse(pingUrl)).timeout(Duration(seconds: 60));
    } catch (_) {}
  }

  static Future<List<dynamic>> getMatches() async {

    try {
      final response = await http.get(Uri.parse('$baseUrl/matches'))
          .timeout(Duration(seconds: 90));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('Format')) {
         throw Exception('Invalid Data: Server might be waking up');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMatch(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/matches/$id'))
        .timeout(Duration(seconds: 90));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load match');
    }
  }

  static Future<void> submitInteraction(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/misc/submit'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    ).timeout(Duration(seconds: 30));

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to submit. Please try again.');
    }
  }
}
