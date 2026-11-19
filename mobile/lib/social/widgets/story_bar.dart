import 'package:flutter/material.dart';

import '../social_models.dart';
import 'social_ui.dart';

/// Faixa horizontal de stories no topo do feed. O primeiro item é sempre o do aluno.
class StoryBar extends StatelessWidget {
  const StoryBar({super.key, required this.me, required this.groups, required this.onAddStory, required this.onOpen});

  final SocialAuthor? me;
  final List<StoryGroup> groups;
  final VoidCallback onAddStory;
  final void Function(int groupIndex) onOpen;

  @override
  Widget build(BuildContext context) {
    final myIndex = groups.indexWhere((group) => group.isMe);
    final others = [
      for (var i = 0; i < groups.length; i++)
        if (!groups[i].isMe) i,
    ];
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          if (me != null)
            _StoryBubble(
              key: const Key('my-story'),
              author: me!,
              label: 'Seu flash',
              ring: myIndex >= 0 ? StoryRing.seen : StoryRing.none,
              showAdd: true,
              onTap: myIndex >= 0 ? () => onOpen(myIndex) : onAddStory,
              onAdd: onAddStory,
            ),
          for (final index in others)
            _StoryBubble(
              author: groups[index].author,
              label: groups[index].author.handle,
              ring: groups[index].hasUnseen ? StoryRing.unseen : StoryRing.seen,
              onTap: () => onOpen(index),
            ),
        ],
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    super.key,
    required this.author,
    required this.label,
    required this.ring,
    required this.onTap,
    this.showAdd = false,
    this.onAdd,
  });

  final SocialAuthor author;
  final String label;
  final StoryRing ring;
  final VoidCallback onTap;
  final bool showAdd;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Flash de $label',
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            const SizedBox(height: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                SocialAvatar(author: author, size: 62, ring: ring == StoryRing.none ? StoryRing.none : ring),
                if (showAdd)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SocialColors.accent,
                          border: Border.all(color: SocialColors.bg, width: 3),
                        ),
                        padding: const EdgeInsets.all(1),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: showAdd ? SocialColors.ink2 : SocialColors.ink),
            ),
          ],
        ),
      ),
    ),
  );
}
