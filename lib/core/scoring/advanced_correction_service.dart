import 'match_state.dart';
import 'match_session.dart';
import 'live_match_integrity.dart';

enum AdminRole { umpire, scorer, admin, superAdmin }

class CorrectionAuditLog {
  final String action;
  final String details;
  final DateTime timestamp;

  CorrectionAuditLog({
    required this.action,
    required this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  @override
  String toString() => '[$timestamp] $action: $details';
}

class AdvancedCorrectionValidator {
  static void validateSuperAdmin(AdminRole role) {
    if (role != AdminRole.superAdmin) {
      throw Exception('Access Denied: Advanced corrections require SUPER_ADMIN role.');
    }
  }

  static void validateRuns(int runs) {
    if (runs < 0 || runs > 999) {
      throw Exception('Runs must be an integer between 0 and 999.');
    }
  }

  static void validateWickets(int wickets, {int dismissedPlayersCount = 0}) {
    if (wickets < 0 || wickets > 10) {
      throw Exception('Wickets must be between 0 and 10.');
    }
    if (wickets < dismissedPlayersCount) {
      throw Exception('Wickets cannot be less than the number of recorded dismissed players.');
    }
  }

  static void validateOvers(int over, int ball, int maxOvers) {
    if (ball < 0 || ball > 5) {
      throw Exception('Ball must be between 0 and 5.');
    }
    if (over > maxOvers || (over == maxOvers && ball > 0)) {
      throw Exception('Total overs cannot exceed match limit of $maxOvers.');
    }
  }

  static String validateText(String text, {int minLength = 0, int maxLength = 100, String fieldName = "Text"}) {
    if (text.isEmpty) throw Exception('$fieldName cannot be empty.');
    // Basic HTML stripping
    final String stripped = text.replaceAll(RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true), '').trim();
    if (stripped.length < minLength || stripped.length > maxLength) {
      throw Exception('$fieldName length must be between $minLength and $maxLength characters.');
    }
    return stripped;
  }

  static void validateBatters(String striker, String nonStriker, List<dynamic> battingTeamPlayers) {
    if (striker.isEmpty || nonStriker.isEmpty) throw Exception('Striker and Non-Striker are required.');
    if (striker == nonStriker) throw Exception('Striker and Non-Striker cannot be the same player.');
    
    List<String> validIds = battingTeamPlayers.map((p) => p.toString()).toList();
    // Assuming UI passes simple strings or Player objects whose toString/id gets extracted upstream
    if (!validIds.contains(striker) || !validIds.contains(nonStriker)) {
      throw Exception('Batters must belong to the active batting team squad.');
    }
  }

  static void validateBowler(String bowler, List<dynamic> bowlingTeamPlayers) {
    if (bowler.isEmpty) throw Exception('Bowler is required.');
    List<String> validIds = bowlingTeamPlayers.map((p) => p.toString()).toList();
    if (!validIds.contains(bowler)) {
      throw Exception('Bowler must belong to the active bowling team squad.');
    }
  }

  static void validatePOTM(String potm, bool isCompleted) {
    if (!isCompleted) throw Exception('Player of the Match can only be selected after match completion.');
  }

  static void validateDateTime(String dateStr, String timeStr) {
    final RegExp timeExp = RegExp(r"^(0?[1-9]|1[0-2]):[0-5][0-9]\s(AM|PM)$", caseSensitive: false);
    if (!timeExp.hasMatch(timeStr.trim())) {
      throw Exception('Time must be in 12-hour format (hh:mm AM/PM).');
    }
    if (DateTime.tryParse(dateStr) == null) {
      throw Exception('Invalid Date format.');
    }
  }
}

class AdvancedCorrectionService {
  final MatchSession session;
  final AdminRole adminRole;
  final List<CorrectionAuditLog> auditLogs;

  AdvancedCorrectionService({
    required this.session,
    required this.adminRole,
    List<CorrectionAuditLog>? auditLogs,
  }) : auditLogs = auditLogs ?? [] {
    AdvancedCorrectionValidator.validateSuperAdmin(adminRole);
  }

