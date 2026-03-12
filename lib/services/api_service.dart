import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../main.dart';
import '../screens/admin/admin_login_screen.dart';
import 'package:flutter/material.dart';

class ApiService {
  // Production Backend URL
  static const String baseUrl = 'https://smcc-backend.onrender.com/api';

  // Socket.IO root URL (no /api — mirrors web API_URL)
  static const String socketUrl = 'https://smcc-backend.onrender.com';

  static Future<void> init() async {}

  // Wake up Render server early
  static Future<void> warmup() async {
    try {
      String pingUrl = baseUrl.replaceAll('/api', '');
      http.get(Uri.parse(pingUrl)).timeout(const Duration(seconds: 60));
    } catch (_) {}
  }

  /// Helper to generate headers with auth token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Helper to handle the new standardized response format { success, message, data }
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      _handleUnauthorized();
      throw Exception('Session Expired');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = json.decode(response.body);
      
      if (body is Map && body.containsKey('success')) {
        if (body['success'] == true) {
          return body['data'];
        } else {
          throw Exception(body['message'] ?? 'Action failed');
        }
      }
      return body;
    } else {
      try {
        final body = json.decode(response.body);
        if (body is Map && body.containsKey('message')) {
          throw Exception(body['message']);
        }
      } catch (_) {}
      throw Exception('Server Error: ${response.statusCode}');
    }
  }

  static void _handleUnauthorized() async {
    await AuthService.logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen(expired: true)),
      (route) => false,
    );
  }

  // --- Auth API ---
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 30));
    
    final data = Map<String, dynamic>.from(await _handleResponse(response));
    if (data['token'] != null) {
      await AuthService.saveToken(data['token']);
    }
    return data;
  }

  static Future<bool> verifyToken() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verify'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      final res = await _handleResponse(response);
      return res != null;
    } catch (_) {
      return false;
    }
  }

  // --- Match API ---
  static Future<List<dynamic>> getMatches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/matches'))
          .timeout(const Duration(seconds: 90));
      return (await _handleResponse(response)) as List<dynamic>;
    } catch (e) {
      if (e.toString().contains('Format')) {
         throw Exception('Invalid Data: Server might be waking up');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMatch(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/matches/$id'))
        .timeout(const Duration(seconds: 90));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> createMatch(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/matches'),
      headers: headers,
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> updateMatch(String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/matches/$id'),
      headers: headers,
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> updateScore(String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/matches/$id/score'),
      headers: headers,
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> updateToss(String id, String winnerId, String decision) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/matches/${id.toString()}/toss'),
      headers: headers,
      body: json.encode({
        'tossWinnerTeamId': winnerId,
        'tossDecision': decision,
      }),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }


  static Future<Map<String, dynamic>> reverseMatch(String id) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/matches/$id/reverse'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> pauseMatch(String id, bool pause, String reason) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/matches/$id/pause'),
      headers: headers,
      body: json.encode({'pause': pause, 'reason': reason}),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> updateMatchDateTime(String id, Map<String, dynamic> payload) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/matches/$id/datetime'),
      headers: headers,
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<void> deleteMatch(String id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/matches/$id'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  // --- Footer API ---
  static Future<Map<String, dynamic>> getFooterLinks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/footer/links'))
          .timeout(const Duration(seconds: 30));
      final res = await _handleResponse(response);
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'quick_links': [], 'support': [], 'community': []};
    } catch (_) {
      return {'quick_links': [], 'support': [], 'community': []};
    }
  }

  static Future<List<dynamic>> getFooterSocials() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/footer/socials'))
          .timeout(const Duration(seconds: 30));
      return (await _handleResponse(response)) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  static Future<void> submitInteraction(Map<String, dynamic> payload) async {
    final String type = payload['type'] ?? 'feedback';
    final Map<String, dynamic> data = Map.from(payload);
    data.remove('type');

    final Map<String, dynamic> flattenedData = {};
    data.forEach((key, value) {
      if (key == 'data' && value is Map) {
        value.forEach((k, v) => flattenedData[k] = v);
      } else {
        flattenedData[key] = value;
      }
    });

    final response = await http.post(
      Uri.parse('$baseUrl/interactions/$type'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(flattenedData),
    ).timeout(const Duration(seconds: 30));

    await _handleResponse(response);
  }

  // --- Tournament API ---
  static Future<List<dynamic>> getTournaments() async {
    final response = await http.get(Uri.parse('$baseUrl/tournaments'))
        .timeout(const Duration(seconds: 30));
    return (await _handleResponse(response)) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getTournament(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/tournaments/$id'))
        .timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> createTournament(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/tournaments'),
      headers: headers,
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  // --- Registration API ---
  static Future<Map<String, dynamic>> getRegistrations() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/tournaments/registrations'), headers: headers)
        .timeout(const Duration(seconds: 30));
    final body = json.decode(response.body);
    if (body['success'] == true) {
      return {'data': body['data'], 'stats': body['stats'] ?? {'total': 0, 'approved': 0, 'rejected': 0}};
    } else {
      throw Exception(body['message'] ?? 'Failed to load registrations');
    }
  }

  static Future<void> updateRegistrationAction(String id, String action) async {
    final headers = await _getHeaders();
    final response = await http.put(Uri.parse('$baseUrl/tournaments/registrations/$id/$action'), headers: headers)
        .timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> deleteRegistration(String id) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/tournaments/registrations/$id'), headers: headers)
        .timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> generateRegistrationSchedule() async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/tournaments/registrations/generate-schedule'), headers: headers)
        .timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> submitPublicRegistration(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tournaments/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> registerTeam(int tournamentId, String name, {String captain = '', String captainMobile = '', String district = '', String manager = ''}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/tournaments/$tournamentId/teams'),
      headers: headers,
      body: json.encode({'name': name, 'captain': captain, 'captainMobile': captainMobile, 'district': district, 'manager': manager}),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> updateTeam(int tournamentId, int teamId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/tournaments/$tournamentId/teams/$teamId'),
      headers: headers,
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> generateGroups(int id) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/tournaments/$id/generate-groups'), headers: headers)
        .timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> generateSchedule(int id) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/tournaments/$id/generate-schedule'), headers: headers)
        .timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<void> generateKnockouts(int id) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/tournaments/$id/generate-knockouts'), headers: headers)
        .timeout(const Duration(seconds: 30));
    await _handleResponse(response);
  }

  static Future<List<dynamic>> getPointsTable(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/tournaments/$id/points-table'))
        .timeout(const Duration(seconds: 30));
    return (await _handleResponse(response)) as List<dynamic>;
  }

  // --- Series API ---
  static Future<List<dynamic>> getSeries() async {
    final response = await http.get(Uri.parse('$baseUrl/series'))
        .timeout(const Duration(seconds: 30));
    return (await _handleResponse(response)) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getSeriesById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/series/$id'))
        .timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }

  static Future<Map<String, dynamic>> createSeries(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/series'),
      headers: headers,
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(await _handleResponse(response));
  }
}
