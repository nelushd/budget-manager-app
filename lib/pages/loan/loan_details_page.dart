import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/loan_model.dart';
import '../../models/loan_payment_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/loan_calculator.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import 'create_bank_loan_page.dart';
import 'create_personal_loan_page.dart';

class LoanDetailsPage extends StatefulWidget {
  final String loanId;

  const LoanDetailsPage({super.key, required this.loanId});

  @override
  State<LoanDetailsPage> createState() => _LoanDetailsPageState();
}

class _LoanDetailsPageState extends State<LoanDetailsPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  LoanModel? loan;
  List<LoanPaymentModel> payments = [];
  bool showPayments = false;
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loadedLoan = await _firestoreService.getLoanById(widget.loanId);
      final loadedPayments = await _firestoreService.getLoanPayments(widget.loanId);
      if (!mounted) return;
      setState(() {
        loan = loadedLoan;
        payments = loadedPayments;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading loan details: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _makePayment() async {
    final l = loan;
    if (l == null) return;

    final amountController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Make Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              AmountField(label: 'Amount', controller: amountController),
              const SizedBox(height: 18),
              PrimaryActionButton(label: 'Make Payment', onPressed: () => Navigator.pop(sheetContext, true)),
            ],
          ),
        );
      },
    );

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (confirmed != true || amount <= 0 || l.id == null) return;

    setState(() => isRecording = true);
    try {
      final now = DateTime.now();
      await _firestoreService.addLoanPayment(
        LoanPaymentModel(
          loanId: l.id!,
          amount: amount,
          date: PeriodCalculator.formatDate(now),
          createdAt: now.millisecondsSinceEpoch,
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => isRecording = false);
    }
  }

  Future<void> _edit() async {
    final l = loan;
    if (l == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => l.isBank ? CreateBankLoanPage(existing: l) : CreatePersonalLoanPage(existing: l),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete() async {
    final l = loan;
    if (l?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${l!.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _firestoreService.deleteLoan(l!.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = loan;

    if (isLoading && l == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (l == null) {
      return const Scaffold(body: Center(child: Text('Loan not found')));
    }

    final monthlyPayment = l.isBank
        ? calculateMonthlyPayment(
            principal: l.totalAmount,
            interestRatePercent: l.interestRate,
            termMonths: l.termMonths,
            customInstallmentAmount: l.customInstallmentAmount,
          )
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.name),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: StatusBadge(
                label: l.isBank ? 'Bank' : 'Personal',
                color: AppColors.primary,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _confirmDelete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                    StatusBadge(
                      label: l.isPaid ? 'Paid' : 'Active',
                      color: l.isPaid ? AppColors.secondary : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Remaining Balance', style: TextStyle(color: Colors.white60, fontSize: 12)),
                Text('Rs ${l.remaining.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const Divider(color: Colors.white24, height: 28),
                Row(
                  children: [
                    _heroStat('Monthly', l.isBank ? 'Rs ${monthlyPayment.toStringAsFixed(2)}' : '—'),
                    _heroStat('Next Due', l.isBank ? (l.nextDueDate ?? '—') : (l.dueDate ?? '—')),
                    _heroStat('Total Paid', 'Rs ${l.paidAmount.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(child: _tabButton('Overview', !showPayments, () => setState(() => showPayments = false))),
                Expanded(child: _tabButton('Payments', showPayments, () => setState(() => showPayments = true))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!showPayments) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loan Repayment Progress', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Principal Paid', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            Text('Rs ${l.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.secondaryDark)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Remaining Principal', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            Text('Rs ${l.remaining.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FinanceProgressBar(value: l.paidAmount, max: l.totalAmount, color: AppColors.secondary),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Loan overview', style: TextStyle(fontWeight: FontWeight.w800)),
                      StatusBadge(label: l.isBank ? 'Bank Loan' : 'Personal Loan', color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _overviewField('Original Amount', 'Rs ${l.totalAmount.toStringAsFixed(2)}'),
                      _overviewField('Interest Rate', l.interestRate != null ? '${l.interestRate}%' : '—'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _overviewField('Term', l.termMonths != null ? '${l.termMonths} months' : '—'),
                      _overviewField('Monthly Payment', l.isBank ? 'Rs ${monthlyPayment.toStringAsFixed(2)}' : '—'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _overviewField('Loan Start Date', l.startDate),
                      _overviewField('Next Due Date', l.isBank ? (l.nextDueDate ?? '—') : (l.dueDate ?? '—')),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            if (payments.isEmpty)
              const FinanceEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No payments yet',
                description: 'Payments you make will show up here.',
              )
            else
              ...payments.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0x1A22C55E),
                            child: Icon(Icons.check, size: 14, color: AppColors.secondaryDark),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.date, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text('Rs ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  )),
          ],
          const SizedBox(height: 20),
          PrimaryActionButton(
            label: isRecording ? 'Recording...' : 'Make Payment',
            icon: Icons.credit_card,
            onPressed: isRecording || l.isPaid ? null : _makePayment,
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.primary : Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _overviewField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
