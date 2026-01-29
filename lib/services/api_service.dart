import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  // static const String baseUrl = 'http://10.0.2.2:5000/api';
  static const String baseUrl = 'https://smcc-backend.onrender.com/api';

  static Future<List<dynamic>> getMatches() async {
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
      throw Exception('Login failed');
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
