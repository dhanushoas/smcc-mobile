import 'match_state.dart';
import 'scoring_enums.dart';
import 'scoring_validation.dart';
import 'scoring_engine.dart';
import 'scoring_events.dart';

class MatchSession {
  final MatchState currentState;
  final List<MatchState> deliveryHistory;
  final List<ScoringEvent> eventHistory;

  const MatchSession({
    required this.currentState,
    this.deliveryHistory = const [],
    this.eventHistory = const [],
  });

  MatchSession copyWith({
    MatchState? currentState,
    List<MatchState>? deliveryHistory,
    List<ScoringEvent>? eventHistory,
  }) {
    return MatchSession(
      currentState: currentState ?? this.currentState,
      deliveryHistory: deliveryHistory ?? this.deliveryHistory,
      eventHistory: eventHistory ?? this.eventHistory,
    );
  }

  /// 1️⃣ REVERSE LAST ACTION FIX
  MatchSession reverseLastAction() {
    if (deliveryHistory.isEmpty) return this;
    
    List<MatchState> historyCopy = List.from(deliveryHistory);
    MatchState previousState = historyCopy.removeLast();

    List<ScoringEvent> eventCopy = List.from(eventHistory);
    if (eventCopy.isNotEmpty) eventCopy.removeLast();

    // Reverse must pop last state and restore it perfectly without triggering scoring logic
    return copyWith(
      currentState: previousState,
      deliveryHistory: historyCopy,
      eventHistory: eventCopy,
    );
  }

  /// 6️⃣ APPLY DELIVERY
  MatchSession applyDelivery(int runs, DeliveryType type) {
    List<MatchState> historyCopy = List.from(deliveryHistory);
    // Push deep copy into history before mutating
    historyCopy.add(currentState.copyWith());

    List<ScoringEvent> eventCopy = List.from(eventHistory);
    eventCopy.add(ScoringEvent(type: type, runs: runs));

    MatchState nextState = ScoringEngine.scoreRuns(currentState, runs, type);
    
    return copyWith(
      currentState: nextState,
      deliveryHistory: historyCopy,
      eventHistory: eventCopy,
    );
  }

  /// WICKET INTEGRATION
  MatchSession recordWicket(WicketType type, {RunOutDetails? runOut, DeliveryType currentDeliveryType = DeliveryType.normal}) {
     List<MatchState> historyCopy = List.from(deliveryHistory);
     historyCopy.add(currentState.copyWith());

     List<ScoringEvent> eventCopy = List.from(eventHistory);
     int runs = runOut?.runsCompleted ?? 0;
     eventCopy.add(ScoringEvent(type: currentDeliveryType, runs: runs, isWicket: true));

     MatchState nextState = ScoringEngine.recordWicket(currentState, type, runOut: runOut, currentDeliveryType: currentDeliveryType);

     return copyWith(
       currentState: nextState,
       deliveryHistory: historyCopy,
       eventHistory: eventCopy,
     );
  }

  /// 3️⃣ OVERTHROW FIX
  MatchSession applyOverthrow(int extraRuns) {
    List<MatchState> historyCopy = List.from(deliveryHistory);
    historyCopy.add(currentState.copyWith());

    List<ScoringEvent> eventCopy = List.from(eventHistory);
    // Overthrows attach to the last event logically, but for data validation completeness we log the extension
    eventCopy.add(ScoringEvent(type: currentState.lastDeliveryType, runs: 0, overthrows: extraRuns));

    MatchState nextState = ScoringEngine.applyOverthrow(currentState, extraRuns);

    return copyWith(
      currentState: nextState,
      deliveryHistory: historyCopy,
      eventHistory: eventCopy,
    );
  }

  /// 2️⃣ TEMPORARY PAUSE FIX
  MatchSession pauseMatch() {
    // Does not mutate history, just toggles pause
    return copyWith(
      currentState: ScoringEngine.pauseMatch(currentState),
    );
  }

  MatchSession resumeMatch() {
    return copyWith(
      currentState: ScoringEngine.resumeMatch(currentState),
    );
  }
}
