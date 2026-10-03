import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/lending_model.dart';
import '../../models/lending_repayment_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../../widgets/finance/dark_finance_widgets.dart';
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
  List<AccountModel> accounts = [];
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
      final loadedAccounts = await _firestoreService.getAccounts();
      if (!mounted) return;
      setState(() {
        lendings = loaded;
        accounts = loadedAccounts;
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
        backgroundColor: FinanceDark.card,
        title: Text('Delete "${lending.name}"?', style: const TextStyle(color: FinanceDark.textPrimary)),
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
    if (confirmed != true || lending.id == null) return;
    await _firestoreService.deleteLending(lending.id!);
    _load();
  }

  Future<void> _addRepayment(LendingModel lending) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
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
            final canConfirm = amount > 0 && amount <= lending.remaining && selectedAccount != null;

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
                              Text('Add repayment', style: TextStyle(color: FinanceDark.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                              SizedBox(height: 6),
                              Text('Record money received for this lending.', style: TextStyle(color: FinanceDark.textSecondary, fontSize: 15)),
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
                    const DarkSectionLabel('Amount received'),
                    DarkAmountTile(
                      controller: amountController,
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text('Remaining: Rs ${lending.remaining.toStringAsFixed(2)}', style: const TextStyle(color: FinanceDark.textSecondary, fontSize: 12)),
                    ),
                    const SizedBox(height: 22),
                    const DarkSectionLabel('Add to wallet'),
                    SizedBox(
                      height: 104,
                      child: accounts.isEmpty
                          ? const Center(child: Text('No accounts available', style: TextStyle(color: FinanceDark.textSecondary)))
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: accounts.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
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
                    const SizedBox(height: 18),
                    TextField(
                      controller: noteController,
                      style: const TextStyle(color: FinanceDark.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        filled: true,
                        fillColor: FinanceDark.card,
                        labelStyle: const TextStyle(color: FinanceDark.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinanceDark.divider)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    DarkActionButton(label: 'Add Repayment', icon: Icons.check, onPressed: canConfirm ? () => Navigator.pop(sheetContext, true) : null),
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
    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();
    if (confirmed != true || amount <= 0 || lending.id == null || accountId == null) return;

    final now = DateTime.now();
    await _firestoreService.addLendingRepayment(
      LendingRepaymentModel(
        lendingId: lending.id!,
        accountId: accountId,
        amount: amount,
        date: PeriodCalculator.formatDate(now),
        note: note.isEmpty ? null : note,
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
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: const Text('Lendings', style: TextStyle(fontWeight: FontWeight.w800)),
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
        heroTag: 'lendingsListFab',
        backgroundColor: FinanceDark.accent,
        foregroundColor: FinanceDark.bg,
        elevation: 6,
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
          Icon(icon, color: selected ? FinanceDark.accent : FinanceDark.textSecondary, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: selected ? FinanceDark.accent : FinanceDark.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 2, color: selected ? FinanceDark.accent : Colors.transparent),
        ],
      ),
    );
  }

  Widget _card(LendingModel lending) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DarkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(lending.name, style: const TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(
                  'Rs ${lending.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.accent),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: FinanceDark.textSecondary),
                  onSelected: (value) {
                    if (value == 'repay') _addRepayment(lending);
                    if (value == 'edit') _openEdit(lending);
                    if (value == 'delete') _delete(lending);
                  },
                  color: FinanceDark.card,
                  itemBuilder: (context) => [
                    if (!lending.isSettled)
                      const PopupMenuItem(value: 'repay', child: Text('Add Repayment', style: TextStyle(color: FinanceDark.textPrimary))),
                    const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: FinanceDark.textPrimary))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: FinanceDark.error))),
                  ],
                ),
              ],
            ),
            const Divider(height: 20, color: FinanceDark.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Repayment Progress', style: TextStyle(fontSize: 12, color: FinanceDark.textSecondary)),
                Text(
                  lending.isSettled
                      ? 'Rs ${lending.receivedAmount.toStringAsFixed(2)} received'
                      : 'Rs ${lending.remaining.toStringAsFixed(2)} left',
                  style: TextStyle(fontSize: 12, color: FinanceDark.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DarkProgressBar(value: lending.receivedAmount, max: lending.totalAmount, color: FinanceDark.accent),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${lending.progressPercent.toStringAsFixed(0)}%', style: const TextStyle(color: FinanceDark.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(width: 8),
                StatusBadge(
                  label: lending.isSettled ? 'Settled' : 'Outstanding',
                  color: lending.isSettled ? FinanceDark.success : FinanceDark.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
