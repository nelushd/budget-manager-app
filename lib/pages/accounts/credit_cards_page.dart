import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/account_model.dart';
import '../../services/firestore_service.dart';
import 'create_credit_card_page.dart';
import 'credit_card_detail_page.dart';

const _bg = Color(0xFF0B0F14);
const _accent = Color(0xFF2DD4A7);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF9CA3AF);

class CreditCardsPage extends StatefulWidget {
  const CreditCardsPage({super.key});

  @override
  State<CreditCardsPage> createState() => _CreditCardsPageState();
}

class _CreditCardsPageState extends State<CreditCardsPage> {
  List<AccountModel> cards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    final accounts = await FirestoreService.instance.getAccounts();
    if (!mounted) return;
    setState(() {
      cards = accounts.where((a) => a.type == 'credit_card').toList();
      isLoading = false;
    });
  }

  Future<void> openCreatePage() async {
    await showCreateCreditCardSheet(context);
    loadCards();
  }

  Future<void> _openDetail(AccountModel card) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreditCardDetailPage(card: card)),
    );
    loadCards();
  }

  String _formatAmount(double amount) {
    return 'Rs ${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text(
          'Credit Cards',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: cards.isEmpty
          ? null
          : FloatingActionButton(
              heroTag: 'creditCardsFab',
              backgroundColor: _accent,
              onPressed: openCreatePage,
              child: const Icon(Icons.add, color: _bg),
            ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : cards.isEmpty
              ? _emptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    for (final card in cards) ...[
                      _cardTile(card),
                      const SizedBox(height: 14),
                    ],
                  ],
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
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: const Icon(Icons.credit_card, color: _accent, size: 40),
            ),
            const SizedBox(height: 22),
            const Text(
              'No credit cards yet',
              style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first credit card to start tracking your spending',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: openCreatePage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _bg,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Credit Card', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTile(AccountModel card) {
    final limit = card.creditLimit ?? 0;
    final available = card.availableCredit ?? 0;
    final usedPct = limit > 0 ? (card.balance / limit * 100).clamp(0, 100) : 0.0;

    return GestureDetector(
      onTap: () => _openDetail(card),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF115E59), Color(0xFF2DD4A7)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const Icon(Icons.credit_card, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Credit Card', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Available', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              _formatAmount(available),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (usedPct / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(
                  usedPct >= 90 ? const Color(0xFFEF4444) : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${usedPct.toStringAsFixed(0)}% used of ${_formatAmount(limit)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
