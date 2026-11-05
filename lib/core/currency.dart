const String saudiRiyalSymbol = '\u20C1';

String formatCurrency(num value, {int decimals = 0}) {
  final normalized = value.abs() < 0.005 ? 0.0 : value;
  return '${normalized.toStringAsFixed(decimals)} $saudiRiyalSymbol';
}

String formatCurrencyCompact(num value, {int decimals = 0}) {
  final normalized = value.abs() < 0.005 ? 0.0 : value;
  return '${normalized.toStringAsFixed(decimals)} $saudiRiyalSymbol';
}
