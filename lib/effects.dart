import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class Rain extends StatefulWidget {
  @override
  _RainState createState() => _RainState();
}

class _RainState extends State<Rain> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<RainDrop> _rainDrops = [];

  @override
  void initState() {
    super.initState();
    _rainDrops = List.generate(100, (_) => RainDrop());
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..addListener(() {
        setState(() {
          for (var drop in _rainDrops) {
            drop.update();
          }
        });
      })
        ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: RainPainter(_rainDrops),
    );
  }
}

class RainDrop {
  double x;
  double y;
  double speed;
  double length;

  RainDrop()
      : x = Random().nextDouble() * 400,
        y = Random().nextDouble() * 800,
        speed = 2 + Random().nextDouble() * 5,
        length = 10 + Random().nextDouble() * 10;

  void update() {
    y += speed;
    if (y > 800) {
      y = 0;
      x = Random().nextDouble() * 400;
    }
  }
}

class RainPainter extends CustomPainter {
  final List<RainDrop> rainDrops;

  RainPainter(this.rainDrops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.6)
      ..strokeWidth = 2;

    for (var drop in rainDrops) {
      canvas.drawLine(
        Offset(drop.x, drop.y),
        Offset(drop.x, drop.y + drop.length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Drizzle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.grey.shade900,
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),

        Rain(),
      ],
    );
  }
}
