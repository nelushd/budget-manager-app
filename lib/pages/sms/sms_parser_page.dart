import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../services/sms_parser_service.dart';
import '../../utils/category_icon.dart';
import '../../widgets/finance/calculator_keypad.dart';

/// Dark palette matching Home/Analytics/Accounts/Transactions/Transfer.
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

/// Paste-a-bank-SMS entry point. Parses amount/date/time/type from the
/// pasted text, then lets the user review and edit every field
/// (category and account are never auto-filled — always picked here)
/// before saving directly as a real transaction.
class SmsParserPage extends StatefulWidget {
  const SmsParserPage({super.key});

  @override
  State<SmsParserPage> createState() => _SmsParserPageState();
}

class _SmsParserPageState extends State<SmsParserPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  final TextEditingController _smsController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _hasParsed = false;
  String _selectedType = 'expense'; // income | expense
  String _currency = 'LKR';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<AccountModel> _accounts = [];
  List<CategoryModel> _categories = [];
  AccountModel? _selectedAccount;
  CategoryModel? _selectedCategory;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_refresh);
    _loadAccountsAndCategories();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAccountsAndCategories() async {
    try {
      final accounts = await _firestoreService.getAccounts();
      final categories =
          await _firestoreService.getCategoriesByType(_selectedType);

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _categories = categories;
        _selectedAccount = accounts.isEmpty
            ? null
            : accounts.firstWhere(
                (a) => a.isDefault,
                orElse: () => accounts.first,
              );
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading accounts/categories: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadCategoriesForType() async {
    try {
      final categories =
          await _firestoreService.getCategoriesByType(_selectedType);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategory = categories.isNotEmpty ? categories.first : null;
      });
    } catch (error, stackTrace) {
      debugPrint('Error reloading categories: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null || !mounted) return;
    setState(() => _smsController.text = data!.text!);
  }

  void _parse() {
    final text = _smsController.text.trim();
    if (text.isEmpty) return;

    final parsed = parseSmsText(text);

    if (parsed == null) {
      _showMessage("Couldn't detect a transaction in this text.", isError: true);
      return;
    }

    setState(() {
      _hasParsed = true;
      _amountController.text = parsed.amount.toStringAsFixed(2);
      _currency = parsed.currency;
      _selectedDate = parsed.date ?? DateTime.now();
      _selectedTime = parsed.time ?? TimeOfDay.now();
      _selectedType = parsed.type == 'credit' ? 'income' : 'expense';
    });

    _reloadCategoriesForType();
  }

  void _clear() {
    setState(() {
      _smsController.clear();
      _hasParsed = false;
      _amountController.clear();
    });
  }

  Future<void> _changeType(String type) async {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    await _reloadCategoriesForType();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _Dark.accent,
              onPrimary: _Dark.bg,
              surface: _Dark.card,
              onSurface: _Dark.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _Dark.bg),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _Dark.accent,
              onPrimary: _Dark.bg,
              surface: _Dark.card,
              onSurface: _Dark.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _Dark.bg),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid amount.', isError: true);
      return;
    }

    if (_selectedCategory?.id == null) {
      _showMessage('Please select a category.', isError: true);
      return;
    }

    if (_selectedAccount?.id == null) {
      _showMessage('Please select an account.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final transaction = TransactionModel(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        amount: amount,
        type: _selectedType,
        categoryId: _selectedCategory!.id!,
        accountId: _selectedAccount!.id!,
        receiptPath: null,
        date:
            '${_selectedDate.year}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        time:
            '${_selectedTime.hour.toString().padLeft(2, '0')}:'
            '${_selectedTime.minute.toString().padLeft(2, '0')}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _firestoreService.addTransaction(transaction);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error saving SMS transaction: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Unable to save the transaction.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _Dark.error : _Dark.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool isIncome = _selectedType == 'income';
    final Color accentColor = isIncome ? _Dark.success : _Dark.error;

    final double parsedAmount = double.tryParse(
          _amountController.text.trim().replaceAll(',', ''),
        ) ??
        0;

    final bool canSave = parsedAmount > 0 &&
        _selectedCategory != null &&
        _selectedAccount != null &&
        !_isSaving;

    return Scaffold(
      backgroundColor: _Dark.bg,
      appBar: AppBar(
        backgroundColor: _Dark.bg,
        foregroundColor: _Dark.textPrimary,
        elevation: 0,
        title: const Text(
          'SMS Parser',
          style: TextStyle(
            color: _Dark.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Dark.accent))
          : SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Paste box
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      color: _Dark.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _Dark.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _smsController,
                                maxLines: 6,
                                minLines: 4,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: _Dark.textPrimary),
                                cursorColor: _Dark.accent,
                                decoration: InputDecoration(
                                  hintText: 'Paste your bank SMS here...',
                                  hintStyle: const TextStyle(color: _Dark.textSecondary),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Paste from clipboard',
                              icon: const Icon(Icons.content_paste, color: _Dark.textSecondary),
                              onPressed: _pasteFromClipboard,
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_smsController.text.length} chars',
                            style: const TextStyle(fontSize: 11, color: _Dark.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _smsController.text.trim().isEmpty
                                      ? null
                                      : _parse,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _Dark.accent,
                                    foregroundColor: _Dark.bg,
                                    disabledBackgroundColor: _Dark.divider,
                                    disabledForegroundColor: _Dark.textSecondary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  icon: const Icon(Icons.document_scanner_outlined, size: 19),
                                  label: const Text(
                                    'Parse',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _clear,
                              style: TextButton.styleFrom(foregroundColor: _Dark.textSecondary),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (!_hasParsed) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.sms_outlined, color: _Dark.divider, size: 48),
                          const SizedBox(height: 14),
                          const Text(
                            'Your parsed result will appear here',
                            style: TextStyle(color: _Dark.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports most Sri Lankan bank SMS formats',
                            style: TextStyle(color: _Dark.textSecondary.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 22),

                    // Income / Expense toggle — editable in case the
                    // credit/debit detection guessed wrong.
                    Container(
                      height: 54,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _Dark.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _Dark.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _typeButton(
                              title: 'Income',
                              icon: Icons.arrow_downward_rounded,
                              type: 'income',
                              selectedColor: _Dark.success,
                            ),
                          ),
                          Expanded(
                            child: _typeButton(
                              title: 'Expense',
                              icon: Icons.arrow_upward_rounded,
                              type: 'expense',
                              selectedColor: _Dark.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount — tap to edit via the calculator keypad.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'AMOUNT',
                            style: TextStyle(
                              color: accentColor.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_currency ',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Flexible(
                                child: TextField(
                                  controller: _amountController,
                                  readOnly: true,
                                  showCursor: true,
                                  onTap: () => showCalculatorKeypad(
                                    context,
                                    controller: _amountController,
                                    currency: _currency,
                                    dark: true,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date and Time — editable pickers.
                    Row(
                      children: [
                        Expanded(
                          child: _dateTimeBox(
                            title: 'Date',
                            icon: Icons.calendar_today,
                            text:
                                '${_selectedDate.year}-'
                                '${_selectedDate.month.toString().padLeft(2, '0')}-'
                                '${_selectedDate.day.toString().padLeft(2, '0')}',
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dateTimeBox(
                            title: 'Time',
                            icon: Icons.access_time,
                            text: _selectedTime.format(context),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Category
                    const Text(
                      'Category',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _Dark.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    if (_categories.isEmpty)
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _Dark.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _Dark.divider),
                        ),
                        child: Text(
                          'No $_selectedType categories',
                          style: const TextStyle(color: _Dark.textSecondary),
                        ),
                      )
                    else
                      SizedBox(
                        height: 84,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final bool isSelected = _selectedCategory?.id == category.id;

                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategory = category),
                              child: Container(
                                width: 82,
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accentColor.withValues(alpha: 0.14)
                                      : _Dark.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? accentColor : _Dark.divider,
                                    width: isSelected ? 1.6 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      getCategoryIcon(category.iconName),
                                      size: 22,
                                      color: isSelected ? accentColor : _Dark.textPrimary,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      category.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? accentColor : _Dark.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Account
                    const Text(
                      'Select Account',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _Dark.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    if (_accounts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _Dark.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _Dark.divider),
                        ),
                        child: const Text('No accounts are available.', style: TextStyle(color: _Dark.textSecondary)),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _accounts.map((account) {
                            final bool isSelected = _selectedAccount?.id == account.id;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedAccount = account),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accentColor.withValues(alpha: 0.14)
                                      : _Dark.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? accentColor : _Dark.divider,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? accentColor : _Dark.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rs ${account.balance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected ? accentColor : _Dark.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canSave ? _save : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: _Dark.bg,
                          disabledBackgroundColor: _Dark.card,
                          disabledForegroundColor: _Dark.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _Dark.bg,
                                ),
                              )
                            : const Text(
                                'Save Transaction',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _typeButton({
    required String title,
    required IconData icon,
    required String type,
    required Color selectedColor,
  }) {
    final bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => _changeType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? _Dark.bg : _Dark.textSecondary),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? _Dark.bg : _Dark.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTimeBox({
    required String title,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputLabel(title),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _Dark.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Dark.divider),
            ),
            child: Row(
              children: [
                Icon(icon, color: _Dark.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14, color: _Dark.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _Dark.textPrimary));
  }

  @override
  void dispose() {
    _amountController.removeListener(_refresh);
    _smsController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
