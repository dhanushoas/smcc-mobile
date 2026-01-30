import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String baseUrl = 'http://192.168.1.164:5000/api';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      if (savedUrl.endsWith('/')) savedUrl = savedUrl.substring(0, savedUrl.length - 1);
      if (savedUrl.endsWith('/api')) savedUrl = savedUrl.substring(0, savedUrl.length - 4);
      baseUrl = '$savedUrl/api';
    }
  }

  static Future<void> setUrl(String url) async {
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    
    baseUrl = '$url/api';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
  }

  static Future<List<dynamic>> getMatches() async {
    if (baseUrl.contains('10.0.2.2')) await init(); // Try to load saved if default
    final response = await http.get(Uri.parse('$baseUrl/matches'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load matches');
    }
  }

  static Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      return token;
    } else {
      String msg = 'Login failed';
      try {
        final errData = json.decode(response.body);
        if (errData['msg'] != null) msg = 'Invalid: ${errData['msg']}';
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> updateMatch(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('$baseUrl/matches/$id'),
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? ''
      },
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update match');
    }
  }
  static Future<void> deleteMatch(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse('$baseUrl/matches/$id'),
      headers: {
        'x-auth-token': token ?? ''
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete match');
    }
  }
}
