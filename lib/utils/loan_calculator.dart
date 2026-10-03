import 'dart:math';

double calculateMonthlyPayment({
  required double principal,
  double? interestRatePercent,
  int? termMonths,
  double? customInstallmentAmount,
}) {
  if (customInstallmentAmount != null && customInstallmentAmount > 0) {
    return customInstallmentAmount;
  }
  if (termMonths == null || termMonths <= 0 || principal <= 0) return 0;

  final monthlyRate = (interestRatePercent ?? 0) / 100 / 12;
  if (monthlyRate == 0) return principal / termMonths;

  final factor = pow(1 + monthlyRate, termMonths);
  return principal * monthlyRate * factor / (factor - 1);
}
