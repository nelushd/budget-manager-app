import 'package:flutter/material.dart';

import '../../models/loan_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../../widgets/finance/dark_finance_widgets.dart';
import 'create_bank_loan_page.dart';
import 'create_personal_loan_page.dart';
import 'loan_details_page.dart';

class LoansListPage extends StatefulWidget {
  const LoansListPage({super.key});

  @override
  State<LoansListPage> createState() => _LoansListPageState();
}

class _LoansListPageState extends State<LoansListPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  List<LoanModel> loans = [];
  bool showPaid = false;
  String typeFilter = 'All';

  static const List<String> _typeFilters = ['All', 'Bank Loan', 'Personal Loan'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loaded = await _firestoreService.getLoans();
      if (!mounted) return;
      setState(() {
        loans = loaded;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading loans: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _openCreateChooser() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FinanceDark.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance, color: FinanceDark.accent),
                  title: const Text('Bank Loan', style: TextStyle(color: FinanceDark.textPrimary)),
                  onTap: () => Navigator.pop(sheetContext, 'bank'),
                ),
                ListTile(
                  leading: const Icon(Icons.handshake_outlined, color: FinanceDark.accent),
                  title: const Text('Personal Loan', style: TextStyle(color: FinanceDark.textPrimary)),
                  onTap: () => Navigator.pop(sheetContext, 'personal'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) return;

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => choice == 'bank' ? const CreateBankLoanPage() : const CreatePersonalLoanPage(),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openDetails(LoanModel loan) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailsPage(loanId: loan.id!)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filteredByType = loans.where((l) {
      if (typeFilter == 'Bank Loan') return l.isBank;
      if (typeFilter == 'Personal Loan') return !l.isBank;
      return true;
    }).toList();

    final unpaid = filteredByType.where((l) => !l.isPaid).toList();
    final paid = filteredByType.where((l) => l.isPaid).toList();
    final shown = showPaid ? paid : unpaid;

    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: const Text('Loans', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FinanceDark.accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(child: _tab('Unpaid Loans', Icons.pending_actions_outlined, !showPaid, () => setState(() => showPaid = false))),
                      Expanded(child: _tab('Paid Loans', Icons.check_circle_outline, showPaid, () => setState(() => showPaid = true))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _typeFilters.map((f) {
                      final selected = typeFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: selected,
                          onSelected: (_) => setState(() => typeFilter = f),
                          selectedColor: FinanceDark.accent,
                          labelStyle: TextStyle(color: selected ? FinanceDark.textPrimary : FinanceDark.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                          backgroundColor: FinanceDark.card,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: shown.isEmpty
                      ? FinanceEmptyState(
                          icon: Icons.inbox_outlined,
                          title: showPaid ? 'No paid loans yet' : 'No unpaid loans found',
                          description: showPaid ? 'Fully paid loans will show up here.' : 'Add a new loan to get started.',
                          actionLabel: showPaid ? null : 'Add Loan',
                          onAction: showPaid ? null : _openCreateChooser,
                          showIcon: false,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          children: shown.map(_card).toList(),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'loansListFab',
        backgroundColor: FinanceDark.accent,
        foregroundColor: FinanceDark.bg,
        elevation: 6,
        onPressed: _openCreateChooser,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tab(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: selected ? FinanceDark.accent : FinanceDark.textSecondary, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: selected ? FinanceDark.accent : FinanceDark.textSecondary)),
          const SizedBox(height: 8),
          Container(height: 2, color: selected ? FinanceDark.accent : Colors.transparent),
        ],
      ),
    );
  }

  Widget _card(LoanModel loan) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DarkCard(
        onTap: () => _openDetails(loan),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(loan.name, style: const TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
                Text('Rs ${loan.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.accent)),
              ],
            ),
            const Divider(height: 20, color: FinanceDark.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Progress', style: TextStyle(fontSize: 12, color: FinanceDark.textSecondary)),
                Text('${loan.progressPercent.toStringAsFixed(0)}% paid', style: TextStyle(fontSize: 12, color: FinanceDark.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            DarkProgressBar(value: loan.paidAmount, max: loan.totalAmount, color: FinanceDark.accent),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${loan.progressPercent.toStringAsFixed(0)}%', style: const TextStyle(color: FinanceDark.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(width: 8),
                StatusBadge(label: loan.isBank ? 'Bank' : 'Personal', color: FinanceDark.accent),
                const SizedBox(width: 8),
                StatusBadge(
                  label: loan.isPaid ? 'Paid' : 'Unpaid',
                  color: loan.isPaid ? FinanceDark.success : FinanceDark.warning,
                ),
                const Spacer(),
                Text('Rs ${loan.remaining.toStringAsFixed(2)} left', style: const TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
