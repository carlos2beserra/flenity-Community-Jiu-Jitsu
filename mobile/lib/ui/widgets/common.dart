import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../theme.dart';

class FlenityBackdrop extends StatelessWidget {
  const FlenityBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF9FCFF),
                  Color(0xFFEAF4FD),
                  Color(0xFFF3F8FC),
                ],
                stops: [0, 0.58, 1],
              ),
            ),
          ),
          Positioned(
            top: -110,
            right: -80,
            child: _GlowOrb(
              size: 300,
              color: const Color(0xFF9ED7FF).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -150,
            child: _GlowOrb(
              size: 300,
              color: const Color(0xFFB4E6F7).withValues(alpha: 0.24),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x143A6E98),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }
}

/// Carrega dados com estados de carregando/erro/vazio e "puxar para atualizar".
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  Future<void> _reload() async {
    final next = widget.load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // o erro já é exibido pelo FutureBuilder
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            message: errorText(snapshot.error),
            onRetry: _reload,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          color: Palette.blood,
          onRefresh: _reload,
          child: widget.builder(context, snapshot.data as T, _reload),
        );
      },
    );
  }
}

String errorText(Object? error) =>
    error is ApiException ? error.message : 'Algo deu errado';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Palette.bad : Palette.panel2,
      ),
    );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Palette.ink3, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.ink2),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: displayStyle(20, color: Palette.ink2),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: displayStyle(20))),
          ?trailing,
        ],
      ),
    );
  }
}

enum Tone { good, warn, bad, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.tone});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      Tone.good => Palette.good,
      Tone.warn => Palette.warn,
      Tone.bad => Palette.bad,
      Tone.neutral => Palette.ink3,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

const invoiceStateLabel = {
  'PAID': 'Pago',
  'CANCELED': 'Cancelado',
  'OVERDUE': 'Vencido',
  'PENDING': 'A vencer',
};
const invoiceStateTone = {
  'PAID': Tone.good,
  'CANCELED': Tone.neutral,
  'OVERDUE': Tone.bad,
  'PENDING': Tone.warn,
};

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: Palette.blood.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143A6E98),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Text(initials, style: displayStyle(size * 0.42)),
    );
  }
}

/// Barra de progresso até a próxima graduação.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.highlight = false});

  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: Palette.panel2,
        color: highlight ? Palette.blood : Palette.ink3,
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message, {
  String confirm = 'Confirmar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Palette.panel,
      title: Text(title.toUpperCase(), style: displayStyle(24)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
