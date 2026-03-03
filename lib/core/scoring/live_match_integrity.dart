import 'match_state.dart';
import 'match_session.dart';
import 'scoring_enums.dart';
import 'scoring_events.dart';

class LiveMatchIntegrityService {
  /// 6️⃣ SAFE OVER/BALL FORMATTER
  static String formatOvers(int over, int ball) {
    if (ball < 0 || ball > 5) {
      throw Exception('Integrity Error: Ball must be strictly between 0 and 5.');
    }
    return '$over.$ball Overs';
  }

  /// 5️⃣ LAST BALL EVENTS VALIDATION
  static List<DeliveryType> getLastOverEvents(MatchSession session) {
    // Order matters: most recent first or standard L-R based on UI needs.
    // Display last over events up to 6 legal balls + any extras inside it.
    List<DeliveryType> timeline = [];
    int legalCount = 0;
    
    for (int i = session.eventHistory.length - 1; i >= 0; i--) {
      ScoringEvent event = session.eventHistory[i];
      timeline.insert(0, event.type);
      
      if (event.type == DeliveryType.normal || 
          event.type == DeliveryType.bye || 
          event.type == DeliveryType.legBye) {
        legalCount++;
      }
      
      if (legalCount >= 6) {
        break; 
      }
    }
    return timeline;
  }

  /// 1️⃣ SCORE VALIDATION (Calculate from true history)
  static int calculateTotalRuns(MatchSession session) {
    int total = 0;
    for (var event in session.eventHistory) {
      total += event.totalRuns; // Extrapolates runs + extras + overthrows
    }
    return total;
  }

  static int calculateWickets(MatchSession session) {
    int w = 0;
    for (var event in session.eventHistory) {
      if (event.isWicket) w += 1;
    }
    return w;
  }

  /// 7️⃣ DATA CONSISTENCY CHECK
  static void validateLivePage(MatchSession session) {
    MatchState state = session.currentState;

    // 1. Validate runs recursively from history. If false, log error. 
    // It must NEVER manual increment independently.
    validateTotalRuns(session);

    // 2. Validate over and ball properties explicitly.
    if (state.ball < 0 || state.ball > 5) {
      print('Integrity Error: Ball count out of bounds.');
    }
    if (state.wickets > 10) {
      print('Integrity Error: Wickets logically cannot exceed 10.');
    }

    // 3. Status checks
    String status = state.matchStatusTag;
    if (status != 'UPCOMING' && status != 'LIVE' && status != 'COMPLETED') {
      print('Integrity Error: Invalid match status tag.');
    }

    // 4. Validate Batters on Live state.
    if (status == 'LIVE') {
       if (state.striker.isEmpty || state.nonStriker.isEmpty) {
          print('Integrity Error: Exactly 2 active batters must exist during a live match.');
       }
       if (state.striker == state.nonStriker) {
          print('Integrity Error: Striker and nonStriker are duplicated to the same player.');
       }
       if (state.bowler.isEmpty) {
          print('Integrity Error: Bowler is missing during a live match.');
       }
       
       // Note: Domain models hold team limits, so if teams are attached, 
       // one could theoretically validate striker == batsman in playingXI
    }
  }

  static void validateTotalRuns(MatchSession session) {
     int calculatedRuns = calculateTotalRuns(session);
     if (session.currentState.totalRuns != calculatedRuns) {
       print('CRITICAL INTEGRITY ERROR: displayedTotalRuns (${session.currentState.totalRuns}) != calculatedTotalRunsFromHistory ($calculatedRuns)');
     }

     int calculatedWickets = calculateWickets(session);
     if (session.currentState.wickets != calculatedWickets) {
       print('CRITICAL INTEGRITY ERROR: displayedWickets (${session.currentState.wickets}) != historyWickets ($calculatedWickets)');
     }

     if (session.currentState.totalRuns < 0) {
       print('CRITICAL INTEGRITY ERROR: Total runs logically cannot be negative.');
     }
  }
}
