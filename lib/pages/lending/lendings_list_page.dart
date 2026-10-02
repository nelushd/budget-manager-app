import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/lending_model.dart';
import '../../models/lending_repayment_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import 'create_lending_page.dart';

class LendingsListPage extends StatefulWidget {
  const LendingsListPage({super.key});

  @override
  State<LendingsListPage> createState() => _LendingsListPageState();
}

class _LendingsListPageState extends State<LendingsListPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  List<LendingModel> lendings = [];
  bool showReceived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loaded = await _firestoreService.getLendings();
      if (!mounted) return;
      setState(() {
        lendings = loaded;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading lendings: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateLendingPage()),
    );
    if (created == true) _load();
  }

  Future<void> _openEdit(LendingModel lending) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateLendingPage(existing: lending)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(LendingModel lending) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${lending.name}"?'),
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
    if (confirmed != true || lending.id == null) return;
    await _firestoreService.deleteLending(lending.id!);
    _load();
  }

  Future<void> _addRepayment(LendingModel lending) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

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
              const Text('Add Repayment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              AmountField(label: 'Amount Received', controller: amountController),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 18),
              PrimaryActionButton(
                label: 'Add Repayment',
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        );
      },
    );

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (confirmed != true || amount <= 0 || lending.id == null) return;

    final now = DateTime.now();
    await _firestoreService.addLendingRepayment(
      LendingRepaymentModel(
        lendingId: lending.id!,
        amount: amount,
        date: PeriodCalculator.formatDate(now),
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        createdAt: now.millisecondsSinceEpoch,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = lendings.where((l) => !l.isSettled).toList();
    final received = lendings.where((l) => l.isSettled).toList();
    final shown = showReceived ? received : outstanding;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lendings', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(child: _tab('Outstanding Lendings', Icons.north_east_rounded, !showReceived, () => setState(() => showReceived = false))),
                      Expanded(child: _tab('Received Lendings', Icons.check_circle_outline, showReceived, () => setState(() => showReceived = true))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: shown.isEmpty
                      ? FinanceEmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: showReceived ? 'No received lendings yet' : 'No outstanding lendings found',
                          description: showReceived
                              ? 'Settled lendings will show up here.'
                              : 'Add a new lending to get started.',
                          actionLabel: showReceived ? null : 'Add Lending',
                          onAction: showReceived ? null : _openCreate,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          children: shown.map(_card).toList(),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'lendingsListFab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tab(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: selected ? AppColors.secondary : Colors.grey[400], size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: selected ? AppColors.secondaryDark : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 2, color: selected ? AppColors.secondary : Colors.transparent),
        ],
      ),
    );
  }

  Widget _card(LendingModel lending) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(lending.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(
                  'Rs ${lending.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.secondaryDark),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'repay') _addRepayment(lending);
                    if (value == 'edit') _openEdit(lending);
                    if (value == 'delete') _delete(lending);
                  },
                  itemBuilder: (context) => [
                    if (!lending.isSettled)
                      const PopupMenuItem(value: 'repay', child: Text('Add Repayment')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Repayment Progress', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                Text(
                  lending.isSettled
                      ? 'Rs ${lending.receivedAmount.toStringAsFixed(2)} received'
                      : 'Rs ${lending.remaining.toStringAsFixed(2)} left',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FinanceProgressBar(value: lending.receivedAmount, max: lending.totalAmount, color: AppColors.secondary),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${lending.progressPercent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(width: 8),
                StatusBadge(
                  label: lending.isSettled ? 'Settled' : 'Outstanding',
                  color: lending.isSettled ? AppColors.secondary : AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
