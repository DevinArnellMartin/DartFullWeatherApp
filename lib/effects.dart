import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class Rain extends StatefulWidget {
  @override
  _RainState createState() => _RainState();
}

class _RainState extends State<Rain> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<RainDrop> _rainDrops;
  late Size _screenSize;

  @override
  void initState() {
    super.initState();

    // Use a fallback size to ensure size is non-null during init
    _screenSize = const Size(400, 800); 

    _rainDrops = List.generate(100, (_) => RainDrop(_screenSize.width, _screenSize.height));

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..addListener(() {
        setState(() {
          for (var drop in _rainDrops) {
            drop.update(_screenSize.width, _screenSize.height);
          }
        });
      })
      ..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update screen size here when context is available
    final size = MediaQuery.of(context).size;
    if (size != Size.zero) {
      _screenSize = size;
      _rainDrops = List.generate(100, (_) => RainDrop(_screenSize.width, _screenSize.height));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: _screenSize,
      painter: RainPainter(_rainDrops),
    );
  }
}

class RainDrop {
  double x;
  double y;
  double speed;
  double length;

  RainDrop(double width, double height)
      : x = Random().nextDouble() * width,
        y = Random().nextDouble() * height,
        speed = 2 + Random().nextDouble() * 5,
        length = 10 + Random().nextDouble() * 10;

  void update(double width, double height) {
    y += speed;
    if (y > height) {
      reset(width, height);
    }
  }

  void reset(double width, double height) {
    x = Random().nextDouble() * width;
    y = 0;
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
