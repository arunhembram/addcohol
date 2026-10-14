/// Utility to format numbers and currency in the standard Indian format
/// (lakhs, crores, thousands) with the '₹' symbol.
String formatIndianCurrency(num amount) {
  final intVal = amount.round();
  if (intVal < 0) {
    return '-₹${formatIndianNumber(-intVal)}';
  }
  return '₹${formatIndianNumber(intVal)}';
}

String formatIndianNumber(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buffer = StringBuffer();
  for (int i = 0; i < rest.length; i++) {
    if (i > 0 && (rest.length - i) % 2 == 0) {
      buffer.write(',');
    }
    buffer.write(rest[i]);
  }
  return '$buffer,$last3';
}
