import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/loan_model.dart';
import '../../models/loan_payment_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/loan_calculator.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../../widgets/finance/dark_finance_widgets.dart';
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
  List<AccountModel> accounts = [];
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
      final loadedAccounts = await _firestoreService.getAccounts();
      if (!mounted) return;
      setState(() {
        loan = loadedLoan;
        payments = loadedPayments;
        accounts = loadedAccounts;
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
    AccountModel? selectedAccount = accounts.where((account) => account.isDefault).firstOrNull;
    selectedAccount ??= accounts.isNotEmpty ? accounts.first : null;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FinanceDark.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            final canConfirm = amount > 0 && amount <= l.remaining && selectedAccount != null;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: FinanceDark.divider, borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pay now', style: TextStyle(color: FinanceDark.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                              SizedBox(height: 6),
                              Text('Record a payment for this loan.', style: TextStyle(color: FinanceDark.textSecondary, fontSize: 15)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: FinanceDark.textSecondary),
                          style: IconButton.styleFrom(backgroundColor: FinanceDark.card),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const DarkSectionLabel('Amount'),
                    DarkAmountTile(
                      controller: amountController,
                      hint: '0.00',
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text('Remaining: Rs ${l.remaining.toStringAsFixed(2)}', style: const TextStyle(color: FinanceDark.textSecondary, fontSize: 12)),
                    ),
                    const SizedBox(height: 22),
                    const DarkSectionLabel('Pay from wallet'),
                    SizedBox(
                      height: 104,
                      child: accounts.isEmpty
                          ? const Center(child: Text('No accounts available', style: TextStyle(color: FinanceDark.textSecondary)))
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: accounts.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 10),
                              itemBuilder: (_, index) {
                                final account = accounts[index];
                                final isSelected = selectedAccount?.id == account.id;
                                return GestureDetector(
                                  onTap: () => setSheetState(() => selectedAccount = account),
                                  child: Container(
                                    width: 152,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? FinanceDark.accent.withValues(alpha: 0.14) : FinanceDark.card,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isSelected ? FinanceDark.accent : FinanceDark.divider, width: isSelected ? 2 : 1),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.account_balance_wallet_outlined, color: isSelected ? FinanceDark.accent : FinanceDark.textSecondary, size: 20),
                                        const Spacer(),
                                        Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FinanceDark.textPrimary, fontSize: 13)),
                                        const SizedBox(height: 3),
                                        Text('Rs ${account.balance.toStringAsFixed(2)}', style: const TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: DarkActionButton(label: 'Make Payment', icon: Icons.check, onPressed: canConfirm ? () => Navigator.pop(sheetContext, true) : null),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final accountId = selectedAccount?.id;
    amountController.dispose();
    if (confirmed != true || amount <= 0 || l.id == null || accountId == null) return;

    setState(() => isRecording = true);
    try {
      final now = DateTime.now();
      await _firestoreService.addLoanPayment(
        LoanPaymentModel(
          loanId: l.id!,
          accountId: accountId,
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
    final loanToDelete = l!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FinanceDark.card,
        title: Text('Delete "${loanToDelete.name}"?', style: const TextStyle(color: FinanceDark.textPrimary)),
        content: const Text('This cannot be undone.', style: TextStyle(color: FinanceDark.textSecondary)),
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
    await _firestoreService.deleteLoan(loanToDelete.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = loan;

    if (isLoading && l == null) {
      return const Scaffold(
        backgroundColor: FinanceDark.bg,
        body: Center(child: CircularProgressIndicator(color: FinanceDark.accent)),
      );
    }
    if (l == null) {
      return const Scaffold(
        backgroundColor: FinanceDark.bg,
        body: Center(child: Text('Loan not found', style: TextStyle(color: FinanceDark.textPrimary))),
      );
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
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: Text(l.name),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: StatusBadge(
                label: l.isBank ? 'Bank' : 'Personal',
                color: FinanceDark.accent,
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
                      color: l.isPaid ? FinanceDark.success : FinanceDark.warning,
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
            decoration: BoxDecoration(color: FinanceDark.card, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(child: _tabButton('Overview', !showPayments, () => setState(() => showPayments = false))),
                Expanded(child: _tabButton('Payments', showPayments, () => setState(() => showPayments = true))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!showPayments) ...[
            DarkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loan Repayment Progress', style: TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Principal Paid', style: TextStyle(fontSize: 11, color: FinanceDark.textSecondary)),
                            Text('Rs ${l.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.accent)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Remaining Principal', style: TextStyle(fontSize: 11, color: FinanceDark.textSecondary)),
                            Text('Rs ${l.remaining.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DarkProgressBar(value: l.paidAmount, max: l.totalAmount, color: FinanceDark.accent),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DarkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Loan overview', style: TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary)),
                      StatusBadge(label: l.isBank ? 'Bank Loan' : 'Personal Loan', color: FinanceDark.accent),
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
                    child: DarkCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0x1A22C55E),
                            child: Icon(Icons.check, size: 14, color: FinanceDark.success),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.date, style: const TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w600))),
                          Text('Rs ${p.amount.toStringAsFixed(2)}', style: const TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  )),
          ],
          const SizedBox(height: 20),
          DarkActionButton(
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
        decoration: BoxDecoration(color: selected ? FinanceDark.accent.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, color: selected ? FinanceDark.accent : FinanceDark.textSecondary),
        ),
      ),
    );
  }

  Widget _overviewField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: FinanceDark.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: FinanceDark.textPrimary)),
        ],
      ),
    );
  }
}
