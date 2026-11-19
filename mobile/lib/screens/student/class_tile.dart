import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/theme.dart';

/// Situação do check-in de uma turma de hoje, do ponto de vista do aluno.
enum CheckInState { done, open, notYet, closed, otherDay }

CheckInState checkInStateOf(ClassSlot slot, DateTime now) {
  if (slot.checkedInToday) return CheckInState.done;
  if (slot.checkInOpen) return CheckInState.open;
  if (slot.weekday != now.weekday % 7) return CheckInState.otherDay;
  final minutes = now.hour * 60 + now.minute;
  final [h, m] = slot.startTime.split(':').map(int.parse).toList();
  return minutes < h * 60 + m ? CheckInState.notYet : CheckInState.closed;
}

class ClassTile extends StatelessWidget {
  const ClassTile({
    super.key,
    required this.slot,
    required this.onCheckIn,
    this.busy = false,
  });

  final ClassSlot slot;
  final VoidCallback onCheckIn;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final state = checkInStateOf(slot, DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x103A6E98),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${slot.startTime} – ${slot.endTime}',
                  style: monoStyle(color: Palette.ink2),
                ),
                const SizedBox(height: 3),
                Text(
                  slot.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slot.modality.name} · ${slot.instructor?.name ?? 'sem professor'}',
                  style: const TextStyle(color: Palette.ink3, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          switch (state) {
            CheckInState.done => const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Palette.good, size: 20),
                SizedBox(width: 4),
                Text(
                  'Presente',
                  style: TextStyle(
                    color: Palette.good,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            CheckInState.open => FilledButton(
              onPressed: busy ? null : onCheckIn,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('CHECK-IN'),
            ),
            CheckInState.notYet => Text(
              'abre 30 min\nantes',
              textAlign: TextAlign.right,
              style: monoStyle(size: 11),
            ),
            CheckInState.closed => Text(
              'encerrada',
              style: monoStyle(size: 11),
            ),
            CheckInState.otherDay => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}
