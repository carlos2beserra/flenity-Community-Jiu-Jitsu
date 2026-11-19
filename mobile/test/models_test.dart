import 'package:flenity_combate/models/models.dart';
import 'package:flenity_combate/screens/student/class_tile.dart';
import 'package:flutter_test/flutter_test.dart';

Json rankJson({int classesSince = 30, int minClasses = 40, bool eligible = false}) => {
      'studentId': 's1', 'studentName': 'Lucas Silva', 'modalityId': 'bjj', 'modalityName': 'Jiu-Jitsu',
      'beltName': 'Azul', 'beltColor': '#1e5bd6', 'degree': 2, 'maxDegrees': 4, 'minClasses': minClasses,
      'classesSince': classesSince, 'promotedAt': '2026-03-01T00:00:00.000Z', 'eligible': eligible,
    };

ClassSlot slot({int weekday = 3, String start = '19:30', String end = '21:00', bool open = false, bool done = false}) => ClassSlot(
      id: 'c1', name: 'Jiu-Jitsu', weekday: weekday, startTime: start, endTime: end, capacity: 30,
      modality: const Ref('bjj', 'Jiu-Jitsu'), checkInOpen: open, checkedInToday: done,
    );

void main() {
  group('RankProgress', () {
    test('calcula progresso e aulas restantes', () {
      final rank = RankProgress.fromJson(rankJson(classesSince: 30, minClasses: 40));
      expect(rank.progress, 0.75);
      expect(rank.classesRemaining, 10);
    });

    test('limita progresso a 100% quando passou do mínimo', () {
      final rank = RankProgress.fromJson(rankJson(classesSince: 55, minClasses: 40, eligible: true));
      expect(rank.progress, 1);
      expect(rank.classesRemaining, 0);
    });
  });

  group('Invoice.stateOn', () {
    Invoice invoice(String status, String due) => Invoice.fromJson({
          'id': 'i1', 'description': 'Mensalidade', 'amountCents': 22000, 'dueDate': due, 'status': status,
          'paidAt': null, 'paymentMethod': null,
        });

    test('pendente com vencimento passado fica vencida', () {
      expect(invoice('PENDING', '2026-10-19T00:00:00.000Z').stateOn(DateTime(2026, 10, 20, 23)), 'OVERDUE');
    });

    test('vence hoje ainda está a vencer', () {
      expect(invoice('PENDING', '2026-10-20T00:00:00.000Z').stateOn(DateTime(2026, 10, 20, 23)), 'PENDING');
    });

    test('paga continua paga', () {
      expect(invoice('PAID', '2026-01-01T00:00:00.000Z').stateOn(DateTime(2026, 10, 20)), 'PAID');
    });
  });

  test('StudentFile mantém só a graduação atual de cada modalidade', () {
    Json rank(String id, String modality, int degree) => {
          'id': id, 'degree': degree, 'promotedAt': '2026-01-01T00:00:00.000Z',
          'belt': {'name': 'Branca', 'color': '#ffffff'}, 'modality': {'id': modality, 'name': modality},
        };
    final file = StudentFile.fromJson({
      'id': 's1', 'name': 'Lucas', 'status': 'ACTIVE', 'notes': null, 'checkIns': [], 'invoices': [],
      'ranks': [rank('r3', 'bjj', 3), rank('r2', 'muay', 1), rank('r1', 'bjj', 2)],
    });
    expect(file.ranks.map((r) => '${r.modality.id}:${r.degree}'), ['bjj:3', 'muay:1']);
  });

  group('checkInStateOf', () {
    final wednesday1900 = DateTime(2026, 10, 21, 19, 0); // quarta-feira

    test('presença já registrada prevalece', () {
      expect(checkInStateOf(slot(done: true), wednesday1900), CheckInState.done);
    });

    test('aberto quando o servidor libera', () {
      expect(checkInStateOf(slot(open: true), wednesday1900), CheckInState.open);
    });

    test('antes da janela e depois do fim', () {
      expect(checkInStateOf(slot(), wednesday1900), CheckInState.notYet);
      expect(checkInStateOf(slot(start: '07:00', end: '08:00'), wednesday1900), CheckInState.closed);
    });

    test('turma de outro dia não mostra ação', () {
      expect(checkInStateOf(slot(weekday: 1), wednesday1900), CheckInState.otherDay);
    });
  });
}
