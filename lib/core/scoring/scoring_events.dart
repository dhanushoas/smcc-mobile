import 'scoring_enums.dart';

class RunOutDetails {
  final int runsCompleted;
  final bool isCrossed;
  final bool isStrikerOut;
  final String newBatsmanId;

  const RunOutDetails({
    required this.runsCompleted,
    required this.isCrossed,
    required this.isStrikerOut,
    required this.newBatsmanId,
  });
}

class ScoringEvent {
  final DeliveryType type;
  final int runs;
  final int overthrows;
  final bool isWicket;

  const ScoringEvent({
    required this.type,
    this.runs = 0,
    this.overthrows = 0,
    this.isWicket = false,
  });

  int get extras {
    if (type == DeliveryType.wide || type == DeliveryType.noBall) {
      return 1;
    }
    return 0;
  }

  int get totalRuns => runs + extras + overthrows;
}
