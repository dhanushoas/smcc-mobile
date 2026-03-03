class MatchState {
  int over;
  int ball;
  int totalRuns;
  int wickets;
  String striker;
  String nonStriker;
  String bowler;
  bool isFreeHit;
  bool isPaused;
  bool isMatchCompleted;
  bool inningsCompleted;
  String lastDeliveryType;

  MatchState({
    required this.over,
    required this.ball,
    required this.totalRuns,
    required this.wickets,
    required this.striker,
    required this.nonStriker,
    required this.bowler,
    required this.isFreeHit,
    required this.isPaused,
    required this.isMatchCompleted,
    required this.inningsCompleted,
    required this.lastDeliveryType,
  });

  MatchState copyWith({
    int? over,
    int? ball,
    int? totalRuns,
    int? wickets,
    String? striker,
    String? nonStriker,
    String? bowler,
    bool? isFreeHit,
    bool? isPaused,
    bool? isMatchCompleted,
    bool? inningsCompleted,
    String? lastDeliveryType,
  }) {
    return MatchState(
      over: over ?? this.over,
      ball: ball ?? this.ball,
      totalRuns: totalRuns ?? this.totalRuns,
      wickets: wickets ?? this.wickets,
      striker: striker ?? this.striker,
      nonStriker: nonStriker ?? this.nonStriker,
      bowler: bowler ?? this.bowler,
      isFreeHit: isFreeHit ?? this.isFreeHit,
      isPaused: isPaused ?? this.isPaused,
      isMatchCompleted: isMatchCompleted ?? this.isMatchCompleted,
      inningsCompleted: inningsCompleted ?? this.inningsCompleted,
      lastDeliveryType: lastDeliveryType ?? this.lastDeliveryType,
    );
  }
}

enum BallType {
  normal,
  wide,
  noBall,
  bye,
  legBye,
}

enum WhoIsOut {
  striker,
  nonStriker,
}

class RunOutEvent {
  final int runsCompleted;
  final bool isCrossed;
  final WhoIsOut whoIsOut;
  final BallType ballType;
  final String fielder;
  final String newBatsman;

  RunOutEvent({
    required this.runsCompleted,
    required this.isCrossed,
    required this.whoIsOut,
    required this.ballType,
    required this.fielder,
    required this.newBatsman,
  });
}

class RunOutException implements Exception {
  final String message;
  RunOutException(this.message);
  @override
  String toString() => 'RunOutException: $message';
}

