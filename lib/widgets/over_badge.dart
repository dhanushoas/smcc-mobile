import 'package:flutter/material.dart';

class OverBadge extends StatelessWidget {
  final int over;
  final int ball;
  final bool isMatchCompleted;

  const OverBadge({
    Key? key,
    required this.over,
    required this.ball,
    this.isMatchCompleted = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 5️⃣ Validation rules
    final int validOver = over < 0 ? 0 : over;
    final int validBall = ball < 0 ? 0 : (ball > 5 ? 5 : ball);

    // Dynamic Colors Check mapped to theme modes
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color textColor;
    Color accentColor;

    if (isMatchCompleted) {
      bgColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
      textColor = isDark ? Colors.grey[300]! : Colors.grey[800]!;
      accentColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    } else if (validOver < 6) {
      // Powerplay 
      bgColor = isDark ? Colors.teal[900]!.withOpacity(0.4) : Colors.teal[100]!;
      textColor = isDark ? Colors.teal[100]! : Colors.teal[900]!;
      accentColor = isDark ? Colors.teal[300]! : Colors.teal[700]!;
    } else if (validOver >= 6 && validOver < 15) {
      // Middle Overs
      bgColor = isDark ? Colors.amber[900]!.withOpacity(0.4) : Colors.amber[100]!;
      textColor = isDark ? Colors.amber[100]! : Colors.brown[900]!;
      accentColor = isDark ? Colors.amber[400]! : Colors.brown[600]!;
    } else {
      // Death Overs
      bgColor = isDark ? Colors.red[900]!.withOpacity(0.4) : Colors.red[100]!;
      textColor = isDark ? Colors.red[100]! : Colors.red[900]!;
      accentColor = isDark ? Colors.red[300]! : Colors.red[700]!;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$validOver.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '$validBall',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accentColor, // Highlight ball metric
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'OVERS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor.withOpacity(0.9),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
