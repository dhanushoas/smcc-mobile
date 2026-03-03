import 'match_state.dart';
import 'scoring_enums.dart';

class ValidationService {
  /// 13. MATCH STATE VALIDATION & 9. TEMPORARY PAUSE VALIDATION
  static void validateCanScore(MatchState state) {
    if (state.isPaused) {
      throw ScoringException('Match is paused. Cannot process actions.');
    }
    if (state.isMatchCompleted) {
      throw ScoringException('Match is completed. Cannot process actions.');
    }
    if (state.inningsCompleted) {
      throw ScoringException('Innings is completed. Cannot process actions.');
    }
    if (state.target != null && state.totalRuns >= state.target!) {
      throw ScoringException('Target achieved. Match should be marked complete.');
    }
    if (state.wickets >= 10) {
      throw ScoringException('10 wickets have already fallen.');
    }
    // Prevent scoring if over is completed but bowler hasn't been changed yet
    if (state.ball == 0 && state.over > 0 && state.lastDeliveryRuns != -1) {
       // A weak check for bowler rotation needed. In a real world, we likely evaluate the previous bowler.
       // Because bowler change happens 'after' the 6th ball, the UI should forcibly prompt.
       // E.g. Require passing a 'newBowler' or flag if ball==0 after a completed over.
    }
  }

  /// 4. WICKET LOGIC & 🎯 CRITICAL VALIDATION LIST
  static void validateWicket(MatchState state, WicketType type) {
    validateCanScore(state);

    if (state.isFreeHit) {
      if (type != WicketType.runOut) {
        throw ScoringException('On a Free Hit, only a Run Out is permitted.');
      }
    }
  }

  /// 11. BOWLER CHANGE VALIDATION
  static void validateBowlerChange(MatchState state, bool isInjury) {
    if (state.isMatchCompleted || state.inningsCompleted) {
      throw ScoringException('Cannot change bowler. Innings is complete.');
    }
    
    // Allow bowler change only at over completion OR if bowler injured/retired.
    if (state.ball != 0 && !isInjury) {
      throw ScoringException('Cannot change bowler mid-over unless due to injury.');
    }
  }

  /// 6. LEG BYE / BYE VALIDATION
  static void validateByeOrLegBye(MatchState state, DeliveryType type) {
    if (type == DeliveryType.noBall || type == DeliveryType.wide) {
        throw ScoringException('Cannot combine Leg Bye/Bye with Wide or No Ball delivery type.');
    }
  }

  /// 12. RETIRE BATTER
  static void validateBatterRetire(MatchState state, String batterId, bool wicketFallenOnBall) {
    if (state.striker != batterId && state.nonStriker != batterId) {
      throw ScoringException('Player is neither the striker nor non-striker.');
    }
    if (wicketFallenOnBall) {
      throw ScoringException('Cannot retire if a wicket has already fallen on this delivery.');
    }
  }

  /// 8. DLS BUTTON VALIDATION
  static void validateDLSAccess(MatchState state, bool rainInterruptionFlagged, bool oversReduced) {
    if (!state.isPaused) {
      throw ScoringException('DLS can only be evaluated when the match is paused.');
    }
    if (!rainInterruptionFlagged) {
      throw ScoringException('DLS requires a rain interruption flag.');
    }
    if (!oversReduced) {
      throw ScoringException('DLS requires overs to be reduced to activate.');
    }
  }

  /// 10. STRIKE CHANGE RULES
  static void validateManualStrikeChange(MatchState state, bool isMidDelivery) {
    if (state.isPaused) {
      throw ScoringException('Match is paused. Cannot change strike manually.');
    }
    if (isMidDelivery) {
      throw ScoringException('Cannot manually change strike before the delivery is registered.');
    }
  }

  /// 3. OVERTHROW VALIDATION FIX
  static void validateOverthrow(MatchState state) {
    if (state.isPaused) {
      throw ScoringException('Match is paused. Cannot process overthrow.');
    }
    if (state.inningsCompleted) {
      throw ScoringException('Innings is completed. Cannot process overthrow.');
    }
    if (state.lastDeliveryType == null) {
      throw ScoringException('No last delivery found. Overthrow cannot exist independently.');
    }
  }
}

