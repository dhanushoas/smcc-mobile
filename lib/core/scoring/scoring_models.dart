import 'scoring_enums.dart';

class Player {
  final String id;
  final String name;
  final PlayerRole role;
  final bool isActive;

  const Player({
    required this.id,
    required this.name,
    required this.role,
    this.isActive = true,
  });
}

class Team {
  final String id;
  final String name;
  final List<Player> playingXI;

  const Team({
    required this.id,
    required this.name,
    required this.playingXI,
  });
}
