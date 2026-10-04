import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';
import '../../models/activity_entry.dart';
import '../../services/firestore_service.dart';
import '../../utils/activity_builder.dart';
import '../../utils/category_color.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/analytics/daily_bar_chart.dart';
import '../../widgets/analytics/donut_chart.dart';
import '../../widgets/finance/finance_widgets.dart';

class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF141B24);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF232C38);
}

Widget _darkCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _Dark.card,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _BreakdownLine {
  final String title;
  final IconData icon;
  final double amount;
  final int count;
  final double pct;

  const _BreakdownLine({
    required this.title,
    required this.icon,
    required this.amount,
    required this.count,
    required this.pct,
  });
}

class _TopCategoryResult {
  final String title;
  final double amount;
  final double pct;

  const _TopCategoryResult(this.title, this.amount, this.pct);
}

class _HighlightData {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String subtitle;

  const _HighlightData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.subtitle,
  });
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool _isLoading = true;
  List<ActivityEntry> _entries = [];

  int _tabIndex = 0; // 0 general, 1 expense category, 2 income category
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  PeriodWindow? _customWindow;

  final PageController _highlightsController = PageController();
  int _highlightsPage = 0;

  static const _palette = [
    _Dark.accent,
    Color(0xFF6366F1),
    AppColors.warning,
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    AppColors.success,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final entries = await loadActivityFeed(_firestoreService);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading analytics: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  PeriodWindow get _window =>
      _customWindow ?? PeriodCalculator.windowFor('monthly', _selectedMonth);

  List<ActivityEntry> get _entriesInWindow {
    final w = _window;
    return _entries.where((e) => w.contains(e.date)).toList();
  }

  double _sum(Iterable<ActivityEntry> entries) => entries.fold(0.0, (s, e) => s + e.amount);

  double get _totalIncome => _sum(_entriesInWindow.where((e) => e.kind == 'income'));
  double get _totalExpense => _sum(_entriesInWindow.where((e) => e.kind == 'expense'));
  double get _cashIn => _sum(_entriesInWindow.where((e) => e.isInflow));
  double get _cashOut => _sum(_entriesInWindow.where((e) => !e.isInflow));

  int get _daysInWindow => _window.end.difference(_window.start).inDays + 1;
  double get _avgDailyIncome => _daysInWindow <= 0 ? 0 : _totalIncome / _daysInWindow;
  double get _avgDailySpending => _daysInWindow <= 0 ? 0 : _totalExpense / _daysInWindow;

  MapEntry<String, int>? get _mostFrequent {
    final counts = <String, int>{};
    for (final e in _entriesInWindow) {
      counts[e.title] = (counts[e.title] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  MapEntry<String, int>? get _mostUsedAccount {
    final counts = <String, int>{};
    for (final e in _entriesInWindow) {
      if (e.accountName.isEmpty) continue;
      counts[e.accountName] = (counts[e.accountName] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  _TopCategoryResult? get _topCategory {
    final sums = <String, double>{};
    for (final e in _entriesInWindow.where((e) => e.kind == 'expense')) {
      sums[e.title] = (sums[e.title] ?? 0) + e.amount;
    }
    if (sums.isEmpty) return null;
    final top = sums.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final pct = _totalExpense > 0 ? top.value / _totalExpense * 100 : 0.0;
    return _TopCategoryResult(top.key, top.value, pct);
  }

  int get _smallPaymentsCount =>
      _entriesInWindow.where((e) => e.kind == 'expense' && e.amount < 500).length;

  List<_BreakdownLine> _breakdownFor(String kind) {
    final entries = _entriesInWindow.where((e) => e.kind == kind).toList();
    final total = _sum(entries);
    final grouped = <String, List<ActivityEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.title, () => []).add(e);
    }
    final lines = grouped.entries.map((entry) {
      final amount = _sum(entry.value);
      return _BreakdownLine(
        title: entry.key,
        icon: entry.value.first.icon,
        amount: amount,
        count: entry.value.length,
        pct: total > 0 ? amount / total * 100 : 0,
      );
    }).toList();
    lines.sort((a, b) => b.amount.compareTo(a.amount));
    return lines;
  }

  List<DailyBarPoint> get _dailyPoints {
    final w = _window;
    final points = <DailyBarPoint>[];
    for (var day = w.start; !day.isAfter(w.end); day = day.add(const Duration(days: 1))) {
      final dayEntries = _entriesInWindow.where(
        (e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
      );
      points.add(DailyBarPoint(
        day: day.day,
        income: _sum(dayEntries.where((e) => e.kind == 'income')),
        expense: _sum(dayEntries.where((e) => e.kind == 'expense')),
      ));
    }
    return points;
  }

  String _fmt(double amount) => 'Rs ${NumberFormat('#,##0.00').format(amount)}';

  List<DateTime> get _recentMonths {
    final now = DateTime.now();
    return List.generate(12, (i) => DateTime(now.year, now.month - i, 1));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: _window.start, end: _window.end),
    );
    if (picked == null || !mounted) return;
    setState(() => _customWindow = PeriodWindow(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Dark.bg,
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w800, color: _Dark.textPrimary),
        ),
        backgroundColor: _Dark.bg,
        foregroundColor: _Dark.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _load,
          ),
          IconButton(
            tooltip: 'Pick date range',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDateRange,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Dark.accent))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _tabsRow(),
                  const SizedBox(height: 14),
                  _monthChips(),
                  const SizedBox(height: 10),
                  _rangeChip(),
                  const SizedBox(height: 18),
                  if (_tabIndex == 0)
                    ..._generalTab()
                  else
                    _categoryTab(_tabIndex == 1 ? 'expense' : 'income'),
                ],
              ),
            ),
    );
  }

  Widget _tabsRow() {
    const tabs = ['General', 'Expense Category', 'Income Category'];
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _tabIndex == i ? _Dark.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _tabIndex == i ? _Dark.accent : _Dark.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _monthChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recentMonths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = _recentMonths[index];
          final selected = _customWindow == null &&
              month.year == _selectedMonth.year &&
              month.month == _selectedMonth.month;
          return ChoiceChip(
            label: Text(DateFormat("MMM ''yy").format(month)),
            selected: selected,
            onSelected: (_) => setState(() {
              _selectedMonth = month;
              _customWindow = null;
            }),
            selectedColor: _Dark.accent,
            labelStyle: TextStyle(
              color: selected ? const Color(0xFF0B0F14) : _Dark.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: _Dark.card,
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  Widget _rangeChip() {
    final w = _window;
    final label = '${DateFormat('MMM d').format(w.start)} - ${DateFormat('MMM d').format(w.end)}';
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _Dark.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _Dark.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: _Dark.accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: _Dark.accent, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _generalTab() {
    final expenseBreakdown = _breakdownFor('expense');

    return [
      _darkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Income', _totalIncome, AppColors.success),
            const SizedBox(height: 14),
            _summaryRow('Expenses', _totalExpense, AppColors.error),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Spending Highlights',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _Dark.textPrimary),
      ),
      const SizedBox(height: 12),
      _highlightsCarousel(),
      const SizedBox(height: 20),
      _sectionHeaderRow(Icons.bar_chart_rounded, 'Daily Summary'),
      const SizedBox(height: 12),
      _darkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _legendDot(AppColors.error, 'Expense'),
                const SizedBox(width: 16),
                _legendDot(AppColors.success, 'Income'),
              ],
            ),
            const SizedBox(height: 14),
            DailyBarChart(points: _dailyPoints),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Spending Distribution',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _Dark.textPrimary),
      ),
      const SizedBox(height: 12),
      _darkCard(
        child: expenseBreakdown.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No expenses in this period.', style: TextStyle(color: _Dark.textSecondary)),
                ),
              )
            : Column(
                children: [
                  for (final line in expenseBreakdown) _distributionRow(line),
                  Divider(height: 24, color: _Dark.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expenses',
                        style: TextStyle(fontWeight: FontWeight.w700, color: _Dark.textPrimary),
                      ),
                      Text(
                        _fmt(_totalExpense),
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      const SizedBox(height: 20),
      _sectionHeaderRow(Icons.donut_large_rounded, 'Spending by Category'),
      const SizedBox(height: 12),
      _darkCard(
        child: expenseBreakdown.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text('No expenses in this period.', style: TextStyle(color: _Dark.textSecondary)),
                ),
              )
            : Column(
                children: [
                  DonutChart(
                    slices: [
                      for (var i = 0; i < expenseBreakdown.length; i++)
                        DonutSlice(
                          color: _palette[i % _palette.length],
                          value: expenseBreakdown[i].amount,
                        ),
                    ],
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total', style: TextStyle(color: _Dark.textSecondary, fontSize: 12)),
                        Text(
                          _fmt(_totalExpense),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _Dark.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(height: 1, color: _Dark.divider),
                  const SizedBox(height: 10),
                  for (var i = 0; i < expenseBreakdown.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _palette[i % _palette.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              expenseBreakdown[i].title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _Dark.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${expenseBreakdown[i].pct.toStringAsFixed(1)}%',
                            style: const TextStyle(color: _Dark.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _fmt(expenseBreakdown[i].amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: _Dark.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  Widget _summaryRow(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _Dark.textPrimary),
            ),
            Text(_fmt(amount), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 4,
            backgroundColor: _Dark.divider,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeaderRow(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _Dark.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _Dark.textPrimary),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: _Dark.textSecondary)),
      ],
    );
  }

  Widget _distributionRow(_BreakdownLine line) {
    final tint = colorForCategory(line.title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(line.icon, color: tint, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _Dark.textPrimary),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _Dark.textSecondary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(line.amount),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _Dark.textPrimary),
              ),
              Text('${line.pct.toStringAsFixed(1)}%', style: const TextStyle(color: _Dark.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (line.pct / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _Dark.divider,
              valueColor: AlwaysStoppedAnimation(tint),
            ),
          ),
        ],
      ),
    );
  }

  List<_HighlightData> _highlightData() {
    final mostFrequent = _mostFrequent;
    final mostUsedAccount = _mostUsedAccount;
    final topCategory = _topCategory;

    return [
      _HighlightData(
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
        label: 'Total Income',
        value: _fmt(_totalIncome),
        subtitle: 'Total earned',
      ),
      _HighlightData(
        icon: Icons.south_west_rounded,
        color: AppColors.success,
        label: 'Cash In',
        value: _fmt(_cashIn),
        subtitle: 'Total earned',
      ),
      _HighlightData(
        icon: Icons.receipt_long_outlined,
        color: AppColors.error,
        label: 'Total Spent',
        value: _fmt(_totalExpense),
        subtitle: 'Total expenses',
      ),
      _HighlightData(
        icon: Icons.north_east_rounded,
        color: AppColors.error,
        label: 'Cash Out',
        value: _fmt(_cashOut),
        subtitle: 'Total expenses',
      ),
      _HighlightData(
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
        label: 'Avg Daily Income',
        value: _fmt(_avgDailyIncome),
        subtitle: 'Per day average',
      ),
      _HighlightData(
        icon: Icons.trending_down_rounded,
        color: AppColors.error,
        label: 'Avg Daily Spending',
        value: _fmt(_avgDailySpending),
        subtitle: 'Per day average',
      ),
      _HighlightData(
        icon: Icons.swap_horiz_rounded,
        color: _Dark.accent,
        label: 'Most Frequent',
        value: mostFrequent?.key ?? '—',
        subtitle: mostFrequent == null ? 'No transactions' : '${mostFrequent.value} transactions',
      ),
      _HighlightData(
        icon: Icons.credit_card_outlined,
        color: const Color(0xFF8B5CF6),
        label: 'Most Used Account',
        value: mostUsedAccount?.key ?? '—',
        subtitle: 'Primary payment method',
      ),
      _HighlightData(
        icon: Icons.emoji_events_outlined,
        color: AppColors.warning,
        label: 'Top Category',
        value: topCategory?.title ?? '—',
        subtitle: topCategory == null ? 'No expenses' : '${topCategory.pct.toStringAsFixed(1)}% of expenses',
      ),
      _HighlightData(
        icon: Icons.receipt_outlined,
        color: AppColors.info,
        label: 'Small Payments',
        value: '$_smallPaymentsCount',
        subtitle: '< Rs 500.00',
      ),
    ];
  }

  Widget _highlightsCarousel() {
    final data = _highlightData();
    final pages = <List<_HighlightData>>[];
    for (var i = 0; i < data.length; i += 4) {
      pages.add(data.sublist(i, i + 4 > data.length ? data.length : i + 4));
    }

    return Column(
      children: [
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _highlightsController,
            onPageChanged: (i) => setState(() => _highlightsPage = i),
            itemCount: pages.length,
            itemBuilder: (context, pageIndex) {
              final items = pages[pageIndex];
              return GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (final d in items) _highlightCard(d)],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _highlightsPage == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _highlightsPage == i ? _Dark.accent : _Dark.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _highlightCard(_HighlightData data) {
    return _darkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: data.color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(data.label, style: const TextStyle(color: _Dark.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: data.color),
          ),
          const Spacer(),
          Text(
            data.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _Dark.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _categoryTab(String kind) {
    final lines = _breakdownFor(kind);
    final amountColor = kind == 'income' ? AppColors.success : AppColors.error;

    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            'No ${kind == 'income' ? 'income' : 'expenses'} in this period.',
            style: const TextStyle(color: _Dark.textSecondary),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [for (final line in lines) _categoryGridCard(line, amountColor)],
    );
  }

  Widget _categoryGridCard(_BreakdownLine line, Color amountColor) {
    final tint = colorForCategory(line.title);
    return _darkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                child: Icon(line.icon, color: tint, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _Dark.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${line.pct.toStringAsFixed(1)}%',
                  style: const TextStyle(color: _Dark.accent, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            line.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _Dark.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            _fmt(line.amount),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: amountColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${line.count} txn${line.count == 1 ? '' : 's'}',
            style: const TextStyle(color: _Dark.textSecondary, fontSize: 11),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (line.pct / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _Dark.divider,
              valueColor: AlwaysStoppedAnimation(tint),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _highlightsController.dispose();
    super.dispose();
  }
}
