import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/activity_entry.dart';
import '../../services/firestore_service.dart';
import '../../utils/activity_builder.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/sidebar_drawer.dart';
import '../accounts/accounts_page.dart';
import '../accounts/credit_cards_page.dart';
import '../budget/create_budget_page.dart';
import '../lending/lendings_list_page.dart';
import '../loan/loans_list_page.dart';
import '../recurring/recurring_list_page.dart';
import '../transaction/add_transaction_page.dart';
import '../transaction/transfer_page.dart';
import '../transactions_page.dart';
import '../profile_page.dart';


class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);

  static const Color card = Color(0xFF1B2430);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2E3A4A);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  List<AccountModel> _accounts = [];
  List<ActivityEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _firestoreService.getAccounts(),
        loadActivityFeed(_firestoreService),
      ]);

      if (!mounted) return;

      setState(() {
        _accounts = results[0] as List<AccountModel>;
        _entries = results[1] as List<ActivityEntry>;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading home dashboard: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _totalBalance {
    return _accounts
        .where((account) => account.isIncluded)
        .fold(0.0, (sum, account) => sum + account.balance);
  }

  PeriodWindow get _monthWindow => PeriodCalculator.windowFor('monthly', DateTime.now());

  List<ActivityEntry> get _entriesThisMonth {
    final window = _monthWindow;
    return _entries.where((entry) => window.contains(entry.date)).toList();
  }

  double get _cashIn => _entriesThisMonth
      .where((entry) => entry.isInflow)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get _cashOut => _entriesThisMonth
      .where((entry) => !entry.isInflow)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get _monthlyIncome => _entriesThisMonth
      .where((entry) => entry.kind == 'income')
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get _monthlyExpense => _entriesThisMonth
      .where((entry) => entry.kind == 'expense')
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get _netCashFlow => _cashIn - _cashOut;

  /// All entries grouped by calendar day, most recent day first.
  List<MapEntry<DateTime, List<ActivityEntry>>> get _groupedByDay {
    final grouped = <DateTime, List<ActivityEntry>>{};
    for (final entry in _entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      grouped.putIfAbsent(day, () => []).add(entry);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return groups;
  }

  String _formatAmount(double amount) {
    return 'Rs. ${NumberFormat('#,##0.00').format(amount)}';
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  String _displayName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'User';
  }

  String _displayEmail(User? user) {
    return user?.email ?? 'No email available';
  }

  String _initial(User? user) {
    final name = _displayName(user);
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _displayName(user);
    final displayEmail = _displayEmail(user);
    final avatarInitial = _initial(user);

    return Scaffold(
      backgroundColor: _Dark.bg,
      drawer: SidebarDrawer(
        userName: displayName,
        userEmail: displayEmail,
      ),
      appBar: AppBar(
        backgroundColor: _Dark.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _Dark.textPrimary),
        title: Text(
          'Hi $displayName',
          style: const TextStyle(
            color: _Dark.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfilePage(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _Dark.accent,
                child: Text(
                  avatarInitial,
                  style: const TextStyle(
                    color: Color(0xFF0B0F14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _netCashFlowCard(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _cashFlowCard(
                            title: 'Cash In',
                            amount: _cashIn,
                            subLabel: 'Income',
                            subAmount: _monthlyIncome,
                            color: AppColors.success,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _cashFlowCard(
                            title: 'Cash Out',
                            amount: _cashOut,
                            subLabel: 'Expense',
                            subAmount: _monthlyExpense,
                            color: AppColors.error,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _myAccountsSection(),
                    const SizedBox(height: 30),
                    _recentTransactionsSection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'homeFab',
        backgroundColor: _Dark.accent,
        elevation: 6,
        onPressed: () => _showQuickActionsSheet(context),
        child: const Icon(
          Icons.add,
          color: Color(0xFF0B0F14),
        ),
      ),
    );
  }

  Widget _netCashFlowCard() {
    final window = _monthWindow;
    final rangeLabel = '${DateFormat('MMM d, yyyy').format(window.start)} - '
        '${DateFormat('MMM d, yyyy').format(window.end)}';
    final netIncome = _monthlyIncome - _monthlyExpense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Dark.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Dark.accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Cash Flow',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            _formatAmount(_netCashFlow),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rangeLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Income',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                _formatAmount(netIncome),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _cashFlowCard({
    required String title,
    required double amount,
    required String subLabel,
    required double subAmount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Dark.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Dark.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: _Dark.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${NumberFormat('#,##0.00').format(amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Divider(height: 18, color: _Dark.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subLabel,
                style: const TextStyle(color: _Dark.textSecondary, fontSize: 11),
              ),
              Text(
                'Rs. ${NumberFormat('#,##0.00').format(subAmount)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _Dark.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _myAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Dark.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _Dark.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Accounts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _Dark.textPrimary,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _Dark.accent),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountsPage()),
                      );
                      _loadData();
                    },
                    child: const Text('See all'),
                  ),
                ],
              ),
              const Text(
                'All Accounts Balance',
                style: TextStyle(color: _Dark.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _formatAmount(_totalBalance),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _Dark.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_accounts.isEmpty)
          const Text(
            'No accounts yet.',
            style: TextStyle(color: _Dark.textSecondary),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _accounts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _accountMiniCard(_accounts[index]),
            ),
          ),
      ],
    );
  }

  Widget _accountMiniCard(AccountModel account) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Dark.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Dark.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _Dark.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              account.type == 'credit_card' ? Icons.credit_card : Icons.account_balance_wallet,
              color: _Dark.accent,
              size: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _Dark.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatAmount(account.balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _Dark.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentTransactionsSection() {
    final groups = _groupedByDay.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _Dark.textPrimary,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _Dark.accent),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionsPage()),
              ),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No transactions yet. Add your first income or expense.',
              style: TextStyle(color: _Dark.textSecondary),
            ),
          )
        else
          for (final group in groups) _dayGroup(group.key, group.value),
      ],
    );
  }

  Widget _dayGroup(DateTime day, List<ActivityEntry> entries) {
    final dayIn = entries.where((e) => e.isInflow).fold(0.0, (sum, e) => sum + e.amount);
    final dayOut = entries.where((e) => !e.isInflow).fold(0.0, (sum, e) => sum + e.amount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dayLabel(day),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _Dark.textPrimary,
                ),
              ),
              Row(
                children: [
                  if (dayIn > 0)
                    Text(
                      '+ ${_formatAmount(dayIn)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  if (dayIn > 0 && dayOut > 0) const SizedBox(width: 8),
                  if (dayOut > 0)
                    Text(
                      '- ${_formatAmount(dayOut)}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _Dark.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _Dark.divider),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  Column(
                    children: [
                      _entryTile(entries[i]),
                      if (i != entries.length - 1)
                        Divider(height: 1, color: _Dark.divider),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(ActivityEntry entry) {
    final color = entry.isInflow ? AppColors.success : AppColors.error;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _Dark.textPrimary,
                  ),
                ),
                if (entry.subtitle.isNotEmpty)
                  Text(entry.subtitle, style: const TextStyle(color: _Dark.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${entry.isInflow ? '+' : '-'} ${_formatAmount(entry.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showQuickActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  decoration: BoxDecoration(
                    color: _Dark.card.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _Dark.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Quick Actions',
                          style: TextStyle(
                            color: _Dark.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.9,
                        children: [
                          _quickActionCard(
                            context,
                            title: 'Create Budget',
                            icon: Icons.account_balance_wallet_outlined,
                            color: const Color(0xFF3B82F6),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateBudgetPage(),
                                ),
                              );
                            },
                          ),
                          _quickActionCard(
                            context,
                            title: 'Transfer',
                            icon: Icons.swap_horiz_rounded,
                            color: const Color(0xFFF59E0B),
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TransferPage(),
                                ),
                              );
                              _loadData();
                            },
                          ),
                          _quickActionCard(
                            context,
                            title: 'Recurring',
                            icon: Icons.autorenew_rounded,
                            color: const Color(0xFF06B6D4),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RecurringListPage(),
                                ),
                              );
                            },
                          ),
                          _quickActionCard(
                            context,
                            title: 'My Account',
                            icon: Icons.account_balance_outlined,
                            color: const Color(0xFF6366F1),
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AccountsPage(),
                                ),
                              );
                              _loadData();
                            },
                          ),
                          _quickActionCard(
                            context,
                            title: 'Credit Card',
                            icon: Icons.credit_card,
                            color: const Color(0xFF8B5CF6),
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreditCardsPage(),
                                ),
                              );
                              _loadData();
                            },
                          ),
                          _quickActionCard(
                            context,
                            title: 'Lending & Loans',
                            icon: Icons.handshake_outlined,
                            color: const Color(0xFFEA580C),
                            onTap: () {
                              Navigator.pop(context);
                              _showLendingLoanChooser(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: _primaryActionCard(
                              title: 'Add Income',
                              subtitle: 'Salary, gifts, etc.',
                              icon: Icons.arrow_upward_rounded,
                              color: const Color(0xFF22C55E),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddTransactionPage(
                                      transactionType: 'income',
                                    ),
                                  ),
                                );
                                _loadData();
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _primaryActionCard(
                              title: 'Add Expense',
                              subtitle: 'Bills, shopping, etc.',
                              icon: Icons.arrow_downward_rounded,
                              color: const Color(0xFFEF4444),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddTransactionPage(
                                      transactionType: 'expense',
                                    ),
                                  ),
                                );
                                _loadData();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showLendingLoanChooser(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _Dark.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.north_east_rounded, color: Color(0xFFEA580C)),
                  title: const Text('Lendings', style: TextStyle(color: _Dark.textPrimary)),
                  subtitle: const Text('Money you lent to others', style: TextStyle(color: _Dark.textSecondary)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LendingsListPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined, color: Color(0xFFEA580C)),
                  title: const Text('Loans', style: TextStyle(color: _Dark.textPrimary)),
                  subtitle: const Text('Money you owe', style: TextStyle(color: _Dark.textSecondary)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansListPage()));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _quickActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B2430),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Dark.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _primaryActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Dark.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