  void _logAction(String action, String details) {
    final log = CorrectionAuditLog(action: action, details: details);
    auditLogs.add(log);
    // Mimic the JS print warn for debugging audit logs in console
    print('[AUDIT_LOG] ${log.timestamp} | ${log.action}: ${log.details}');
  }

  void _recalculateAndSync() {
    int historyRuns = LiveMatchIntegrityService.calculateTotalRuns(session);
    int historyWickets = LiveMatchIntegrityService.calculateWickets(session);
    
    if (session.currentState.totalRuns != historyRuns) {
      print('CRITICAL: Overridden totalRuns (${session.currentState.totalRuns}) decoupled from mathematical history ($historyRuns). SUPER ADMIN Overrided.');
    }
    if (session.currentState.wickets != historyWickets) {
      print('CRITICAL: Overridden wickets (${session.currentState.wickets}) decoupled from mathematical history ($historyWickets). SUPER ADMIN Overrided.');
    }
  }

  MatchSession overrideScore(int newRuns, int newWickets, int newOver, int newBall, {int totalOversLimit = 20}) {
    AdvancedCorrectionValidator.validateRuns(newRuns);
    AdvancedCorrectionValidator.validateWickets(newWickets);
    AdvancedCorrectionValidator.validateOvers(newOver, newBall, totalOversLimit);

    MatchState state = session.currentState.copyWith(
      totalRuns: newRuns,
      wickets: newWickets,
      over: newOver,
      ball: newBall,
      inningsCompleted: (newWickets == 10) ? true : session.currentState.inningsCompleted,
    );

    session.currentState = state;
    _logAction('OVERRIDE_SCORE', 'Runs: $newRuns, Wickets: $newWickets, Overs: $newOver.$newBall');
    _recalculateAndSync();
    return session;
  }

  MatchSession overrideActivePlayers(String striker, String nonStriker, String bowler, List<dynamic> batSquad, List<dynamic> bowlSquad) {
    AdvancedCorrectionValidator.validateBatters(striker, nonStriker, batSquad);
    AdvancedCorrectionValidator.validateBowler(bowler, bowlSquad);

    session.currentState = session.currentState.copyWith(
      striker: striker,
      nonStriker: nonStriker,
      bowler: bowler,
    );

    _logAction('OVERRIDE_PLAYERS', 'Striker: $striker, NonStriker: $nonStriker, Bowler: $bowler');
    _recalculateAndSync();
    return session;
  }
  
  MatchSession overridePOTM(String potm) {
    AdvancedCorrectionValidator.validatePOTM(potm, session.currentState.isMatchCompleted);
    _logAction('OVERRIDE_POTM', 'POTM set to $potm');
    return session;
  }

  MatchSession forceEndInnings() {
    session.currentState = session.currentState.copyWith(inningsCompleted: true);
    _logAction('FORCE_END_INNINGS', 'Admin forced end of innings.');
    return session;
  }

  MatchSession clearCurrentOverLog() {
    int currentOver = session.currentState.over;
    // Just pop 6 events roughly representing the last over or balls bowled
    for(int i = 0; i < 6; i++) {
        if(session.eventHistory.isNotEmpty) {
            session.eventHistory.removeLast();
        }
    }
    _logAction('CLEAR_OVER_LOG', 'Admin stripped recent ball history logs for Over $currentOver');
    _recalculateAndSync();
    return session;
  }

  MatchSession purgeAllHistory(String adminPassword) {
    if (adminPassword != "CONFIRM_PURGE") {
      throw Exception("Invalid admin password for purge operation.");
    }
    
    session.eventHistory.clear();
    session.deliveryHistory.clear();
    
    session.currentState = session.currentState.copyWith(
      totalRuns: 0,
      wickets: 0,
      over: 0,
      ball: 0,
      inningsCompleted: false,
      isMatchCompleted: false,
    );

    _logAction('PURGE_ALL_HISTORY', 'COMPLETE MATCH STATE PURGED BY SUPER ADMIN');
    _recalculateAndSync();
    return session;
  }
}
