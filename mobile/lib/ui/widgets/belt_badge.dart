import 'package:flutter/material.dart';

import '../theme.dart';

Color parseHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse(value.length == 6 ? 'FF$value' : value, radix: 16));
}

/// Faixa desenhada: cor da faixa, ponteira (preta, ou vermelha na faixa preta) e uma listra branca por grau.
class BeltBadge extends StatelessWidget {
  const BeltBadge({super.key, required this.color, required this.degree, this.width = 96, this.height = 16});

  final String color;
  final int degree;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final beltColor = parseHex(color);
    final tipColor = beltColor.computeLuminance() < 0.05 ? const Color(0xFFC8361A) : const Color(0xFF111111);
    return Semantics(
      label: degree == 0 ? 'faixa lisa' : 'faixa com $degree grau(s)',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: beltColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: width * 0.1),
        child: Container(
          key: const Key('belt-tip'),
          width: width * 0.34,
          height: double.infinity, // ocupa a altura mesmo sem listras (faixa lisa)
          color: tipColor,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < degree; i++)
                Container(key: ValueKey('belt-stripe-$i'), width: 3, margin: const EdgeInsets.symmetric(horizontal: 1.5), color: Palette.ink),
            ],
          ),
        ),
      ),
    );
  }
}

String degreeLabel(int degree) => degree == 0 ? 'Lisa' : '$degreeº grau';
