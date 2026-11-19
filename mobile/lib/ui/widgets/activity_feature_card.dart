import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

class ActivityFeatureCard extends StatefulWidget {
  const ActivityFeatureCard({
    super.key,
    required this.height,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.details,
    required this.host,
    required this.hostLabel,
    required this.sideNote,
    required this.badge,
    required this.actionLabel,
    required this.onAction,
    required this.onMenuTap,
    required this.icon,
    this.busy = false,
    this.actionEnabled = true,
    this.showMenu = true,
  });

  final double height;
  final String title;
  final String eyebrow;
  final String description;
  final String details;
  final String host;
  final String hostLabel;
  final String sideNote;
  final String badge;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onMenuTap;
  final IconData icon;
  final bool busy;
  final bool actionEnabled;
  final bool showMenu;

  @override
  State<ActivityFeatureCard> createState() => _ActivityFeatureCardState();
}

class _ActivityFeatureCardState extends State<ActivityFeatureCard> {
  int? _attendanceChoice;

  @override
  Widget build(BuildContext context) {
    final hostInitials = widget.host
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final compact = widget.height < 680;

    return Container(
      height: widget.height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.78),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2638617A),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7FB9A6),
                  Color(0xFF3D7978),
                  Color(0xFF1E3948),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          Positioned(
            top: -88,
            right: -52,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 32,
                ),
              ),
            ),
          ),
          Positioned(
            top: 105,
            right: 34,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF2D6A3).withValues(alpha: 0.78),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF2D6A3).withValues(alpha: 0.22),
                    blurRadius: 40,
                    spreadRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: 112,
            child: Container(
              width: 290,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(200),
                color: const Color(0xFF9FD3C0).withValues(alpha: 0.13),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.23, 0.48, 0.76, 1],
                colors: [
                  Color(0x16203344),
                  Color(0x10304450),
                  Color(0x63263844),
                  Color(0xD91A2934),
                  Color(0xF2172630),
                ],
              ),
            ),
          ),
          Positioned(
            right: -52,
            top: widget.height * 0.24,
            child: Icon(
              widget.icon,
              size: 210,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              compact ? 12 : 16,
              20,
              compact ? 12 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  onMenuTap: widget.onMenuTap,
                  title: widget.eyebrow,
                  showMenu: widget.showMenu,
                ),
                SizedBox(height: compact ? 10 : 24),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 25 : 28,
                    fontWeight: FontWeight.w800,
                    height: 1.03,
                    letterSpacing: -0.55,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.description,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: compact ? 12 : 17),
                _AttendancePicker(
                  selected: _attendanceChoice,
                  onChanged: (value) =>
                      setState(() => _attendanceChoice = value),
                ),
                const Spacer(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: compact ? 29 : 34,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          child: Text(
                            hostInitials,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 17 : 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.hostLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 10 : 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _InfoChip(widget.details),
                    _InfoChip(widget.sideNote),
                    _InfoChip(widget.badge),
                  ],
                ),
                SizedBox(height: compact ? 12 : 18),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF9FF2A5),
                      size: 20,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Sua próxima conquista',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sports_martial_arts_rounded,
                            color: Color(0xFF9FF2A5),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.actionEnabled ? 'NO RITMO' : 'FEITO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 19),
                SizedBox(
                  width: double.infinity,
                  height: compact ? 46 : 52,
                  child: FilledButton(
                    onPressed: widget.actionEnabled && !widget.busy
                        ? widget.onAction
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1689EF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1689EF),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                      elevation: 3,
                      shadowColor: const Color(0x551689EF),
                    ),
                    child: widget.busy
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.actionLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onMenuTap,
    required this.title,
    required this.showMenu,
  });

  final VoidCallback onMenuTap;
  final String title;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showMenu) ...[
          _GlassIconButton(
            icon: Icons.menu_rounded,
            label: 'Abrir menu',
            onTap: onMenuTap,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _GlassIconButton(
          icon: Icons.ios_share_rounded,
          label: 'Compartilhar',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compartilhamento de aula em breve.')),
          ),
        ),
        const SizedBox(width: 8),
        _GlassIconButton(
          icon: Icons.map_outlined,
          label: 'Localização do espaço',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: displayStyle(22)),
                    const SizedBox(height: 6),
                    const Text(
                      'A localização pode ser adicionada pela equipe do espaço.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.2),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                color: Colors.white,
                size: 18,
                semanticLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendancePicker extends StatelessWidget {
  const _AttendancePicker({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (label: 'Vou', icon: Icons.check_circle_outline_rounded),
      (label: 'Não vou', icon: Icons.highlight_off_rounded),
      (label: 'Talvez', icon: Icons.access_time_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++)
            Expanded(
              child: _AttendanceOption(
                label: options[index].label,
                icon: options[index].icon,
                selected: selected == index,
                onTap: () => onChanged(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttendanceOption extends StatelessWidget {
  const _AttendanceOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Palette.good
                    : Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? Palette.good : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
