import 'package:flutter/material.dart';

class LandmarkOverlay extends StatelessWidget {
  final List<Offset> points;
  final Size inputSize;

  const LandmarkOverlay({
    super.key,
    required this.points,
    required this.inputSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LandmarkPainter(points: points, inputSize: inputSize),
    );
  }
}

class _LandmarkPainter extends CustomPainter {
  final List<Offset> points;
  final Size inputSize;

  _LandmarkPainter({required this.points, required this.inputSize});

  // MediaPipe Pose connections (indices based on 33 pose landmarks)
  static const List<List<int>> _poseEdges = [
    // Shoulders and arms
    [11, 12],
    [11, 13], [13, 15],
    [12, 14], [14, 16],
    // Hands (approximate connections from wrists)
    [15, 17], [15, 19], [15, 21],
    [16, 18], [16, 20], [16, 22],
    // Torso and hips
    [11, 23], [12, 24], [23, 24],
    // Legs
    [23, 25], [25, 27],
    [24, 26], [26, 28],
    [27, 29], [29, 31],
    [28, 30], [30, 32],
    // Face (coarse)
    [9, 10],
    [0, 9], [0, 10],
    [0, 1], [1, 2], [2, 3],
    [0, 4], [4, 5], [5, 6],
    [3, 7], [6, 8],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || inputSize.width == 0 || inputSize.height == 0) return;

    final scaleX = size.width / inputSize.width;
    final scaleY = size.height / inputSize.height;
    final pointPaint = Paint()
      ..color = Colors.limeAccent
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    // Pre-map all points once
    final List<Offset> mappedPoints = points
        .map((p) => Offset(p.dx * scaleX, p.dy * scaleY))
        .toList(growable: false);

    // Draw connections first
    for (final edge in _poseEdges) {
      final int a = edge[0];
      final int b = edge[1];
      if (a < mappedPoints.length && b < mappedPoints.length) {
        canvas.drawLine(mappedPoints[a], mappedPoints[b], linePaint);
      }
    }

    // Draw landmarks
    for (final mapped in mappedPoints) {
      canvas.drawCircle(mapped, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.inputSize != inputSize;
  }
}
