import 'match_state.dart';

class StrikeRotationService {
  /// 10. STRIKE CHANGE RULES
  /// Auto changes strike based on completed physical runs.
  static MatchState evaluateStrikeRotation(MatchState currentState, int runsCompleted, {bool forceSwap = false}) {
    // We operate on a copy of the state
    MatchState nextState = currentState.copyWith();

    bool shouldSwap = forceSwap;

    // "Auto change strike if: 1 run, 3 runs, 5 runs"
    if (!forceSwap && runsCompleted > 0 && runsCompleted % 2 != 0) {
      shouldSwap = true;
    }

    if (shouldSwap) {
      nextState = _swapStrike(nextState);
    }

    return nextState;
  }

  /// Automatically swap strike. E.g., at end of over.
  static MatchState swapStrike(MatchState currentState) {
    return _swapStrike(currentState.copyWith());
  }

  static MatchState _swapStrike(MatchState state) {
    String temp = state.striker;
    return state.copyWith(
      striker: state.nonStriker,
      nonStriker: temp,
    );
  }
}
