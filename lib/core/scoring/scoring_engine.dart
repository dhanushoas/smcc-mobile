import 'match_state.dart';
import 'scoring_enums.dart';
import 'scoring_events.dart';
import 'scoring_validation.dart';
import 'free_hit_state_machine.dart';
import 'strike_rotation_service.dart';

class ScoringEngine {

  /// Core Facade for Scoring Runs
  static MatchState scoreRuns(
    MatchState currentState,
    int runs,
    DeliveryType type,
  ) {
    // 1. Initial Gatekeeping
    ValidationService.validateCanScore(currentState);
    
    // 2. Leg Bye / Bye Validations (Requirements 6)
    if (type == DeliveryType.bye || type == DeliveryType.legBye) {
      ValidationService.validateByeOrLegBye(currentState, type);
    }

    MatchState nextState = currentState.copyWith(
      lastDeliveryType: type,
      lastDeliveryRuns: runs,
    );

    // 3. Process Extras and Ball Counters
    int extras = 0;
    bool isLegal = false;

    switch (type) {
      case DeliveryType.normal:
      case DeliveryType.bye:
      case DeliveryType.legBye:
        isLegal = true;
        break;
      case DeliveryType.wide:
      case DeliveryType.noBall:
        extras += 1; // 1 run penalty added for Wide or No Ball automatically (Req 1 & 2)
        isLegal = false;
        break;
      case DeliveryType.penalty:
        // Optional placeholder based on Enum. Follows similar uncounted logic.
        isLegal = false;
        break;
    }

    // 4. Update Runs
    nextState = nextState.copyWith(
      totalRuns: nextState.totalRuns + runs + extras,
    );

    // 5. Update Free Hit State
    bool nextFreeHit = FreeHitStateMachine.getNextFreeHitState(currentState.isFreeHit, type);
    nextState = nextState.copyWith(isFreeHit: nextFreeHit);

    // 6. Advance Ball Count & Check Completion
    bool overCompleted = false;

    if (isLegal) {
      // 3. Increment ball count
      int targetBall = nextState.ball + 1;
      
      if (targetBall == 6) {
        // OVER COMPLETION RULE
        targetBall = 0;
        overCompleted = true;
        nextState = nextState.copyWith(
          ball: targetBall,
          over: nextState.over + 1,
        );
      } else {
        nextState = nextState.copyWith(ball: targetBall);
      }
    }

    // 7. Auto-Swap Strike Rule
    // Requirement 3: Increment striker/non-striker -> If odd run -> swap strike.
    // If over completes -> auto swap strike.
    
    // If isOverthrow, runs still physically ran by batters + overthrow boundary. 
    // Requirement is physical runs, but usually total runs (excluding penalty 1) dictates the ends.
    nextState = StrikeRotationService.evaluateStrikeRotation(nextState, runs);

    if (overCompleted) {
      // Auto swap if over just completed
      nextState = StrikeRotationService.swapStrike(nextState);
    }

    return nextState;
  }

  /// Core Facade for Wickets
  static MatchState recordWicket(
    MatchState currentState,
    WicketType type, {
    RunOutDetails? runOut,
    DeliveryType currentDeliveryType = DeliveryType.normal,
  }) {
    // 1. Initial Gatekeeping (Blocks Wickets on Free Hits unless Run Out)
    ValidationService.validateWicket(currentState, type);

    MatchState nextState = currentState.copyWith(
       lastDeliveryType: currentDeliveryType,
    );

    if (type == WicketType.runOut && runOut != null) {
        // Run out handler
        nextState = nextState.copyWith(totalRuns: nextState.totalRuns + runOut.runsCompleted);
        
        bool survivorAtStrikerEnd = (runOut.runsCompleted % 2 != 0);
        if (runOut.isCrossed) survivorAtStrikerEnd = !survivorAtStrikerEnd;

        String survivor = runOut.isStrikerOut ? nextState.nonStriker : nextState.striker;
        
        if (survivorAtStrikerEnd) {
           nextState = nextState.copyWith(striker: survivor, nonStriker: runOut.newBatsmanId);
        } else {
           nextState = nextState.copyWith(striker: runOut.newBatsmanId, nonStriker: survivor);
        }
    } else {
        // Normal Wickets replace striker
        if (type != WicketType.retired) {
           // Requirements specify placing the new batsman at the striker's end for standard wickets (Bowled, LBW, Caught*, Stumped)
           // *Note: new laws stipulate new batter takes strike on catch regardless of crossing.
           nextState = nextState.copyWith(striker: 'Pending Batsman'); // In reality, we pass newBatterId directly to this function
        }
    }

    // Fall of wicket
    nextState = nextState.copyWith(wickets: nextState.wickets + 1);
    
    if (nextState.wickets >= 10) {
      nextState = nextState.copyWith(inningsCompleted: true);
    }

    // 2. Free Hit State
    bool nextFreeHit = FreeHitStateMachine.getNextFreeHitState(currentState.isFreeHit, currentDeliveryType);
    nextState = nextState.copyWith(isFreeHit: nextFreeHit);

    // 3. Ball Count (Wickets on Legals vs Illegals)
    bool isLegal = (currentDeliveryType != DeliveryType.wide && currentDeliveryType != DeliveryType.noBall);
    
    if (isLegal) {
      int targetBall = nextState.ball + 1;
      if (targetBall == 6) {
        targetBall = 0;
        nextState = nextState.copyWith(
          ball: targetBall,
          over: nextState.over + 1,
        );
        nextState = StrikeRotationService.swapStrike(nextState);
      } else {
        nextState = nextState.copyWith(ball: targetBall);
      }
    }

    return nextState;
  }

  /// Core Facade for Manual Updates
  static MatchState changeBowler(MatchState currentState, String newBowler, {bool isInjury = false}) {
    ValidationService.validateBowlerChange(currentState, isInjury);
    return currentState.copyWith(bowler: newBowler);
  }

  static MatchState retireBatter(MatchState currentState, String batterId, {bool wicketFallenOnBall = false}) {
    ValidationService.validateBatterRetire(currentState, batterId, wicketFallenOnBall);
    // Treat as wicket
    return recordWicket(currentState, WicketType.retired);
  }

  /// 3. OVERTHROW FIX
  static MatchState applyOverthrow(MatchState currentState, int overthrowRuns) {
    ValidationService.validateCanScore(currentState);
    ValidationService.validateOverthrow(currentState);

    // Explictly avoids advancing ball count or over count.
    MatchState nextState = currentState.copyWith(
      totalRuns: currentState.totalRuns + overthrowRuns,
    );

    // Overthrow rotation: If odd extra runs applied from overthrow, swap strike.
    if (overthrowRuns % 2 != 0) {
      nextState = StrikeRotationService.swapStrike(nextState);
    }
    
    return nextState;
  }

  /// 2. TEMPORARY PAUSE FIX
  static MatchState pauseMatch(MatchState currentState) {
    return currentState.copyWith(isPaused: true);
  }

  static MatchState resumeMatch(MatchState currentState) {
    return currentState.copyWith(isPaused: false);
  }
}

