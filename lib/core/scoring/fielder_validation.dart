import 'match_state.dart';
import 'scoring_enums.dart';
import 'scoring_models.dart';

class FielderValidationException implements Exception {
  final String message;
  FielderValidationException(this.message);

  @override
  String toString() => 'FielderValidationException: $message';
}

class FielderValidationService {
  /// 1. FIELDER DROPDOWN SOURCE
  /// Returns an array of valid active fielders from the bowling team.
  static List<Player> getAvailableFielders(MatchState state) {
    if (state.bowlingTeam == null) {
      return [];
    }
    
    // Show ONLY bowlingTeam.playingXI where player.isActive == true
    return state.bowlingTeam!.playingXI.where((player) => player.isActive).toList();
  }

  /// 2. WICKET TYPE VALIDATION & 3. VALIDATION RULES
  static void validateWicketFielders({
    required MatchState state,
    required WicketType wicketType,
    Player? primaryFielder,
    Player? assistFielder,
    bool isDirectHit = false,
  }) {
    List<Player> availableFielders = getAvailableFielders(state);

    bool isValidFielder(Player? player) {
      if (player == null) return false;
      return availableFielders.any((f) => f.id == player.id);
    }

    switch (wicketType) {
      case WicketType.bowled:
      case WicketType.lbw:
      case WicketType.hitWicket:
      case WicketType.retired:
        // D) BOWLED (and similar unassisted dismissals): No fielder required.
        break;

      case WicketType.caught:
        // B) CAUGHT: Fielder is mandatory.
        if (primaryFielder == null) {
          throw FielderValidationException('A catcher (fielder) is mandatory for a Caught dismissal.');
        }
        if (!isValidFielder(primaryFielder)) {
          throw FielderValidationException('Selected catcher must be an active player in the bowling team.');
        }
        break;

      case WicketType.stumped:
        // C) STUMPED: Fielder mandatory. Any player can keep wickets (relaxed).
        if (primaryFielder == null) {
          throw FielderValidationException('A defined fielder is mandatory for a Stumped dismissal.');
        }
        if (!isValidFielder(primaryFielder)) {
          throw FielderValidationException('Selected fielder must be an active player in the bowling team.');
        }
        break;

      case WicketType.runOut:
        // A) RUN OUT: Fielder mandatory, keeper included.
        if (primaryFielder == null) {
          throw FielderValidationException('A primary fielder is mandatory for a Run Out dismissal.');
        }
        if (!isValidFielder(primaryFielder)) {
          throw FielderValidationException('Selected primary fielder must be an active player in the bowling team.');
        }

        if (isDirectHit) {
          // If Direct Hit == true: Only one fielder required. Disable assist fielder.
          if (assistFielder != null) {
             throw FielderValidationException('Assist fielder cannot be selected when Direct Hit is true.');
          }
        } else {
          // If Direct Hit == false: Allow optional assist fielder
          if (assistFielder != null) {
             if (!isValidFielder(assistFielder)) {
               throw FielderValidationException('Selected assist fielder must be an active player in the bowling team.');
             }
             if (assistFielder.id == primaryFielder.id) {
               throw FielderValidationException('Assist fielder cannot be the same as the primary fielder.');
             }
          }
        }
        break;
    }
  }
}
