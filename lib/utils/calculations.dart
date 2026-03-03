import 'formatters.dart';
import '../constants/scoring.dart';

/// Mirrors AdminDashboard.jsx:calculateWinner
String? calculateWinner(Map<String, dynamic> match) {
  if (match['status'] != 'completed') return null;
  final innings = List<dynamic>.from(match['innings'] ?? []);
  if (innings.length < 2) return 'Match Completed';

  if (innings.length >= 4) {
    final lastIdx = innings.length - 1;
    final inn1 = innings[lastIdx - 1];
    final inn2 = innings[lastIdx];
    final runs1 = (inn1['runs'] ?? 0) as num;
    final runs2 = (inn2['runs'] ?? 0) as num;
    if (runs1 > runs2) return 'Match Tied | ${inn1['team']} won via Super Over';
    if (runs2 > runs1) return 'Match Tied | ${inn2['team']} won via Super Over';
    return 'Match Drawn | Super Over Tied';
  }

  final inn1 = innings[0];
  final inn2 = innings[1];
  final runs1 = (inn1['runs'] ?? 0) as num;
  final runs2 = (inn2['runs'] ?? 0) as num;

  if (runs1 > runs2) {
    final diff = runs1 - runs2;
    return '${inn1['team']} won the match by ${pluralize(diff, 'Run')}.';
  } else if (runs2 > runs1) {
    final wickets = (inn2['wickets'] ?? 0) as num;
    final remaining = maxWickets - wickets;
    return '${inn2['team']} won the match by ${pluralize(remaining, 'Wicket')}.';
  } else if (runs1 > 0) {
    return 'Match Drawn';
  }
  return 'Match Completed';
}

/// Mirrors AdminDashboard.jsx:calculateSuggestedMOM
String? calculateSuggestedMOM(Map<String, dynamic> match) {
  if (match['innings'] == null) return null;
  final innings = List<dynamic>.from(match['innings']);
  final Map<String, Map<String, dynamic>> playerStats = {};

  for (final inn in innings) {
    final team = inn['team']?.toString();
    final batting = List<dynamic>.from(inn['batting'] ?? []);
    final bowling = List<dynamic>.from(inn['bowling'] ?? []);

    for (final p in batting) {
      final name = p['player']?.toString();
      if (name == null) continue;
      playerStats.putIfAbsent(name, () => {'runs': 0, 'fours': 0, 'sixes': 0, 'wickets': 0, 'team': team});
      playerStats[name]!['runs'] = (playerStats[name]!['runs'] as int) + ((p['runs'] ?? 0) as int);
      playerStats[name]!['fours'] = (playerStats[name]!['fours'] as int) + ((p['fours'] ?? 0) as int);
      playerStats[name]!['sixes'] = (playerStats[name]!['sixes'] as int) + ((p['sixes'] ?? 0) as int);
    }

    for (final p in bowling) {
      final name = p['player']?.toString();
      if (name == null) continue;
      playerStats.putIfAbsent(name, () => {'runs': 0, 'fours': 0, 'sixes': 0, 'wickets': 0, 'team': team});
      playerStats[name]!['wickets'] = (playerStats[name]!['wickets'] as int) + ((p['wickets'] ?? 0) as int);
    }
  }

  String? winningTeam;
  if (innings.length >= 2) {
    dynamic inn1, inn2;
    if (innings.length >= 4) {
      final lastIdx = innings.length - 1;
      inn1 = innings[lastIdx - 1];
      inn2 = innings[lastIdx];
    } else {
      inn1 = innings[0];
      inn2 = innings[1];
    }
    final r1 = (inn1['runs'] ?? 0) as num;
    final r2 = (inn2['runs'] ?? 0) as num;
    if (r1 > r2) winningTeam = inn1['team']?.toString();
    else if (r2 > r1) winningTeam = inn2['team']?.toString();
  }

  String? bestPlayer;
  double bestScore = -1;

  playerStats.forEach((name, stats) {
    double score = (stats['runs'] * 1.0) + (stats['fours'] * 1.0) + (stats['sixes'] * 2.0) + (stats['wickets'] * 20.0);
    if (stats['team'] == winningTeam) score *= 1.25;

    if (score > bestScore) {
      bestScore = score;
      bestPlayer = name;
    }
  });

  return bestPlayer;
}

