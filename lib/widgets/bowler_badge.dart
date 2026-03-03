import 'package:flutter/material.dart';

class BowlerBadge extends StatelessWidget {
  final String bowlerName;

  const BowlerBadge({Key? key, required this.bowlerName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (bowlerName.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Indigo-themed rounded badge
    final bgColor = isDark ? Colors.indigo[900]!.withOpacity(0.3) : Colors.indigo[50]!;
    final textColor = isDark ? Colors.indigo[200]! : Colors.indigo[800]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '⚾',
            style: TextStyle(
              fontSize: 14,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              bowlerName,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
