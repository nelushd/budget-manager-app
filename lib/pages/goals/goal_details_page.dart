import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/goal_model.dart';
import '../../models/goal_transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/goal_icon.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import 'goal_completed_page.dart';

class GoalDetailsPage extends StatefulWidget {
  final String goalId;

  const GoalDetailsPage({super.key, required this.goalId});

  @override
  State<GoalDetailsPage> createState() => _GoalDetailsPageState();
}

class _GoalDetailsPageState extends State<GoalDetailsPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  GoalModel? goal;
  List<GoalTransactionModel> transactions = [];

  bool showDeposit = false;
  bool showWithdraw = false;
  bool showDelete = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loadedGoal = await _firestoreService.getGoalById(widget.goalId);
      final loadedTransactions = await _firestoreService.getGoalTransactions(widget.goalId);
      if (!mounted) return;
      setState(() {
        goal = loadedGoal;
        transactions = loadedTransactions;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading goal details: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitTransaction(String type) async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0 || goal?.id == null) return;

    final now = DateTime.now();
    final updated = await _firestoreService.addGoalTransaction(
      GoalTransactionModel(
        goalId: goal!.id!,
        amount: amount,
        type: type,
        date: PeriodCalculator.formatDate(now),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: now.millisecondsSinceEpoch,
      ),
    );

    _amountController.clear();
    _noteController.clear();

    if (!mounted) return;

    if (updated.isCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GoalCompletedPage(goalId: widget.goalId)),
      );
      return;
    }

    setState(() {
      showDeposit = false;
      showWithdraw = false;
    });
    _load();
  }

  Future<void> _delete() async {
    if (goal?.id == null) return;
    await _firestoreService.deleteGoal(goal!.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _showEditSheet() async {
    final g = goal;
    if (g == null) return;

    final nameController = TextEditingController(text: g.goalName);
    final notesController = TextEditingController(text: g.notes);
    DateTime targetDate = PeriodCalculator.parseDate(g.targetDate);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Goal Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: targetDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setSheetState(() => targetDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(PeriodCalculator.formatDate(targetDate)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryActionButton(
                    label: 'Save Changes',
                    onPressed: () async {
                      await _firestoreService.updateGoal(
                        g.copyWith(
                          goalName: nameController.text.trim(),
                          notes: notesController.text.trim(),
                          targetDate: PeriodCalculator.formatDate(targetDate),
                        ),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      _load();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = goal;

    if (isLoading && g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (g == null) {
      return const Scaffold(body: Center(child: Text('Goal not found')));
    }

    final pct = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100).clamp(0, 100) : 0.0;
    final remaining = g.targetAmount - g.currentAmount;

    final tip = _savingsTip(g, remaining.toDouble());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(g.goalName),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _showEditSheet)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: CircularProgressRing(
              percentage: pct.toDouble(),
              size: 160,
              strokeWidth: 13,
              color: AppColors.secondary,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(goalIconFor(g.iconName), color: AppColors.secondary, size: 30),
                  const SizedBox(height: 4),
                  Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('completed', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Goal Progress'),
                Row(
                  children: [
                    _stat('Current Savings', 'Rs ${g.currentAmount.toStringAsFixed(0)}', AppColors.secondaryDark),
                    _stat('Target Amount', 'Rs ${g.targetAmount.toStringAsFixed(0)}', AppColors.textPrimary),
                    _stat('Remaining', 'Rs ${remaining.clamp(0, double.infinity).toStringAsFixed(0)}', remaining <= 0 ? AppColors.secondary : AppColors.textPrimary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Goal Information'),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Target Date'),
                    const Spacer(),
                    Text(g.targetDate, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                if (g.notes.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(g.notes, style: TextStyle(color: Colors.grey[600], height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (tip != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryActionButton(
                  label: 'Add Savings',
                  onPressed: () => setState(() {
                    showDeposit = true;
                    showWithdraw = false;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryActionButton(
                  label: 'Withdraw',
                  variant: ActionButtonVariant.ghost,
                  onPressed: () => setState(() {
                    showWithdraw = true;
                    showDeposit = false;
                  }),
                ),
              ),
            ],
          ),
          if (showDeposit || showWithdraw) ...[
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(showDeposit ? 'Add Savings' : 'Withdraw Funds', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  AmountField(label: 'Amount', controller: _amountController),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() {
                            showDeposit = false;
                            showWithdraw = false;
                          }),
                          child: const Text('Cancel'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: PrimaryActionButton(
                          label: showDeposit ? 'Add Savings' : 'Withdraw',
                          onPressed: () => _submitTransaction(showDeposit ? 'deposit' : 'withdraw'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (transactions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Savings Transaction History'),
            ...transactions.map((t) {
              final isDeposit = t.type == 'deposit';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: (isDeposit ? AppColors.secondary : AppColors.error).withValues(alpha: 0.12),
                      child: Icon(
                        isDeposit ? Icons.south_west_rounded : Icons.north_east_rounded,
                        size: 16,
                        color: isDeposit ? AppColors.secondaryDark : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.note ?? (isDeposit ? 'Deposit' : 'Withdrawal'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(t.date, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    Text(
                      '${isDeposit ? '+' : '-'}Rs ${t.amount.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: isDeposit ? AppColors.secondaryDark : AppColors.error),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          if (showDelete)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  const Text('Delete this goal?', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextButton(onPressed: () => setState(() => showDelete = false), child: const Text('Cancel'))),
                      Expanded(child: TextButton(onPressed: _delete, child: const Text('Delete', style: TextStyle(color: AppColors.error)))),
                    ],
                  ),
                ],
              ),
            )
          else
            PrimaryActionButton(
              label: 'Delete Goal',
              variant: ActionButtonVariant.danger,
              onPressed: () => setState(() => showDelete = true),
            ),
        ],
      ),
    );
  }

  String? _savingsTip(GoalModel g, double remaining) {
    if (remaining <= 0) return "You've reached your goal! Consider creating a new savings challenge.";

    DateTime target;
    try {
      target = PeriodCalculator.parseDate(g.targetDate);
    } catch (_) {
      return null;
    }

    final monthsLeft = ((target.difference(DateTime.now()).inDays) / 30).ceil().clamp(1, 1000);
    final monthlyNeeded = remaining / monthsLeft;

    return 'Save Rs ${monthlyNeeded.toStringAsFixed(0)}/month to reach "${g.goalName}" by ${g.targetDate}.';
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
