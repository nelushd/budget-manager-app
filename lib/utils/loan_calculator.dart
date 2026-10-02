import 'dart:math';

/// Standard amortized monthly payment for a bank loan. A custom installment
/// amount always wins if set. With no term, there's nothing to calculate
/// yet (matches the "Rs 0.00" shown for an incomplete loan in the app).
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
