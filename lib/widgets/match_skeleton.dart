import 'package:flutter/material.dart';

class MatchSkeleton extends StatefulWidget {
  const MatchSkeleton({Key? key}) : super(key: key);

  @override
  State<MatchSkeleton> createState() => _MatchSkeletonState();
}

class _MatchSkeletonState extends State<MatchSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar skeleton
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Container(width: 80, height: 10, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                   Container(width: 60, height: 16, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                ],
              ),
            ),
            // Body skeleton
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Team A row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      Row(
                        children: [
                          Container(width: 60, height: 32, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 8),
                          Container(width: 40, height: 14, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Team B row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                      Row(
                        children: [
                          Container(width: 60, height: 32, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 8),
                          Container(width: 40, height: 14, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Footer skeleton
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade50))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: double.infinity, height: 36, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Container(width: 150, height: 10, decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
