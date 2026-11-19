import 'package:flutter/material.dart';

import '../../social/widgets/social_ui.dart';
import '../../ui/theme.dart';
import '../tracks_models.dart';
import 'belt_widgets.dart';

/// Cabeçalho "Descomplicando a Faixa X" com a faixa desenhada e o progresso.
class TrackHeader extends StatelessWidget {
  const TrackHeader({super.key, required this.belt, this.degree = 0, this.progress, this.subtitle});

  final TrackBelt belt;
  final int degree;

  /// Progresso do aluno; o professor passa `subtitle` no lugar.
  final TrackProgress? progress;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESCOMPLICANDO',
            style: TextStyle(color: SocialColors.ink2, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 12),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'a ${belt.title}',
              key: const Key('track-title'),
              style: displayStyle(30, color: SocialColors.ink),
            ),
          ),
          const SizedBox(height: 12),
          BeltStrip(color: belt.color, degrees: degree),
          const SizedBox(height: 12),
          if (progress != null)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.total == 0
                            ? 'Nenhum conceito liberado ainda'
                            : '${progress.completed} de ${progress.total} conceitos aprendidos',
                        style: socialBold,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress.fraction,
                          minHeight: 8,
                          backgroundColor: SocialColors.surface,
                          color: SocialColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ProgressRing(fraction: progress.fraction, size: 48),
              ],
            )
          else if (subtitle != null)
            Text(subtitle!, style: const TextStyle(color: SocialColors.ink2)),
        ],
      ),
    );
  }
}

/// Faixas lado a lado para trocar a trilha exibida.
class BeltSelector extends StatelessWidget {
  const BeltSelector({
    super.key,
    required this.belts,
    required this.selectedId,
    required this.onSelected,
    required this.caption,
  });

  final List<TrackBelt> belts;
  final String selectedId;
  final ValueChanged<TrackBelt> onSelected;
  final String Function(TrackBelt belt) caption;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: belts.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final belt = belts[index];
        final selected = belt.id == selectedId;
        return Material(
          color: selected ? SocialColors.ink : SocialColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: Key('belt-${belt.id}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(belt),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  BeltIcon(color: belt.color, size: 26, outline: selected ? Colors.white : SocialColors.ink),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        belt.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : SocialColors.ink,
                        ),
                      ),
                      Text(
                        caption(belt),
                        style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : SocialColors.ink2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Os quatro eixos (Guarda, Passagem, Controle, Finalizações) com o progresso de cada um.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.sections, required this.onTap});

  final List<TrackSection> sections;
  final ValueChanged<TrackCategory> onTap;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 2.3,
    children: [
      for (final section in sections)
        Material(
          color: SocialColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: Key('category-${section.category.apiName}'),
            borderRadius: BorderRadius.circular(16),
            onTap: section.lessons.isEmpty ? null : () => onTap(section.category),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ProgressRing(
                    fraction: section.progress.fraction,
                    size: 38,
                    label: '${section.progress.completed}/${section.progress.total}',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(section.category.icon, size: 18, color: SocialColors.ink2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(section.category.label, style: socialBold.copyWith(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.category, this.trailing});

  final TrackCategory category;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 8, 4),
    child: Row(
      children: [
        Icon(category.icon, color: SocialColors.ink, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(category.label, style: socialTitleStyle.copyWith(fontSize: 19))),
        ?trailing,
      ],
    ),
  );
}

/// Capa da videoaula na lista: cor da faixa, ícone da categoria e "play" (ou câmera riscada sem vídeo).
class VideoThumb extends StatelessWidget {
  const VideoThumb({super.key, required this.color, required this.category, required this.hasVideo, this.width = 96});

  final Color color;
  final TrackCategory category;
  final bool hasVideo;
  final double width;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: width * 9 / 16,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: hasVideo
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.black, light ? 0.55 : 0.2)!, const Color(0xFF111418)],
                  )
                : null,
            color: hasVideo ? null : SocialColors.surface,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -6,
                bottom: -8,
                child: Icon(category.icon, size: width * 0.5, color: hasVideo ? Colors.white12 : Colors.black12),
              ),
              Center(
                child: hasVideo
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, size: 22, color: Color(0xFF111418)),
                      )
                    : const Icon(Icons.videocam_off_outlined, size: 20, color: SocialColors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Área do player quando o professor ainda não enviou o vídeo.
class VideoComingSoon extends StatelessWidget {
  const VideoComingSoon({super.key, required this.color, required this.category});

  final Color color;
  final TrackCategory category;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.black, 0.6)!, const Color(0xFF111418)],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, color: Colors.white54, size: 44),
          const SizedBox(height: 8),
          const Text(
            'Vídeo em breve',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 2),
          const Text('O professor ainda vai gravar esta aula.', style: TextStyle(color: Colors.white70)),
        ],
      ),
    ),
  );
}

/// Linha de um conceito, como videoaula. `leading` é o check do aluno ou o interruptor do professor.
class LessonTile extends StatelessWidget {
  const LessonTile({
    super.key,
    required this.lesson,
    required this.onTap,
    required this.leading,
    this.beltColor = Colors.white,
    this.trailing,
    this.dimmed = false,
  });

  final TrackLesson lesson;
  final Color beltColor;
  final VoidCallback onTap;
  final Widget leading;
  final Widget? trailing;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      child: Row(
        children: [
          leading,
          VideoThumb(color: beltColor, category: lesson.category, hasVideo: lesson.media?.isVideo ?? false),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: dimmed ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dimmed)
                    const Text(
                      'RASCUNHO',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  Text(
                    lesson.title,
                    style: socialBold.copyWith(
                      fontSize: 15,
                      decoration: lesson.completed ? TextDecoration.lineThrough : null,
                      decorationColor: SocialColors.ink2,
                    ),
                  ),
                  if ((lesson.description ?? '').isNotEmpty)
                    Text(
                      lesson.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SocialColors.ink2, height: 1.3),
                    ),
                ],
              ),
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: SocialColors.ink2),
        ],
      ),
    ),
  );
}

class TrackEmpty extends StatelessWidget {
  const TrackEmpty({super.key, required this.title, required this.message, this.actions = const []});

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.menu_book_rounded, size: 52, color: SocialColors.ink),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: SocialColors.ink2),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: actions),
        ],
      ],
    ),
  );
}
