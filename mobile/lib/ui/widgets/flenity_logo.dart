import 'package:flutter/material.dart';

import '../theme.dart';

/// Marca da Flenity: um "F" branco cujo traço superior é uma faixa de jiu-jitsu
/// (ponteira escura com duas listras de grau), sobre um ladrilho em degradê azul.
class FlenityLogo extends StatelessWidget {
  const FlenityLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Flenity',
    image: true,
    child: SizedBox.square(dimension: size, child: const CustomPaint(painter: _LogoPainter())),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  static const _tileTop = Color(0xFF0F2A44);
  static const _tileBottom = Palette.blood;
  static const _tip = Color(0xFF111418);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Rect r(double l, double t, double w, double h) => Rect.fromLTWH(l * s, t * s, w * s, h * s);
    RRect round(Rect rect, double radius) => RRect.fromRectAndRadius(rect, Radius.circular(radius * s));

    final tile = Offset.zero & size;
    canvas.drawRRect(
      round(tile, 0.26),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_tileTop, _tileBottom],
        ).createShader(tile),
    );

    final white = Paint()..color = Colors.white;
    // Haste e traço do meio do "F".
    canvas.drawRRect(round(r(0.27, 0.22, 0.13, 0.58), 0.035), white);
    canvas.drawRRect(round(r(0.27, 0.47, 0.34, 0.12), 0.035), white);
    // Traço superior em forma de faixa: corpo branco + ponteira escura com dois graus.
    canvas.drawRRect(round(r(0.27, 0.22, 0.48, 0.13), 0.035), white);
    canvas.drawRRect(round(r(0.57, 0.22, 0.18, 0.13), 0.03), Paint()..color = _tip);
    for (final x in [0.615, 0.67]) {
      canvas.drawRect(r(x, 0.22, 0.025, 0.13), white);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => false;
}

/// Logo + nome, para capas e topo de telas.
class FlenityWordmark extends StatelessWidget {
  const FlenityWordmark({super.key, this.logoSize = 40, this.color = Palette.ink, this.textSize = 30});

  final double logoSize;
  final Color color;
  final double textSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FlenityLogo(size: logoSize),
      SizedBox(width: logoSize * 0.28),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Flenity', style: displayStyle(textSize, color: color)),
        ),
      ),
    ],
  );
}
