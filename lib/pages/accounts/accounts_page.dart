import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/account_model.dart';
import '../../services/firestore_service.dart';
import 'create_account_page.dart';

/// Dark palette matching Home/Analytics/Budget/Credit Cards — this page
/// used to be the one plain-white holdout in the account flow, which made
/// every card in it look flat next to the rest of the app.
class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF1B2430);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2E3A4A);
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);
}

class AccountsPage extends StatefulWidget {
  final bool openCreate;

  const AccountsPage({super.key, this.openCreate = false});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<AccountModel> accounts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAccounts();
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openCreatePage();
      });
    }
  }

  Future<void> loadAccounts() async {
    final loaded = await FirestoreService.instance.getAccounts();
    if (!mounted) return;
    setState(() {
      accounts = loaded;
      isLoading = false;
    });
  }

  Future<void> openCreatePage() async {
    await showCreateAccountSheet(context);
    loadAccounts();
  }

  String _formatAmount(double amount) {
    return 'Rs ${NumberFormat('#,##0.00').format(amount)}';
  }

  /// Credit cards get their own dedicated section (via the Home quick
  /// action) and their own richer detail page — they don't belong in the
  /// plain cash/bank list here.
  List<AccountModel> get _visibleAccounts =>
      accounts.where((a) => a.type != 'credit_card').toList();

  double get _cashAndBankTotal =>
      _visibleAccounts.fold(0.0, (sum, a) => sum + a.balance);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Dark.bg,
      appBar: AppBar(
        backgroundColor: _Dark.bg,
        foregroundColor: _Dark.textPrimary,
        elevation: 0,
        title: const Text(
          'My Accounts',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'accountsFab',
        backgroundColor: _Dark.accent,
        onPressed: openCreatePage,
        child: const Icon(Icons.add, color: _Dark.bg),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _Dark.accent))
          : _visibleAccounts.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: loadAccounts,
                  color: _Dark.accent,
                  backgroundColor: _Dark.card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 20),
                      for (final account in _visibleAccounts) ...[
                        _accountCard(account),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _Dark.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: _Dark.accent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'No accounts yet',
              style: TextStyle(color: _Dark.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a cash or bank account to start tracking your money.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _Dark.textSecondary),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: openCreatePage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Dark.accent,
                foregroundColor: _Dark.bg,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Dark.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Dark.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _Dark.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, color: _Dark.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_visibleAccounts.length} Account${_visibleAccounts.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: _Dark.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total balance ${_formatAmount(_cashAndBankTotal)}',
                  style: const TextStyle(color: _Dark.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(AccountModel account) {
    final isNegative = account.balance < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Dark.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Dark.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _Dark.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  account.type == 'bank' ? Icons.account_balance : Icons.payments_outlined,
                  color: _Dark.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  account.name,
                  style: const TextStyle(color: _Dark.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatAmount(account.balance),
            style: TextStyle(
              color: isNegative ? _Dark.error : _Dark.success,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
