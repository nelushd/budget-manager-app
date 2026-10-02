import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/sms_draft_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../services/sms_draft_store.dart';
import '../../services/sms_parser_service.dart';
import '../../utils/category_icon.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../categories/create_category_page.dart';

class SmsDraftsPage extends StatefulWidget {
  const SmsDraftsPage({super.key});

  @override
  State<SmsDraftsPage> createState() => _SmsDraftsPageState();
}

class _SmsDraftsPageState extends State<SmsDraftsPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final SmsDraftStore _draftStore = SmsDraftStore.instance;

  bool isLoading = true;
  List<SmsDraft> drafts = [];
  List<CategoryModel> incomeCategories = [];
  List<CategoryModel> expenseCategories = [];
  List<AccountModel> accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loadedDrafts = await _draftStore.getDrafts();
      final loadedIncome = await _firestoreService.getCategoriesByType('income');
      final loadedExpense = await _firestoreService.getCategoriesByType('expense');
      final loadedAccounts = await _firestoreService.getAccounts();

      if (!mounted) return;
      setState(() {
        drafts = loadedDrafts;
        incomeCategories = loadedIncome;
        expenseCategories = loadedExpense;
        accounts = loadedAccounts;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading SMS drafts: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _addFromText() async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add from SMS text'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Paste the bank SMS here'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Parse'),
            ),
          ],
        );
      },
    );

    if (text == null || text.isEmpty) return;

    final parsed = parseSmsText(text);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't detect a transaction in this text.")),
      );
      return;
    }

    final now = DateTime.now();
    await _draftStore.addDraft(
      SmsDraft(
        id: 'manual_${now.millisecondsSinceEpoch}',
        rawMessage: text,
        sender: 'Manual entry',
        type: parsed.type,
        amount: parsed.amount,
        detectedDate: PeriodCalculator.formatDate(now),
        createdAt: now.millisecondsSinceEpoch,
      ),
    );
    _load();
  }

  Future<void> _discard(SmsDraft draft) async {
    await _draftStore.removeDraft(draft.id);
    _load();
  }

  Future<void> _verify(SmsDraft draft, CategoryModel category, AccountModel account, double amount) async {
    final now = DateTime.now();
    final transaction = TransactionModel(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      amount: amount,
      type: draft.type == 'credit' ? 'income' : 'expense',
      categoryId: category.id!,
      accountId: account.id!,
      note: 'From SMS · ${draft.sender}',
      receiptPath: null,
      date: draft.detectedDate.isNotEmpty ? draft.detectedDate : PeriodCalculator.formatDate(now),
      time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now.millisecondsSinceEpoch,
    );

    await _firestoreService.addTransaction(transaction);
    await _draftStore.removeDraft(draft.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved.')));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SMS Drafts', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Add from SMS text',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _addFromText,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (drafts.isEmpty)
                    FinanceEmptyState(
                      icon: Icons.mark_email_read_outlined,
                      title: 'No pending SMS drafts',
                      description: 'Pasted bank SMS will show up here for you to verify.',
                      actionLabel: 'Add from SMS text',
                      onAction: _addFromText,
                    )
                  else
                    ...drafts.map((draft) => _DraftCard(
                          key: ValueKey(draft.id),
                          draft: draft,
                          incomeCategories: incomeCategories,
                          expenseCategories: expenseCategories,
                          accounts: accounts,
                          onDiscard: () => _discard(draft),
                          onVerify: (category, account, amount) => _verify(draft, category, account, amount),
                          onCreateCategory: () async {
                            final created = await Navigator.push<CategoryModel>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateCategoryPage(
                                  transactionType: draft.type == 'credit' ? 'income' : 'expense',
                                ),
                              ),
                            );
                            if (created != null) _load();
                          },
                        )),
                ],
              ),
            ),
    );
  }
}

class _DraftCard extends StatefulWidget {
  final SmsDraft draft;
  final List<CategoryModel> incomeCategories;
  final List<CategoryModel> expenseCategories;
  final List<AccountModel> accounts;
  final VoidCallback onDiscard;
  final void Function(CategoryModel category, AccountModel account, double amount) onVerify;
  final VoidCallback onCreateCategory;

  const _DraftCard({
    super.key,
    required this.draft,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.accounts,
    required this.onDiscard,
    required this.onVerify,
    required this.onCreateCategory,
  });

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  late final TextEditingController _amountController;
  CategoryModel? selectedCategory;
  AccountModel? selectedAccount;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.draft.amount.toStringAsFixed(2));
    final categories = widget.draft.type == 'credit' ? widget.incomeCategories : widget.expenseCategories;
    selectedCategory = categories.isNotEmpty ? categories.first : null;
    selectedAccount = widget.accounts.isNotEmpty ? widget.accounts.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final isCredit = draft.type == 'credit';
    final categories = isCredit ? widget.incomeCategories : widget.expenseCategories;
    final canSave = selectedCategory != null && selectedAccount != null &&
        (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(
                  label: isCredit ? 'Credit' : 'Debit',
                  color: isCredit ? AppColors.secondary : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(draft.sender, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                Text(draft.detectedDate, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              draft.rawMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            AmountField(label: 'Amount', controller: _amountController, onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            if (categories.isEmpty)
              TextButton.icon(
                onPressed: widget.onCreateCategory,
                icon: const Icon(Icons.add, size: 16),
                label: Text('Create ${isCredit ? 'income' : 'expense'} category'),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: categories.map((c) {
                  final selected = selectedCategory?.id == c.id;
                  return ChoiceChip(
                    avatar: Icon(getCategoryIcon(c.iconName), size: 14, color: selected ? Colors.white : Colors.grey[700]),
                    label: Text(c.name, style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    onSelected: (_) => setState(() => selectedCategory = c),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                    backgroundColor: Colors.grey[100],
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            if (widget.accounts.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.accounts.map((a) {
                  final selected = selectedAccount?.id == a.id;
                  return ChoiceChip(
                    label: Text(a.name, style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    onSelected: (_) => setState(() => selectedAccount = a),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                    backgroundColor: Colors.grey[100],
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(onPressed: widget.onDiscard, child: const Text('Discard')),
                ),
                Expanded(
                  flex: 2,
                  child: PrimaryActionButton(
                    label: 'Verify & Save',
                    onPressed: canSave
                        ? () => widget.onVerify(
                              selectedCategory!,
                              selectedAccount!,
                              double.parse(_amountController.text.trim()),
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