/// Mirrors PointsTable.jsx:calculateStats
List<Map<String, dynamic>> calculateStats(List<dynamic> matchList) {
  final Map<String, Map<String, dynamic>> teamStats = {};

  for (final m in matchList) {
    if (m['status'] != 'completed' && m['status'] != 'live') continue;
    final innings = List<dynamic>.from(m['innings'] ?? []);
    if (innings.length < 2) continue;

    for (final team in [m['teamA'], m['teamB']]) {
      if (team == null) continue;
      teamStats.putIfAbsent(team.toString(), () => {
        'name': team, 'p': 0, 'w': 0, 'l': 0, 'd': 0, 'pts': 0,
        'runsScored': 0, 'ballsFaced': 0, 'runsConceded': 0, 'ballsBowled': 0,
      });
    }

    final runsA = (innings[0]['runs'] ?? 0) as num;
    final runsB = (innings[1]['runs'] ?? 0) as num;
    final teamA = innings[0]['team'].toString();
    final teamB = innings[1]['team'].toString();

    if (m['status'] == 'completed') {
      teamStats[teamA]!['p'] = (teamStats[teamA]!['p'] as int) + 1;
      teamStats[teamB]!['p'] = (teamStats[teamB]!['p'] as int) + 1;

      if (runsA > runsB) {
        teamStats[teamA]!['w'] = (teamStats[teamA]!['w'] as int) + 1;
        teamStats[teamA]!['pts'] = (teamStats[teamA]!['pts'] as int) + 2;
        teamStats[teamB]!['l'] = (teamStats[teamB]!['l'] as int) + 1;
      } else if (runsB > runsA) {
        teamStats[teamB]!['w'] = (teamStats[teamB]!['w'] as int) + 1;
        teamStats[teamB]!['pts'] = (teamStats[teamB]!['pts'] as int) + 2;
        teamStats[teamA]!['l'] = (teamStats[teamA]!['l'] as int) + 1;
      } else if (innings.length >= 4) {
        final runs3 = (innings[2]['runs'] ?? 0) as num;
        final runs4 = (innings[3]['runs'] ?? 0) as num;
        final team3 = innings[2]['team'].toString();
        final team4 = innings[3]['team'].toString();
        if (runs3 > runs4) {
          teamStats[team3]!['w'] = (teamStats[team3]!['w'] as int) + 1;
          teamStats[team3]!['pts'] = (teamStats[team3]!['pts'] as int) + 2;
          final loser = team3 == teamA ? teamB : teamA;
          teamStats[loser]!['l'] = (teamStats[loser]!['l'] as int) + 1;
        } else if (runs4 > runs3) {
          teamStats[team4]!['w'] = (teamStats[team4]!['w'] as int) + 1;
          teamStats[team4]!['pts'] = (teamStats[team4]!['pts'] as int) + 2;
          final loser = team4 == teamA ? teamB : teamA;
          teamStats[loser]!['l'] = (teamStats[loser]!['l'] as int) + 1;
        } else {
          for (final t in [teamA, teamB]) {
            teamStats[t]!['d'] = (teamStats[t]!['d'] as int) + 1;
            teamStats[t]!['pts'] = (teamStats[t]!['pts'] as int) + 1;
          }
        }
      } else {
        for (final t in [teamA, teamB]) {
          teamStats[t]!['d'] = (teamStats[t]!['d'] as int) + 1;
          teamStats[t]!['pts'] = (teamStats[t]!['pts'] as int) + 1;
        }
      }
    }

    // NRR — using balls for accuracy
    final ballsA = oversToBalls((innings[0]['overs'] as num? ?? 0).toDouble());
    final ballsB = oversToBalls((innings[1]['overs'] as num? ?? 0).toDouble());

    teamStats[teamA]!['runsScored'] = (teamStats[teamA]!['runsScored'] as int) + runsA.toInt();
    teamStats[teamA]!['ballsFaced'] = (teamStats[teamA]!['ballsFaced'] as int) + ballsA;
    teamStats[teamA]!['runsConceded'] = (teamStats[teamA]!['runsConceded'] as int) + runsB.toInt();
    teamStats[teamA]!['ballsBowled'] = (teamStats[teamA]!['ballsBowled'] as int) + ballsB;

    teamStats[teamB]!['runsScored'] = (teamStats[teamB]!['runsScored'] as int) + runsB.toInt();
    teamStats[teamB]!['ballsFaced'] = (teamStats[teamB]!['ballsFaced'] as int) + ballsB;
    teamStats[teamB]!['runsConceded'] = (teamStats[teamB]!['runsConceded'] as int) + runsA.toInt();
    teamStats[teamB]!['ballsBowled'] = (teamStats[teamB]!['ballsBowled'] as int) + ballsA;
  }

  final result = teamStats.values.map((t) {
    final oversFaced = (t['ballsFaced'] as int) / 6.0;
    final oversBowled = (t['ballsBowled'] as int) / 6.0;
    final rs = t['runsScored'] as int;
    final rc = t['runsConceded'] as int;
    final nrr = ((rs / (oversFaced > 0 ? oversFaced : 1)) -
                 (rc / (oversBowled > 0 ? oversBowled : 1)));
    return {...t, 'nrr': double.parse(nrr.toStringAsFixed(3))};
  }).toList();

  result.sort((a, b) {
    final ptsDiff = (b['pts'] as int) - (a['pts'] as int);
    if (ptsDiff != 0) return ptsDiff;
    return (b['nrr'] as double).compareTo(a['nrr'] as double);
  });

  return result;
}

