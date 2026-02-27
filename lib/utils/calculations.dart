import 'formatters.dart';

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
    if (runs1 > runs2) return 'MATCH TIED | ${inn1['team'].toString().toUpperCase()} WON VIA SUPER OVER';
    if (runs2 > runs1) return 'MATCH TIED | ${inn2['team'].toString().toUpperCase()} WON VIA SUPER OVER';
    return 'MATCH DRAWN | SUPER OVER TIED';
  }

  final inn1 = innings[0];
  final inn2 = innings[1];
  final runs1 = (inn1['runs'] ?? 0) as num;
  final runs2 = (inn2['runs'] ?? 0) as num;

  if (runs1 > runs2) {
    final diff = runs1 - runs2;
    return '${inn1['team'].toString().toUpperCase()} WON BY $diff ${diff == 1 ? 'RUN' : 'RUNS'}';
  } else if (runs2 > runs1) {
    final wickets = (inn2['wickets'] ?? 0) as num;
    final remaining = 10 - wickets;
    return '${inn2['team'].toString().toUpperCase()} WON BY $remaining ${remaining == 1 ? 'WICKET' : 'WICKETS'}';
  } else if (runs1 > 0) {
    return 'MATCH DRAWN';
  }
  return 'Match Completed';
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

/// Mirrors AdminDashboard CRR calculation
String calculateCRR(Map<String, dynamic> score) {
  try {
    final overs = (score['overs'] as num? ?? 0).toDouble();
    if (overs <= 0) return '-';
    final runs = (score['runs'] as num? ?? 0).toDouble();
    final totalBalls = (overs.floor() * 6) + (overs * 10 % 10).round();
    if (totalBalls == 0) return '-';
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
    final limit = innings.length > 2 ? 1 : totalOvers;
    final totalBalls = limit * 6;
    final ballsBowled = (overs.floor() * 6) + (overs * 10 % 10).round();
    final ballsLeft = totalBalls - ballsBowled;
    if (ballsLeft <= 0) return '-';
    final runsNeeded = target - runs;
    if (runsNeeded <= 0) return '-';
    return ((runsNeeded / ballsLeft) * 6).toStringAsFixed(2);
  } catch (_) {
    return '-';
  }
}
