import 'package:flutter/material.dart';

import '../pages/analytics/analytics_page.dart';
import '../pages/budget/budgets_list_page.dart';
import '../pages/home/home_page.dart';
import '../pages/insights/insights_page.dart';

/// Bottom nav shell: Home, Budget, Analytics, and AI Insights — Accounts,
/// Profile, Goals, Recurring, and SMS Drafts stay reachable via the existing
/// drawer / FAB quick actions rather than adding more tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;

  static const _pages = [HomePage(), BudgetsListPage(), AnalyticsPage(), InsightsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0B0F14),
        selectedItemColor: const Color(0xFF2DD4A7),
        unselectedItemColor: const Color(0xFF6B7684),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_rounded), label: 'Budget'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline_rounded), label: 'Insights'),
        ],
      ),
    );
  }
}