/// Robust conversion from overs (e.g. 1.4) to balls (10)
int oversToBalls(double overs) {
  final whole = overs.floor();
  final balls = ((overs - whole) * 10).round();
  return (whole * 6) + balls;
}

/// Robust conversion from balls (10) to overs (1.4)
double ballsToOvers(int totalBalls) {
  final whole = totalBalls ~/ 6;
  final balls = totalBalls % 6;
  return double.parse('$whole.$balls');
}

/// Mirrors AdminDashboard CRR calculation
String calculateCRR(Map<String, dynamic> score) {
  try {
    final overs = (score['overs'] as num? ?? 0).toDouble();
    final totalBalls = oversToBalls(overs);
    if (totalBalls <= 0) return '-';
    final runs = (score['runs'] as num? ?? 0).toDouble();
    return (runs / (totalBalls / 6.0)).toStringAsFixed(2);
  } catch (_) {
    return '-';
  }
}

/// Mirrors AdminDashboard RRR calculation
String calculateRRR(Map<String, dynamic> score, List<dynamic> innings, int totalOvers) {
  try {
    final target = score['target'] as num?;
    if (target == null) return '-';
    final overs = (score['overs'] as num? ?? 0).toDouble();
    final runs = (score['runs'] as num? ?? 0).toDouble();
    final limit = innings.length > 2 ? superOverOvers : totalOvers;
    final totalBalls = limit * ballsPerOver;
    final ballsBowled = (overs.floor() * ballsPerOver) + (overs * 10 % 10).round();
    final ballsLeft = totalBalls - ballsBowled;
    if (ballsLeft <= 0) return '-';
    final runsNeeded = target - runs;
    if (runsNeeded <= 0) return '-';
    return ((runsNeeded / ballsLeft) * ballsPerOver).toStringAsFixed(2);
  } catch (_) {
    return '-';
  }
}
