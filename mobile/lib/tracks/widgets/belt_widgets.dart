import 'package:flutter/material.dart';

/// Ícone de faixa amarrada (nó + duas pontas) na cor da faixa. Usado na barra de abas.
class BeltIcon extends StatelessWidget {
  const BeltIcon({
    super.key,
    required this.color,
    this.size = 28,
    this.outline = const Color(0xFF111418),
    this.filled = true,
  });

  final Color color;
  final double size;
  final Color outline;

  /// Aba selecionada: faixa preenchida; não selecionada: só contorno com a cor no nó.
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _BeltIconPainter(color: color, outline: outline, filled: filled),
    ),
  );
}

class _BeltIconPainter extends CustomPainter {
  const _BeltIconPainter({required this.color, required this.outline, required this.filled});

  final Color color;
  final Color outline;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = filled ? color : Colors.transparent;

    // Faixa horizontal atravessando o ícone.
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.06, s * 0.30, s * 0.88, s * 0.2),
      Radius.circular(s * 0.05),
    );
    // Duas pontas caindo do nó, levemente abertas.
    Path tail(double dx) => Path()
      ..moveTo(s * (0.44 + dx * 0.02), s * 0.48)
      ..lineTo(s * (0.5 + dx * 0.16), s * 0.92)
      ..lineTo(s * (0.5 + dx * 0.34), s * 0.86)
      ..lineTo(s * (0.56 + dx * 0.04), s * 0.48)
      ..close();
    final knot = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.36, s * 0.24, s * 0.28, s * 0.32),
      Radius.circular(s * 0.06),
    );

    for (final path in [tail(-1), tail(1)]) {
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, stroke);
    }
    canvas
      ..drawRRect(band, fill)
      ..drawRRect(band, stroke)
      ..drawRRect(knot, Paint()..color = color)
      ..drawRRect(knot, stroke);
  }

  @override
  bool shouldRepaint(covariant _BeltIconPainter old) =>
      old.color != color || old.outline != outline || old.filled != filled;
}

/// Faixa esticada com ponteira e graus, como no tatame. Ponteira preta; na faixa preta, vermelha.
class BeltStrip extends StatelessWidget {
  const BeltStrip({super.key, required this.color, this.degrees = 0, this.height = 22});

  final Color color;
  final int degrees;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: _BeltStripPainter(color: color, degrees: degrees),
      size: Size.infinite,
    ),
  );
}

class _BeltStripPainter extends CustomPainter {
  const _BeltStripPainter({required this.color, required this.degrees});

  final Color color;
  final int degrees;

  bool get _isBlack => color.computeLuminance() < 0.03;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height * 0.22);
    final band = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas
      ..save()
      ..clipRRect(band)
      ..drawRect(Offset.zero & size, Paint()..color = color);

    // Costura da faixa.
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: color.computeLuminance() > 0.5 ? 0.12 : 0.25)
      ..strokeWidth = 1;
    for (final y in [size.height * 0.3, size.height * 0.7]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), seam);
    }

    final tipWidth = size.height * 3.2;
    final tipLeft = size.width - tipWidth - size.height * 0.9;
    canvas.drawRect(
      Rect.fromLTWH(tipLeft, 0, tipWidth, size.height),
      Paint()..color = _isBlack ? const Color(0xFFD32F2F) : const Color(0xFF111418),
    );
    final stripe = Paint()..color = Colors.white;
    final stripeWidth = size.height * 0.22;
    for (var i = 0; i < degrees.clamp(0, 6); i++) {
      final x = tipLeft + tipWidth - (i + 1) * stripeWidth * 2.1;
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeWidth, size.height), stripe);
    }
    canvas.restore();
    canvas.drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _BeltStripPainter old) => old.color != color || old.degrees != degrees;
}

/// Anel de progresso com o percentual no centro.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    this.size = 44,
    this.color = const Color(0xFF1689EF),
    this.label,
  });

  final double fraction;
  final double size;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CircularProgressIndicator(
          value: fraction.clamp(0, 1),
          strokeWidth: size * 0.1,
          backgroundColor: const Color(0xFFE5E7EB),
          color: color,
          strokeCap: StrokeCap.round,
        ),
        Center(
          child: FittedBox(
            child: Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: Text(
                label ?? '${(fraction * 100).round()}%',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.26, color: const Color(0xFF111418)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
