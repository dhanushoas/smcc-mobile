import 'match_state.dart';
import 'match_session.dart';
import 'live_match_integrity.dart';

class LiveFeedValidationService {
  /// 2️⃣ LIVE BADGE VALIDATION
  static bool shouldShowLiveBadge(MatchState state) {
    if (state.isMatchCompleted) return false;
    // Innings started if over > 0 or ball > 0 or totalRuns > 0 or wickets > 0
    if (state.over == 0 && state.ball == 0 && state.totalRuns == 0 && state.wickets == 0) return false;
    return true;
  }

  /// 6️⃣ MATCH IN PROGRESS INDICATOR
  static bool isMatchInProgress(MatchState state) {
    if (state.isMatchCompleted) return false;
    if (shouldShowLiveBadge(state) == false) return false; // Innings must be active
    if (state.target != null && state.totalRuns >= state.target!) return false;
    return true;
  }

  /// 7️⃣ COMPLETED BADGE
  static bool shouldShowCompletedBadge(MatchState state) {
    return state.isMatchCompleted;
  }

  /// 9️⃣ MAN OF THE MATCH
  static bool shouldShowManOfTheMatch(MatchState state, String? momPlayer) {
    if (!state.isMatchCompleted) return false;
    if (momPlayer == null || momPlayer.isEmpty) return false;
    return true;
  }
}

class SafeScoreFormatter {
  /// 3️⃣ SCORE DISPLAY VALIDATION & FORMATTER
  static String formatScore(MatchState state) {
    int totalRuns = state.totalRuns >= 0 ? state.totalRuns : 0;
    int wickets = state.wickets <= 10 ? state.wickets : 10;
    
    int over = state.over;
    int ball = state.ball;
    
    if (ball > 5) ball = 5;
    if (ball < 0) ball = 0;

    return '$totalRuns / $wickets ($over.$ball Overs)';
  }
}

class StrikerIconRenderer {
  /// 1️⃣ Replace striker '*' indicator with 🏏 bat icon.
  static String renderBatterName(MatchState state, String batterId, String batterName) {
    if (state.isMatchCompleted || state.inningsCompleted) return batterName;
    if (state.striker == batterId) {
      return '$batterName 🏏';
    }
    return batterName;
  }
}

class ResultTextGenerator {
  /// 8️⃣ RESULT TEXT VALIDATION
  static String generateResultText(int teamARuns, int teamBRuns, int teamBWickets, int maxWickets, {bool isSuperOver = false}) {
    if (isSuperOver) {
      return 'WON VIA SUPER OVER';
    }

    if (teamARuns > teamBRuns) {
      int margin = teamARuns - teamBRuns;
      return 'WON BY $margin RUNS';
    } else if (teamBRuns > teamARuns) {
      int wicketsRemaining = maxWickets - teamBWickets;
      if (wicketsRemaining < 0) wicketsRemaining = 0;
      return 'WON BY $wicketsRemaining WICKETS';
    } else {
      return 'MATCH TIED';
    }
  }
}

class DataIntegrityValidator {
  /// DATA INTEGRITY CHECK
  static void validateRenderData(MatchSession session) {
    MatchState state = session.currentState;

    // 1. Validate Total Runs
    int calculatedRuns = LiveMatchIntegrityService.calculateTotalRuns(session);
    if (state.totalRuns != calculatedRuns) {
    }

    // 2. Validate Wickets
    int calculatedWickets = LiveMatchIntegrityService.calculateWickets(session);
    if (state.wickets != calculatedWickets) {
    }

    // 3. Current Batter Validation
    if (!state.isMatchCompleted && !state.inningsCompleted && state.over > 0) {
      if (state.striker.isEmpty || state.nonStriker.isEmpty) {
      }
      if (state.striker == state.nonStriker) {
      }
    }

    // 4. Bowler Validation
    if (!state.isMatchCompleted && !state.inningsCompleted && state.over > 0) {
      if (state.bowler.isEmpty) {
      }
    }
  }
}
