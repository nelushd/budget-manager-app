import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/category_icon.dart';
import '../../widgets/finance/calculator_keypad.dart';
import 'create_credit_card_page.dart';
import 'upcoming_payments_page.dart';

const _bg = Color(0xFF0B0F14);
const _cardBg = Color(0xFF141B24);
const _accent = Color(0xFF2DD4A7);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF9CA3AF);
const _divider = Color(0xFF232C38);
const _error = Color(0xFFEF4444);

class CreditCardDetailPage extends StatefulWidget {
  final AccountModel card;

  const CreditCardDetailPage({super.key, required this.card});

  @override
  State<CreditCardDetailPage> createState() => _CreditCardDetailPageState();
}

class _CreditCardDetailPageState extends State<CreditCardDetailPage> {
  late AccountModel _card;
  bool _isLoading = true;
  List<TransactionModel> _allTransactions = [];
  Map<String, CategoryModel> _categoriesById = {};
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final id = _card.id;
      final results = await Future.wait([
        if (id != null) FirestoreService.instance.getTransactionsByAccount(id) else Future.value(<TransactionModel>[]),
        FirestoreService.instance.getCategoriesByType('expense'),
        FirestoreService.instance.getCategoriesByType('income'),
      ]);
      if (!mounted) return;
      final categories = [...results[1] as List<CategoryModel>, ...results[2] as List<CategoryModel>];
      setState(() {
        _allTransactions = results[0] as List<TransactionModel>;
        _categoriesById = {
          for (final c in categories)
            if (c.id != null) c.id!: c,
        };
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading credit card detail: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<DateTime> get _recentMonths {
    final now = DateTime.now();
    return List.generate(12, (i) => DateTime(now.year, now.month - i, 1));
  }

  List<TransactionModel> get _monthTransactions {
    return _allTransactions.where((t) {
      if (t.date.isEmpty) return false;
      final date = DateTime.tryParse(t.date);
      return date != null && date.year == _selectedMonth.year && date.month == _selectedMonth.month;
    }).toList();
  }

  DateTime _dayInMonth(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  DateTime? get _nextDueDate {
    final dueDay = _card.dueDay;
    if (dueDay == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var candidate = _dayInMonth(now.year, now.month, dueDay);
    if (candidate.isBefore(today)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      candidate = _dayInMonth(nextMonth.year, nextMonth.month, dueDay);
    }
    return candidate;
  }

  String _fmt(double amount) => 'Rs ${NumberFormat('#,##0.00').format(amount)}';

  Future<void> _openMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined, color: _textPrimary),
                  title: const Text('Upcoming Payments', style: TextStyle(color: _textPrimary)),
                  onTap: () => Navigator.pop(sheetContext, 'upcoming'),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: _textPrimary),
                  title: const Text('Edit Card', style: TextStyle(color: _textPrimary)),
                  onTap: () => Navigator.pop(sheetContext, 'edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: _error),
                  title: const Text('Delete', style: TextStyle(color: _error)),
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'upcoming':
        Navigator.push(context, MaterialPageRoute(builder: (_) => UpcomingPaymentsPage(card: _card)));
        break;
      case 'edit':
        final updated = await showCreateCreditCardSheet(context, existing: _card);
        if (updated != null && mounted) setState(() => _card = updated);
        break;
      case 'delete':
        _confirmDelete();
        break;
    }
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Delete this card?', style: TextStyle(color: _textPrimary)),
        content: const Text('This cannot be undone.', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final id = _card.id;
              if (id != null) await FirestoreService.instance.deleteAccount(id);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
  }

  Future<void> _payNow() async {
    final controller = TextEditingController(
      text: _card.balance == _card.balance.roundToDouble()
          ? _card.balance.toStringAsFixed(0)
          : _card.balance.toString(),
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
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
              const Text('Pay Now', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFF1B2430), borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: controller,
                  readOnly: true,
                  showCursor: true,
                  onTap: () => showCalculatorKeypad(context, controller: controller, dark: true),
                  style: const TextStyle(color: _textPrimary),
                  decoration: const InputDecoration(
                    icon: Text('Rs', style: TextStyle(color: _textSecondary)),
                    hintText: 'Payment Amount',
                    hintStyle: TextStyle(color: _textSecondary),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final payment = double.tryParse(controller.text.trim()) ?? 0;
    if (payment <= 0) return;

    final updated = _card.copyWith(balance: (_card.balance - payment).clamp(0, double.infinity).toDouble());
    await FirestoreService.instance.updateAccount(updated);
    if (!mounted) return;
    setState(() => _card = updated);
  }

  @override
  Widget build(BuildContext context) {
    final limit = _card.creditLimit ?? 0;
    final available = _card.availableCredit ?? 0;
    final usedPct = limit > 0 ? (_card.balance / limit * 100).clamp(0, 100) : 0.0;
    final dueDate = _nextDueDate;
    final hasPaymentDue = _card.balance > 0 && dueDate != null;

    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  pinned: true,
                  elevation: 0,
                  foregroundColor: Colors.white,
                  expandedHeight: 300,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF115E59), Color(0xFF2DD4A7)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_card.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                          const Text('Credit Card', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 18),
                          const Text('Available', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            _fmt(available),
                            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: (usedPct / 100).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation(
                                usedPct >= 90 ? _error : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${usedPct.toStringAsFixed(0)}% used of ${_fmt(limit)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasPaymentDue
                                ? 'Due ${DateFormat('MMM d, yyyy').format(dueDate)}'
                                : 'No payment due',
                            style: TextStyle(
                              color: hasPaymentDue ? Colors.white : const Color(0xFFBBF7D0),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: _openMenu,
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transactions', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentMonths.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final month = _recentMonths[index];
                              final selected = month.year == _selectedMonth.year && month.month == _selectedMonth.month;
                              return ChoiceChip(
                                label: Text(DateFormat('MMM yyyy').format(month)),
                                selected: selected,
                                onSelected: (_) => setState(() => _selectedMonth = month),
                                selectedColor: _accent,
                                labelStyle: TextStyle(
                                  color: selected ? _bg : _textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                backgroundColor: _cardBg,
                                side: BorderSide.none,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Showing ${DateFormat('MMMM yyyy').format(_selectedMonth)} spendings',
                          style: const TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        if (_monthTransactions.isEmpty)
                          _emptyTransactions()
                        else
                          Container(
                            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                for (var i = 0; i < _monthTransactions.length; i++)
                                  Column(
                                    children: [
                                      _transactionTile(_monthTransactions[i]),
                                      if (i != _monthTransactions.length - 1)
                                        const Divider(height: 1, color: _divider),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _payNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _emptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: _textSecondary.withValues(alpha: 0.5), size: 36),
          const SizedBox(height: 10),
          const Text('No transactions for this period', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _transactionTile(TransactionModel transaction) {
    final category = _categoriesById[transaction.categoryId];
    final isInflow = transaction.type == 'income';
    final color = isInflow ? const Color(0xFF22C55E) : _error;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(getCategoryIcon(category?.iconName ?? 'category'), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category?.name ?? 'Uncategorized',
              style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Text(
            '${isInflow ? '+' : '-'} Rs ${NumberFormat('#,##0.00').format(transaction.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
