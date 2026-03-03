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
    return _translations['en']?[key] ?? key;
  }

  final Map<String, Map<String, String>> _translations = {
    'en': {
      'live_scores': 'Live Cricket Scores',
      'real_time_updates': 'Real-time updates from SMCC LIVE',
      'real_time_intelligence': 'Real-time Cricket Intelligence',
      'home': 'Home',
      'admin': 'Admin',
      'login': 'Login',
      'logout': 'Logout',
      'full_scorecard': 'Full Scorecard',
      'live': 'LIVE',
      'upcoming': 'UPCOMING',
      'completed': 'COMPLETED',
      'batter': 'Batter',
      'bowler': 'Bowler',
      'runs': 'Runs',
      'balls': 'Balls Faced',
      'fours': 'Fours',
      'sixes': 'Sixes',
      'sr': 'Strike Rate',
      'overs': 'Overs Bowled',
      'maidens': 'Maiden Overs',
      'wickets': 'Wickets Taken',
      'eco': 'Economy Rate',
      'extras': 'Extras',
      'total': 'Total',
      'match_info': 'Match Info',
      'series': 'Series',
      'venue': 'Venue',
      'date': 'Date',
      'man_of_the_match': 'Man of the Match',
      'no_matches': 'No matches scheduled',
      'check_back': 'Check back later for real-time updates.',
      'start_match': 'Start Match',
      'new_match': 'New Match',
      'score_updated': 'Score Updated!',
      'striker': 'Striker',
      'non_striker': 'Non-Striker',
      'batting': 'Batting',
      'bowling': 'Bowling',
      'out': 'OUT',
      'retire': 'RETIRE',
      'wd': 'Wide Ball',
      'nb': 'No Ball',
      'targets': 'Target',
      'total_overs': 'Total Overs',
      'runs_needed': 'Runs Needed',
      'from': 'from',
      'balls_rem': 'Balls Remaining',
      'innings_break': 'Innings Break',
      'close': 'Close', // Keep from previous Dart list
    },
    'ta': {
      'live_scores': 'நேரடி கிரிக்கெட் முடிவுகள்',
      'real_time_updates': 'SMCC LIVE-இன் நேரடி அறிவிப்புகள்',
      'real_time_intelligence': 'நிகழ்நேர கிரிக்கெட் நுண்ணறிவு',
      'home': 'முகப்பு',
      'admin': 'நிர்வாகி',
      'login': 'உள்நுழை',
      'logout': 'வெளியேறு',
      'full_scorecard': 'முழு மதிப்பெண் பட்டியல்',
      'live': 'நேரடி',
      'upcoming': 'வரவிருக்கும்',
      'completed': 'முடிந்தது',
      'batter': 'பேட்ஸ்மேன்',
      'bowler': 'பந்துவீச்சாளர்',
      'runs': 'ஓட்டங்கள்',
      'balls': 'பந்துகள்',
      'fours': 'நான்குகள்',
      'sixes': 'ஆறுகள்',
      'sr': 'திறன் விகிதம்',
      'overs': 'ஓவர்கள்',
      'maidens': 'மெய்டன்',
      'wickets': 'விக்கெட்டுகள்',
      'eco': 'எகானமி',
      'extras': 'உதிரிகள்',
      'total': 'மொத்தம்',
      'match_info': 'போட்டி விபரம்',
      'series': 'தொடர்',
      'venue': 'இடம்',
      'date': 'தேதி',
      'man_of_the_match': 'ஆட்டநாயகன்',
      'no_matches': 'போட்டிகள் இல்லை',
      'check_back': 'நேரடி அறிவிப்புகளுக்குப் பிறகு பார்க்கவும்.',
      'start_match': 'போட்டியைத் தொடங்கு',
      'new_match': 'புதிய போட்டி',
      'score_updated': 'மதிப்பெண் புதுப்பிக்கப்பட்டது!',
      'striker': 'முனைவர்',
      'non_striker': 'மறுமுனைவர்',
      'batting': 'பேட்டிங்',
      'bowling': 'பந்துவீச்சு',
      'out': 'அவுட்',
      'retire': 'ஓய்வு',
      'wd': 'வைட்',
      'nb': 'நோ பால்',
      'targets': 'இலக்கு',
      'total_overs': 'மொத்த ஓவர்கள்',
      'runs_needed': 'Runs Needed', // adding default for ta
      'from': 'from', // adding default for ta
      'balls_rem': 'Balls Remaining', // adding default for ta
      'innings_break': 'Innings Break', // adding default for ta
      'close': 'Close', // adding default for ta
    }
  };
}
