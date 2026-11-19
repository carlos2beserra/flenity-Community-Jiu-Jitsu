import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import 'student_api.dart';

const _paymentLabel = {
  'PIX': 'Pix',
  'CASH': 'Dinheiro',
  'CREDIT_CARD': 'Crédito',
  'DEBIT_CARD': 'Débito',
  'BOLETO': 'Boleto',
};

typedef _PlanData = ({StudentProfile profile, List<Invoice> invoices});

class StudentPlansTab extends StatelessWidget {
  const StudentPlansTab({super.key});

  @override
  Widget build(BuildContext context) {
    final api = StudentApi(context.read<Session>().api);
    return Loader<_PlanData>(
      load: () async {
        final results = await Future.wait([api.me(), api.invoices()]);
        return (
          profile: results[0] as StudentProfile,
          invoices: results[1] as List<Invoice>,
        );
      },
      builder: (context, data, _) => ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          StudentPlanSection(profile: data.profile, invoices: data.invoices),
        ],
      ),
    );
  }
}

class StudentPlanSection extends StatelessWidget {
  const StudentPlanSection({
    super.key,
    required this.profile,
    required this.invoices,
  });

  final StudentProfile profile;
  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final open = invoices
        .where((i) => i.status == 'PENDING')
        .fold<int>(0, (sum, i) => sum + i.amountCents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Planos'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Palette.good.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.card_membership_rounded,
                        color: Palette.good,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Planos ativos',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            profile.academyName,
                            style: const TextStyle(
                              color: Palette.ink2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile.planNames.isEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Nenhum plano vinculado à sua matrícula.',
                    style: TextStyle(color: Palette.ink2, fontSize: 12),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  for (
                    var index = 0;
                    index < profile.planNames.length;
                    index++
                  ) ...[
                    if (index > 0) const Divider(height: 18),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: Palette.good,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profile.planNames[index],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SectionTitle('Mensalidades'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text('EM ABERTO', style: monoStyle())),
                Text(
                  formatMoney(open),
                  style: displayStyle(
                    30,
                    color: open > 0 ? Palette.blood : Palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (invoices.isEmpty)
          const EmptyState(title: 'Nenhuma cobrança')
        else
          for (final invoice in invoices)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(
                  invoice.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  invoice.paidAt != null
                      ? 'Pago em ${formatDate(invoice.paidAt!.toLocal())} · ${_paymentLabel[invoice.paymentMethod] ?? ''}'
                      : 'Vence em ${formatDate(invoice.dueDate)}',
                  style: const TextStyle(color: Palette.ink3),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(invoice.amountCents),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(
                      invoiceStateLabel[invoice.stateOn(now)]!,
                      tone: invoiceStateTone[invoice.stateOn(now)]!,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
