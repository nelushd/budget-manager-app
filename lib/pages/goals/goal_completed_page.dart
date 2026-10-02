import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/goal_model.dart';
import '../../models/goal_transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/goal_icon.dart';
import '../../widgets/finance/finance_widgets.dart';
import 'create_goal_page.dart';
import 'goals_dashboard_page.dart';

class GoalCompletedPage extends StatefulWidget {
  final String goalId;

  const GoalCompletedPage({super.key, required this.goalId});

  @override
  State<GoalCompletedPage> createState() => _GoalCompletedPageState();
}

class _GoalCompletedPageState extends State<GoalCompletedPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  GoalModel? goal;
  List<GoalTransactionModel> transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedGoal = await _firestoreService.getGoalById(widget.goalId);
    final loadedTransactions = await _firestoreService.getGoalTransactions(widget.goalId);
    if (!mounted) return;
    setState(() {
      goal = loadedGoal;
      transactions = loadedTransactions;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = goal;

    if (isLoading || g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final depositCount = transactions.where((t) => t.type == 'deposit').length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.35), blurRadius: 24)],
              ),
              child: Icon(goalIconFor(g.iconName), color: Colors.white, size: 56),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, size: 14, color: AppColors.secondaryDark),
                  SizedBox(width: 6),
                  Text('Goal Achieved!', style: TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(g.goalName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Congratulations! You successfully reached your savings target. This is a meaningful financial milestone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], height: 1.4),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Completion Summary'),
                Row(
                  children: [
                    _summary('Final Saved', 'Rs ${g.currentAmount.toStringAsFixed(0)}'),
                    _summary('Target Date', g.targetDate),
                    _summary('Deposits', '$depositCount'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryActionButton(
            label: 'Create Another Goal',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateGoalPage()),
              );
              if (created == true && context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsDashboardPage()),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          PrimaryActionButton(
            label: 'Back to Goals',
            variant: ActionButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summary(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
