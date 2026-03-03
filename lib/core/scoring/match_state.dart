import 'scoring_enums.dart';
import 'scoring_models.dart';

class MatchState {
  final int over;
  final int ball;
  final int totalRuns;
  final int wickets;
  final String striker;
  final String nonStriker;
  final String bowler;
  final bool isFreeHit;
  final bool isPaused;
  final bool isMatchCompleted;
  final bool inningsCompleted;
  final DeliveryType lastDeliveryType;
  final int? target;
  final int oversLimit;
  final Team? battingTeam;
  final Team? bowlingTeam;

  // Additional state to track internal engine logic (e.g. over completion swap)
  final bool isOverthrow;
  final int lastDeliveryRuns;

  const MatchState({
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
    required this.oversLimit,
    this.target,
    this.isOverthrow = false,
    this.lastDeliveryRuns = 0,
    this.battingTeam,
    this.bowlingTeam,
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
    DeliveryType? lastDeliveryType,
    int? target,
    int? oversLimit,
    bool? isOverthrow,
    int? lastDeliveryRuns,
    Team? battingTeam,
    Team? bowlingTeam,
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
      target: target ?? this.target,
      oversLimit: oversLimit ?? this.oversLimit,
      isOverthrow: isOverthrow ?? this.isOverthrow,
      lastDeliveryRuns: lastDeliveryRuns ?? this.lastDeliveryRuns,
      battingTeam: battingTeam ?? this.battingTeam,
      bowlingTeam: bowlingTeam ?? this.bowlingTeam,
    );
  }

  // Auto Calculations (Requirement 14 & 15)

  double get currentRunRate {
    if (over == 0 && ball == 0) return 0.0;
    double oversBowled = over + (ball / 6.0);
    return totalRuns / oversBowled;
  }

  double? get requiredRunRate {
    if (target == null) return null;
    int runsNeeded = target! - totalRuns;
    if (runsNeeded <= 0) return 0.0;

    int totalBalls = oversLimit * 6;
    int ballsBowled = (over * 6) + ball;
    int ballsRemaining = totalBalls - ballsBowled;

    if (ballsRemaining <= 0) return null;

    return (runsNeeded / ballsRemaining) * 6.0;
  }

  String get matchStatusTag {
    if (isMatchCompleted) return 'COMPLETED';
    if (over == 0 && ball == 0 && totalRuns == 0 && wickets == 0) return 'UPCOMING';
    return 'LIVE';
  }
}

class ScoringException implements Exception {
  final String message;
  ScoringException(this.message);

  @override
  String toString() => 'ScoringException: $message';
}
