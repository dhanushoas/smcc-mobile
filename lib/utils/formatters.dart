/// Mirrors smcc-web/src/utils/formatters.js

/// Converts a string to Title Case (first letter of each word capitalized)
String toCamelCase(String? text) {
  if (text == null || text.trim().isEmpty) return '';
  return text.trim().split(' ').map((word) {
    if (word.isEmpty) return '';
    if (word.length == 1) return word.toUpperCase();
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// Formats an ISO date string to "1.00 pm" style (mirrors web formatTime)
String formatTime(String? dateInput) {
  if (dateInput == null || dateInput.isEmpty) return '';
  try {
    final date = DateTime.parse(dateInput).toLocal();
    final hour = date.hour;
    final minute = date.minute;
    final ampm = hour >= 12 ? 'pm' : 'am';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12.$minuteStr $ampm';
  } catch (_) {
    return '';
  }
}

/// Formats a DateTime to a readable date: "Mon, Feb 27"
String formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
}

/// Converts overs (e.g. 2.4) to total balls (mirrors web getBalls)
int oversToBalls(double overs) {
  return (overs.floor() * 6) + (overs * 10 % 10).round();
}

/// Converts balls to overs display string e.g. "2.4"
String ballsToOvers(int balls) {
  final ov = balls ~/ 6;
  final b = balls % 6;
  return '$ov.$b';
}

/// Pluralises "over" vs "overs" based on value
String pluralOvers(num overs) {
  return overs == 1 ? 'over' : 'overs';
}
