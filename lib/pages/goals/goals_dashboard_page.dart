import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/goal_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/goal_icon.dart';
import '../../widgets/finance/finance_widgets.dart';
import 'create_goal_page.dart';
import 'goal_completed_page.dart';
import 'goal_details_page.dart';

class GoalsDashboardPage extends StatefulWidget {
  const GoalsDashboardPage({super.key});

  @override
  State<GoalsDashboardPage> createState() => _GoalsDashboardPageState();
}

class _GoalsDashboardPageState extends State<GoalsDashboardPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  List<GoalModel> goals = [];
  bool showCompleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loaded = await _firestoreService.getGoals();
      if (!mounted) return;
      setState(() {
        goals = loaded;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading goals: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = goals.where((g) => !g.isCompleted).toList();
    final completed = goals.where((g) => g.isCompleted).toList();

    final totalSaved = active.fold<double>(0, (s, g) => s + g.currentAmount);
    final totalTarget = active.fold<double>(0, (s, g) => s + g.targetAmount);
    final overallPct = totalTarget > 0 ? (totalSaved / totalTarget * 100) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Goals', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (active.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          CircularProgressRing(
                            percentage: overallPct.clamp(0, 100),
                            size: 72,
                            strokeWidth: 7,
                            color: Colors.white,
                            trackColor: Colors.white.withValues(alpha: 0.25),
                            child: Text(
                              '${overallPct.toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'OVERALL PROGRESS',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs ${totalSaved.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'of Rs ${totalTarget.toStringAsFixed(0)} target',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(child: _tabButton('Active Goals', active.length, !showCompleted, () => setState(() => showCompleted = false))),
                        Expanded(child: _tabButton('Completed', completed.length, showCompleted, () => setState(() => showCompleted = true))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!showCompleted)
                    active.isEmpty
                        ? FinanceEmptyState(
                            icon: Icons.flag_outlined,
                            title: 'No active goals',
                            description: 'Set a savings goal to stay motivated and track your progress.',
                            actionLabel: 'Create Your First Goal',
                            onAction: _openCreate,
                          )
                        : Column(children: active.map(_activeCard).toList())
                  else
                    completed.isEmpty
                        ? const FinanceEmptyState(
                            icon: Icons.emoji_events_outlined,
                            title: 'No completed goals yet',
                            description: 'Keep saving! Your completed goals will appear here.',
                          )
                        : Column(children: completed.map(_completedCard).toList()),
                ],
              ),
            ),
      floatingActionButton: FinanceFab(label: 'Create Goal', onPressed: _openCreate),
    );
  }

  Widget _tabButton(String label, int count, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.textPrimary : Colors.grey[500])),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey[300],
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? AppColors.primary : Colors.grey[600])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCard(GoalModel goal) {
    final pct = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount * 100).clamp(0, 100) : 0.0;
    final remaining = goal.targetAmount - goal.currentAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => _openDetails(goal),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircularProgressRing(
              percentage: pct.toDouble(),
              size: 62,
              strokeWidth: 6,
              color: AppColors.secondary,
              child: Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(goal.goalName, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w800, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniStat('Target', 'Rs ${goal.targetAmount.toStringAsFixed(0)}'),
                      _miniStat('Saved', 'Rs ${goal.currentAmount.toStringAsFixed(0)}'),
                      _miniStat('Remaining', 'Rs ${remaining.clamp(0, double.infinity).toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FinanceProgressBar(value: goal.currentAmount, max: goal.targetAmount, color: AppColors.secondary, thin: true),
                  const SizedBox(height: 6),
                  Text('Due ${goal.targetDate}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _completedCard(GoalModel goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GoalCompletedPage(goalId: goal.id!)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(goalIconFor(goal.iconName), color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(goal.goalName, style: const TextStyle(fontWeight: FontWeight.w800))),
                      const StatusBadge(label: 'Done', color: AppColors.secondary),
                    ],
                  ),
                  Text('Rs ${goal.currentAmount.toStringAsFixed(0)} saved', style: const TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGoalPage()),
    );
    if (created == true) _load();
  }

  Future<void> _openDetails(GoalModel goal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalDetailsPage(goalId: goal.id!)),
    );
    _load();
  }
}
