import 'package:flutter/material.dart';

/// Official 4-color Google "G" brand mark rendered with crisp vector paths.
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({
    super.key,
    this.size = 20,
  });

  final double size;

  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleRed = Color(0xFFEA4335);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Google logo',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          size: Size.square(size),
          painter: const _GoogleGLogoPainter(),
        ),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  const _GoogleGLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    // Blue right petal and crossbar (#4285F4)
    final bluePath = Path()
      ..moveTo(22.56, 12.25)
      ..relativeCubicTo(0, -0.78, -0.07, -1.53, -0.2, -2.25)
      ..lineTo(12.0, 10.0)
      ..relativeLineTo(0, 4.26)
      ..relativeLineTo(5.92, 0)
      ..relativeCubicTo(-0.26, 1.37, -1.04, 2.53, -2.21, 3.31)
      ..relativeLineTo(0, 2.77)
      ..relativeLineTo(3.57, 0)
      ..relativeCubicTo(2.08, -1.92, 3.28, -4.74, 3.28, -8.09)
      ..close();
    canvas.drawPath(
      bluePath,
      Paint()
        ..color = GoogleGLogo.googleBlue
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Green bottom arc (#34A853)
    final greenPath = Path()
      ..moveTo(12.0, 23.0)
      ..relativeCubicTo(2.97, 0, 5.46, -0.98, 7.28, -2.66)
      ..relativeLineTo(-3.57, -2.77)
      ..relativeCubicTo(-0.98, 0.66, -2.23, 1.06, -3.71, 1.06)
      ..relativeCubicTo(-2.86, 0, -5.29, -1.93, -6.16, -4.53)
      ..lineTo(2.18, 14.10)
      ..relativeLineTo(0, 2.84)
      ..cubicTo(3.99, 20.53, 7.7, 23.0, 12.0, 23.0)
      ..close();
    canvas.drawPath(
      greenPath,
      Paint()
        ..color = GoogleGLogo.googleGreen
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Yellow left arc (#FBBC05)
    final yellowPath = Path()
      ..moveTo(5.84, 14.09)
      ..relativeCubicTo(-0.22, -0.66, -0.35, -1.36, -0.35, -2.09)
      ..relativeCubicTo(0.0, -0.73, 0.13, -1.43, 0.35, -2.09)
      ..lineTo(5.84, 7.06)
      ..lineTo(2.18, 7.06)
      ..cubicTo(1.43, 8.55, 1.0, 10.22, 1.0, 12.0)
      ..relativeCubicTo(0.0, 1.78, 0.43, 3.45, 1.18, 4.94)
      ..relativeLineTo(2.85, -2.22)
      ..relativeLineTo(0.81, -0.63)
      ..close();
    canvas.drawPath(
      yellowPath,
      Paint()
        ..color = GoogleGLogo.googleYellow
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Red top arc (#EA4335)
    final redPath = Path()
      ..moveTo(12.0, 5.38)
      ..relativeCubicTo(1.62, 0, 3.06, 0.56, 4.21, 1.64)
      ..relativeLineTo(3.15, -3.15)
      ..cubicTo(17.45, 2.09, 14.97, 1.0, 12.0, 1.0)
      ..cubicTo(7.7, 1.0, 3.99, 3.47, 2.18, 7.06)
      ..relativeLineTo(3.66, 2.84)
      ..relativeCubicTo(0.87, -2.6, 3.3, -4.52, 6.16, -4.52)
      ..close();
    canvas.drawPath(
      redPath,
      Paint()
        ..color = GoogleGLogo.googleRed
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
