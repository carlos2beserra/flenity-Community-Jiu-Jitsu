import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

String formatMoney(int cents) => _currency.format(cents / 100);

const weekdayNames = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
const weekdayShort = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

/// Dia da semana no padrão da API (0 = domingo).
int apiWeekday(DateTime date) => date.weekday % 7;

String _two(int n) => n.toString().padLeft(2, '0');

/// Datas "date-only" chegam como meia-noite UTC: usar os campos UTC evita voltar um dia.
String formatDate(DateTime? date) => date == null ? '—' : '${_two(date.day)}/${_two(date.month)}/${date.year}';

String formatDateTime(DateTime instant) {
  final local = instant.toLocal();
  return '${_two(local.day)}/${_two(local.month)} ${_two(local.hour)}:${_two(local.minute)}';
}

String formatTime(DateTime instant) {
  final local = instant.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String initials(String name) =>
    name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
