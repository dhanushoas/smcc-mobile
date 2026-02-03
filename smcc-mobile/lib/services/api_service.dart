import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Production Backend URL
  static const String baseUrl = 'https://smcc-backend.onrender.com/api';

  // Legacy dynamic URL logic removed as per request for seamless valid login
  static Future<void> init() async {}

  // Wake up Render server early
  static Future<void> warmup() async {
    try {
      // Hit the base domain (without /api) /ping
      String pingUrl = baseUrl.replaceAll('/api', '/ping');
      http.get(Uri.parse(pingUrl)).timeout(Duration(seconds: 60));
    } catch (_) {}
  }

  static Future<List<dynamic>> getMatches() async {

    final response = await http.get(Uri.parse('$baseUrl/matches'))
        .timeout(Duration(seconds: 90));
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
    ).timeout(Duration(seconds: 90));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      
      // Decode user ID if possible or just store it from login response?
      // I'll update backend to return id
      if (data['user'] != null && data['user']['id'] != null) {
        await prefs.setInt('userId', data['user']['id']);
      }
      
      return token;
    } else {
      String msg = 'Login failed';
      try {
        if (response.body.startsWith('{')) {
          final errData = json.decode(response.body);
          if (errData['msg'] != null) msg = 'Invalid: ${errData['msg']}';
        } else if (response.statusCode == 500) {
          msg = 'Server Error (500). Please check backend logs.';
        } else if (response.statusCode == 404) {
          msg = 'Backend endpoint not found (404). Check API URL.';
        }
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> updateMatch(dynamic id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('$baseUrl/matches/${id.toString()}'),
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? ''
      },
      body: json.encode(data),
    ).timeout(Duration(seconds: 90));

    if (response.statusCode != 200) {
      String msg = 'Failed to update match';
      try {
        final err = json.decode(response.body);
        if (err['msg'] != null) msg = err['msg'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> deleteMatch(dynamic id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse('$baseUrl/matches/${id.toString()}'),
      headers: {
        'x-auth-token': token ?? ''
      },
    ).timeout(Duration(seconds: 90));

    if (response.statusCode != 200) {
      String msg = 'Failed to delete match';
      try {
        final err = json.decode(response.body);
        if (err['msg'] != null) msg = err['msg'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> createMatch(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('$baseUrl/matches'),
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? ''
      },
      body: json.encode(data),
    ).timeout(Duration(seconds: 90));

    if (response.statusCode != 201 && response.statusCode != 200) {
      String msg = 'Failed to create match';
      try {
        final err = json.decode(response.body);
        if (err['msg'] != null) msg = err['msg'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (userId == null) return;

    await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId}),
    ).timeout(Duration(seconds: 10));
    
    await prefs.remove('token');
    await prefs.remove('userId');
  }

  static Future<void> resetSession(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-session'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    ).timeout(Duration(seconds: 30));

    if (response.statusCode != 200) {
      String msg = 'Failed to reset session';
      try {
        final err = json.decode(response.body);
        if (err['msg'] != null) msg = err['msg'];
      } catch (_) {}
      throw Exception(msg);
    }
  }
}
