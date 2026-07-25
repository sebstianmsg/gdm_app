/// Meses y días en español, 1:1 con las constantes `MESES`/`DIAS` de
/// `public/js/app.js`.
const meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const dias = [
  'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado',
];

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "julio 2026"
String formatMonthLabel(DateTime month) =>
    capitalize('${meses[month.month - 1]} ${month.year}');

/// "lunes 21 de julio"
String formatDayHeader(DateTime date) =>
    '${dias[date.weekday % 7]} ${date.day} de ${meses[date.month - 1]}';

/// `$ 12.500` — redondeado, separador de miles con punto (formato es-UY),
/// igual que `formatMoney` en `public/js/app.js`.
String formatMoney(num amount) {
  final rounded = amount.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$ $buffer';
}
