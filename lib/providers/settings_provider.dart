import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;
  String _language = 'en';

  bool get isDarkMode => _isDarkMode;
  String get language => _language;

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    _language = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('darkMode', _isDarkMode);
    notifyListeners();
  }

  void setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('language', _language);
    notifyListeners();
  }

  String translate(String key) {
    if (_language == 'ta') {
      return _translations['ta']?[key] ?? key;
    }
    return _translations['en']?[key] ?? key;
  }

  final Map<String, Map<String, String>> _translations = {
    'en': {
      'live_scores': 'Live Cricket Scores',
      'home': 'Home',
      'admin': 'Admin',
      'login': 'Login',
      'full_scorecard': 'Full Scorecard',
      'batting': 'BATTING',
      'bowling': 'BOWLING',
      'man_of_the_match': 'Man of the Match',
      'no_matches': 'No Active Matches',
      'live': 'LIVE',
      'close': 'Close',
      'batter': 'Batter',
      'runs': 'R',
      'balls': 'B',
      'sr': 'SR',
      'extras': 'Extras',
      'total': 'Total',
      'overs': 'Ov',
      'match_info': 'Match Info',
      'series': 'Series',
      'venue': 'Venue',
      'date': 'Date',
      'total_overs': 'Total Overs',
    },
    'ta': {
      'live_scores': 'நேரடி மதிப்பெண்கள்',
      'home': 'முகப்பு',
      'admin': 'நிர்வாகி',
      'login': 'உள்நுழை',
      'full_scorecard': 'முழு மதிப்பெண்',
      'batting': 'பேட்டிங்',
      'bowling': 'பந்துவீச்சு',
      'man_of_the_match': 'ஆட்டநாயகன்',
      'no_matches': 'போட்டிகள் எதுவுமில்லை',
      'live': 'நேரடி',
      'close': 'மூடு',
      'batter': 'பேட்ஸ்மேன்',
      'runs': 'ஓ',
      'balls': 'ப',
      'sr': 'திறன்',
      'extras': 'உதிரிகள்',
      'total': 'மொத்தம்',
      'overs': 'ஓவர்',
      'match_info': 'போட்டி விபரம்',
      'series': 'தொடர்',
      'venue': 'இடம்',
      'date': 'தேதி',
      'total_overs': 'மொத்த ஓவர்கள்',
    }
  };
}