class RunOutEngine {
  /// 1. Complete algorithm function
  /// Processes a run out event and returns an updated MatchState object.
  /// Throws a [RunOutException] if validation fails.
  static MatchState processRunOut(MatchState currentState, RunOutEvent event) {
    // 1. Validate the event against current state
    _validateEvent(currentState, event);

    // Provide a mutable working copy
    MatchState nextState = currentState.copyWith();

    // 2. Determine Extras and Legality based on Ball Type
    int extraRuns = 0;
    bool isLegalDelivery = false;
    
    switch (event.ballType) {
      case BallType.wide:
      case BallType.noBall:
        extraRuns = 1; // 1 extra run for wide or no ball
        isLegalDelivery = false; // Does not count as a legal ball
        break;
      case BallType.normal:
      case BallType.bye:
      case BallType.legBye:
        isLegalDelivery = true; // Counts as a legal ball
        break;
    }

    // 3. Update Runs
    nextState.totalRuns += event.runsCompleted + extraRuns;
    nextState.lastDeliveryType = event.ballType.toString();

    // 4. Update Free Hit Status
    if (nextState.isFreeHit) {
      // Free hit continues if the ball was a wide or no-ball, otherwise it ends
      if (event.ballType == BallType.normal || 
          event.ballType == BallType.bye || 
          event.ballType == BallType.legBye) {
        nextState.isFreeHit = false;
      }
    } else {
      // If the ball was a no-ball, the NEXT ball is a free hit
      if (event.ballType == BallType.noBall) {
         nextState.isFreeHit = true;
      }
    }

    // 5. Update Ball and Over Count
    bool overCompleted = false;
    if (isLegalDelivery) {
      nextState.ball += 1;
      if (nextState.ball == 6) {
        overCompleted = true;
        nextState.ball = 0;
        nextState.over += 1;
        // The bowler will need to change, handled by UI/outer system
      }
    }

    // 6. Update Wickets
    nextState.wickets += 1;
    if (nextState.wickets == 10) {
      nextState.inningsCompleted = true;
      // Depending on context, match might also be completed here
    }

    // 7. Strike Update Logic
    // Step 1: provisionalStrikeSwap
    bool provisionalStrikeSwap = (event.runsCompleted % 2 != 0);

    // Step 2: Crossing logic
    // We need to know who the survivor is
    String survivor;
    String newEndsSurvivor;
    
    if (event.whoIsOut == WhoIsOut.striker) {
      survivor = currentState.nonStriker;
    } else {
      survivor = currentState.striker;
    }

    // Determine the survivor's intended new end based on completed runs
    // If runs are ODD, and survivor was nonStriker -> intended end is STRIKER end
    // If runs are ODD, and survivor was striker -> intended end is NON-STRIKER end
    // If runs are EVEN, they intend to stay at their ORIGINAL end.
    
    bool survivorAtStrikerEndProvisional = false;
    
    if (event.whoIsOut == WhoIsOut.striker) {
        // Survivor = NonStriker. Intended end = striker end ONLY if runs are odd.
        survivorAtStrikerEndProvisional = provisionalStrikeSwap;
    } else {
        // Survivor = Striker. Intended end = non-striker end if runs are odd, striker end if even.
        survivorAtStrikerEndProvisional = !provisionalStrikeSwap;
    }

    // Step 2 Explicit Rule:
    // If isCrossed == true: survivor stays at new end (which is the incomplete run's destination)
    // Else: survivor returns to original end (before the incomplete run started)
    // 
    // The "incomplete run" implies they were running another run.
    // E.g., 1 run completed. They try for a 2nd. 
    // Original end before 2nd run: For Striker, it's NonStriker end. For NonStriker, it's Striker end.
    // New end: For Striker, it's Striker end. For NonStriker, it's NonStriker end.
    
    if (event.isCrossed) {
         // Stay at the new end. This reverses the provisional outcome of completed runs.
         survivorAtStrikerEndProvisional = !survivorAtStrikerEndProvisional;
    } else {
         // Return to original end (which is exactly what the completed runs dictated)
         // So no change to survivorAtStrikerEndProvisional.
    }

    // Step 3: Apply final strike layout
    if (survivorAtStrikerEndProvisional) {
      nextState.striker = survivor;
      nextState.nonStriker = event.newBatsman;
    } else {
      nextState.striker = event.newBatsman;
      nextState.nonStriker = survivor;
    }

    // 8. Over Completion Rule
    // If ball increments and ball == 6 -> auto swap strike
    if (overCompleted) {
      // Swap striker and non-striker
      String temp = nextState.striker;
      nextState.striker = nextState.nonStriker;
      nextState.nonStriker = temp;
    }

    return nextState;
  }

  /// 2. Validation function
  static void _validateEvent(MatchState state, RunOutEvent event) {
    if (state.isPaused) {
      throw RunOutException('Match is paused. Cannot process run out.');
    }
    if (state.isMatchCompleted) {
      throw RunOutException('Match is completed. Cannot process run out.');
    }
    if (state.inningsCompleted) {
      throw RunOutException('Innings is completed. Cannot process run out.');
    }
    if (state.wickets >= 10) {
      throw RunOutException('Team is already all out (10 wickets).');
    }
    if (event.fielder.trim().isEmpty) {
      throw RunOutException('Fielder is required for a run out.');
    }
    if (event.runsCompleted < 0) {
      throw RunOutException('Runs completed cannot be negative.');
    }
    // Hard boundary requirement (e.g., max 4 runs)
    if (event.runsCompleted > 4) {
      throw RunOutException('Runs completed exceeds realistic boundary (max 4).');
    }
    if (event.runsCompleted == 0 && event.isCrossed) {
      throw RunOutException('Cannot cross if 0 runs have been completed. (Invalid case: 0 runs + crossed true)');
    }
    // Note: newBatsman validation could also go here if required
    if (event.newBatsman.trim().isEmpty) {
      throw RunOutException('New batsman must be identified.');
    }
  }
}
