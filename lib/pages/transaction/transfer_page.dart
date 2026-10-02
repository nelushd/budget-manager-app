import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account_model.dart';
import '../../models/transfer_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/finance/calculator_keypad.dart';

/// Dark palette matching Home/Analytics/Accounts/Transactions.
class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF1B2430);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2E3A4A);
  static const Color error = Color(0xFFF87171);
}

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<AccountModel> _accounts = [];
  AccountModel? _fromAccount;
  AccountModel? _toAccount;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_refresh);
    _loadAccounts();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _firestoreService.getAccounts();
      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading accounts for transfer: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load accounts.', isError: true);
    }
  }

  Future<void> _pickAccount({required bool isFromAccount}) async {
    final excludedId =
        isFromAccount ? _toAccount?.id : _fromAccount?.id;

    final selectable =
        _accounts.where((account) => account.id != excludedId).toList();

    final picked = await showModalBottomSheet<AccountModel>(
      context: context,
      backgroundColor: _Dark.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFromAccount ? 'From Account' : 'To Account',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _Dark.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                if (selectable.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No other accounts available.',
                      style: TextStyle(color: _Dark.textSecondary),
                    ),
                  )
                else
                  ...selectable.map((account) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _Dark.accent.withValues(alpha: 0.14),
                        child: Icon(
                          account.type == 'credit_card'
                              ? Icons.credit_card
                              : Icons.account_balance_wallet_outlined,
                          color: _Dark.accent,
                        ),
                      ),
                      title: Text(
                        account.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: _Dark.textPrimary),
                      ),
                      subtitle: Text(
                        'Rs ${account.balance.toStringAsFixed(2)}',
                        style: const TextStyle(color: _Dark.textSecondary),
                      ),
                      onTap: () => Navigator.pop(sheetContext, account),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      if (isFromAccount) {
        _fromAccount = picked;
      } else {
        _toAccount = picked;
      }
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
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

    if (pickedDate == null || !mounted) return;

    setState(() => _selectedDate = pickedDate);
  }

  Future<void> _saveTransfer() async {
    if (_isSaving) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    final fee = double.tryParse(
          _feeController.text.trim().replaceAll(',', ''),
        ) ??
        0;

    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid amount.', isError: true);
      return;
    }

    if (_fromAccount?.id == null || _toAccount?.id == null) {
      _showMessage('Please select both accounts.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final transfer = TransferModel(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        fromAccountId: _fromAccount!.id!,
        toAccountId: _toAccount!.id!,
        amount: amount,
        fee: fee,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date:
            '${_selectedDate.year}-'
            '${_selectedDate.month.toString().padLeft(2, '0')}-'
            '${_selectedDate.day.toString().padLeft(2, '0')}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _firestoreService.addTransfer(transfer);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error saving transfer: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Unable to complete the transfer.', isError: true);
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
    final parsedAmount = double.tryParse(
          _amountController.text.trim().replaceAll(',', ''),
        ) ??
        0;

    final canSave = parsedAmount > 0 &&
        _fromAccount != null &&
        _toAccount != null &&
        _fromAccount!.id != _toAccount!.id &&
        !_isSaving;

    return Scaffold(
      backgroundColor: _Dark.bg,
      appBar: AppBar(
        title: const Text(
          'Transfer Between Accounts',
          style: TextStyle(fontWeight: FontWeight.w800, color: _Dark.textPrimary),
        ),
        backgroundColor: _Dark.bg,
        foregroundColor: _Dark.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Dark.accent))
          : SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _Dark.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _Dark.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        _accountPickerRow(
                          label: 'FROM ACCOUNT',
                          account: _fromAccount,
                          onTap: () => _pickAccount(isFromAccount: true),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: _Dark.accent.withValues(alpha: 0.14),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: _Dark.accent,
                              size: 18,
                            ),
                          ),
                        ),
                        _accountPickerRow(
                          label: 'TO ACCOUNT',
                          account: _toAccount,
                          onTap: () => _pickAccount(isFromAccount: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      color: _Dark.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _Dark.divider),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'AMOUNT',
                          style: TextStyle(
                            color: _Dark.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Rs ',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _Dark.textPrimary,
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
                                  currency: 'Rs',
                                  dark: true,
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: _Dark.textPrimary,
                                ),
                                cursorColor: _Dark.accent,
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: const TextStyle(
                                    color: _Dark.textSecondary,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                  ),
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
                  _inputLabel('Transfer Fee (Optional)'),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _feeController,
                    hintText: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _inputLabel('Date'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _Dark.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _Dark.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: _Dark.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedDate.year}-'
                            '${_selectedDate.month.toString().padLeft(2, '0')}-'
                            '${_selectedDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 14, color: _Dark.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _inputLabel('Note (Optional)'),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _noteController,
                    hintText: 'Add a note',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: canSave ? _saveTransfer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Dark.accent,
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
                              'Transfer Transactions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: _Dark.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _accountPickerRow({
    required String label,
    required AccountModel? account,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _Dark.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              account?.type == 'credit_card'
                  ? Icons.credit_card
                  : Icons.account_balance_wallet_outlined,
              color: _Dark.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _Dark.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  account?.name ?? 'Select account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: account == null ? _Dark.textSecondary : _Dark.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _Dark.textSecondary),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _Dark.textPrimary),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: _Dark.textPrimary),
      cursorColor: _Dark.accent,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _Dark.textSecondary),
        filled: true,
        fillColor: _Dark.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Dark.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Dark.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Dark.accent, width: 1.5),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.removeListener(_refresh);
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
