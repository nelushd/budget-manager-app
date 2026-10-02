import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/finance/calculator_keypad.dart';
import '../../widgets/finance/day_of_month_picker.dart';

const _dark = _CreditCardDark();

/// A short quick-pick of card networks, offered when creating a card so the
/// name doesn't have to be typed out by hand. Selecting one just fills the
/// (still-editable) name field — any other card name is one tap of typing
/// away, not blocked.
const List<String> kCardNetworks = ['Visa', 'Mastercard', 'Amex'];

class _CreditCardDark {
  const _CreditCardDark();
  Color get bg => const Color(0xFF141B24);
  Color get field => const Color(0xFF1B2430);
  Color get accent => const Color(0xFF2DD4A7);
  Color get textPrimary => Colors.white;
  Color get textSecondary => const Color(0xFF9CA3AF);
  Color get error => const Color(0xFFEF4444);
}

/// Opens the "Create Credit Card" / "Edit Card" sheet. Returns the
/// saved account, or null if dismissed without saving.
Future<AccountModel?> showCreateCreditCardSheet(
  BuildContext context, {
  AccountModel? existing,
}) {
  return showModalBottomSheet<AccountModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: _CreateCreditCardSheetBody(existing: existing),
        ),
      );
    },
  );
}

class _CreateCreditCardSheetBody extends StatefulWidget {
  final AccountModel? existing;

  const _CreateCreditCardSheetBody({this.existing});

  @override
  State<_CreateCreditCardSheetBody> createState() => _CreateCreditCardSheetBodyState();
}

class _CreateCreditCardSheetBodyState extends State<_CreateCreditCardSheetBody> {
  final nameController = TextEditingController();
  final creditLimitController = TextEditingController();
  final availableController = TextEditingController();
  final interestController = TextEditingController();
  final minPaymentController = TextEditingController();

  int? billingStartDay;
  int? dueDay;
  bool includeInAvailableBalance = true;
  bool isSaving = false;
  bool showValidation = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      nameController.text = existing.name;
      creditLimitController.text = existing.creditLimit != null
          ? _trimZeros(existing.creditLimit!)
          : '';
      final available = existing.availableCredit;
      availableController.text = available != null ? _trimZeros(available) : '';
      interestController.text = existing.interestRatePercent != null
          ? _trimZeros(existing.interestRatePercent!)
          : '';
      minPaymentController.text = existing.minimumPaymentPercent != null
          ? _trimZeros(existing.minimumPaymentPercent!)
          : '';
      billingStartDay = existing.billingStartDay;
      dueDay = existing.dueDay;
      includeInAvailableBalance = existing.isIncluded;
    }
  }

  String _trimZeros(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
  }

  double get _creditLimit => double.tryParse(creditLimitController.text.trim()) ?? 0;

  bool get _isValid =>
      nameController.text.trim().isNotEmpty &&
      _creditLimit > 0 &&
      billingStartDay != null &&
      dueDay != null;

  Future<void> _pickBillingStartDay() async {
    final picked = await showDayOfMonthPicker(
      context,
      title: 'Billing Start Date',
      initialDay: billingStartDay,
    );
    if (picked != null) setState(() => billingStartDay = picked);
  }

  Future<void> _pickDueDay() async {
    final picked = await showDayOfMonthPicker(
      context,
      title: 'Due Date',
      initialDay: dueDay,
    );
    if (picked != null) setState(() => dueDay = picked);
  }

  Future<void> _save() async {
    setState(() => showValidation = true);
    if (!_isValid || isSaving) return;

    setState(() => isSaving = true);

    final creditLimit = _creditLimit;
    final available = double.tryParse(availableController.text.trim());
    // "used" (the account's balance, for a credit card) is the limit minus
    // whatever the user says is still available — left blank, a new card
    // starts fully available (nothing used yet).
    final used = available != null ? (creditLimit - available).clamp(0, creditLimit) : 0.0;

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    final account = (widget.existing ?? AccountModel(
      userId: userId,
      name: '',
      balance: 0,
      type: 'credit_card',
      createdAt: now,
    )).copyWith(
      name: nameController.text.trim(),
      balance: used.toDouble(),
      type: 'credit_card',
      isIncluded: includeInAvailableBalance,
      creditLimit: creditLimit,
      billingStartDay: billingStartDay,
      dueDay: dueDay,
      interestRatePercent: double.tryParse(interestController.text.trim()),
      minimumPaymentPercent: double.tryParse(minPaymentController.text.trim()),
    );

    if (_isEditing) {
      await FirestoreService.instance.updateAccount(account);
    } else {
      final id = await FirestoreService.instance.addAccount(account);
      if (!mounted) return;
      Navigator.pop(context, account.copyWith(id: id));
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, account);
  }

  @override
  void dispose() {
    nameController.dispose();
    creditLimitController.dispose();
    availableController.dispose();
    interestController.dispose();
    minPaymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: _dark.bg,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF232C38), borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 4, height: 22, color: _dark.accent),
                          const SizedBox(width: 10),
                          Text(
                            _isEditing ? 'Edit Card' : 'Create Credit Card',
                            style: TextStyle(color: _dark.textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _networkChips(),
                      const SizedBox(height: 10),
                      _textField(
                        controller: nameController,
                        hint: 'Credit Card Name',
                        icon: Icons.label_outline,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(color: _dark.field, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Icon(Icons.currency_exchange, color: _dark.textSecondary, size: 20),
                            const SizedBox(width: 12),
                            Text('LKR — Sri Lankan Rupee', style: TextStyle(color: _dark.textPrimary)),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: _dark.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _amountField(
                        controller: creditLimitController,
                        hint: 'Credit Limit',
                        onChanged: (_) => setState(() {}),
                      ),
                      if (showValidation && _creditLimit <= 0) _errorText('Enter credit limit'),
                      const SizedBox(height: 14),
                      _amountField(controller: availableController, hint: 'Available Spending Amount (Optional)'),
                      const SizedBox(height: 6),
                      Text(
                        'Enter the amount you can currently spend with this card.',
                        style: TextStyle(color: _dark.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dateField(
                                  label: 'Billing Start Date',
                                  day: billingStartDay,
                                  onTap: _pickBillingStartDay,
                                ),
                                if (showValidation && billingStartDay == null)
                                  _errorText('Select billing start date'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dateField(label: 'Due Date', day: dueDay, onTap: _pickDueDay),
                                if (showValidation && dueDay == null) _errorText('Select due date'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _amountField(
                        controller: interestController,
                        hint: 'Interest Rate % (Optional)',
                        icon: Icons.percent,
                        prefix: null,
                      ),
                      const SizedBox(height: 14),
                      _amountField(
                        controller: minPaymentController,
                        hint: 'Minimum Payment % (Optional)',
                        icon: Icons.payments_outlined,
                        prefix: null,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _dark.field, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Include credit card balance in credit card available balance',
                                style: TextStyle(color: _dark.textPrimary, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Switch(
                              value: includeInAvailableBalance,
                              activeTrackColor: _dark.accent,
                              onChanged: (v) => setState(() => includeInAvailableBalance = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _dark.accent,
                                side: BorderSide(color: _dark.accent),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _dark.accent,
                                foregroundColor: const Color(0xFF0B0F14),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(isSaving ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Add Account')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _dark.field, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: _dark.textPrimary),
        decoration: InputDecoration(
          icon: Icon(icon, color: _dark.textSecondary, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: _dark.textSecondary),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    Object? prefix = 'Rs',
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _dark.field, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: controller,
        readOnly: prefix != null,
        showCursor: prefix != null,
        keyboardType: prefix == null ? const TextInputType.numberWithOptions(decimal: true) : null,
        onChanged: onChanged,
        onTap: prefix != null
            ? () => showCalculatorKeypad(context, controller: controller, dark: true).then((_) => setState(() {}))
            : null,
        style: TextStyle(color: _dark.textPrimary),
        decoration: InputDecoration(
          icon: icon != null
              ? Icon(icon, color: _dark.textSecondary, size: 20)
              : Text(prefix as String? ?? '', style: TextStyle(color: _dark.textSecondary)),
          hintText: hint,
          hintStyle: TextStyle(color: _dark.textSecondary),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _dateField({required String label, required int? day, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: _dark.field, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _dark.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    day == null ? 'Select date' : 'Day $day',
                    style: TextStyle(color: _dark.textPrimary),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, color: _dark.accent, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _networkChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final network in kCardNetworks)
          ChoiceChip(
            label: Text(network),
            selected: nameController.text == network,
            onSelected: (_) => setState(() => nameController.text = network),
            selectedColor: _dark.accent.withValues(alpha: 0.18),
            backgroundColor: _dark.field,
            labelStyle: TextStyle(
              color: nameController.text == network ? _dark.accent : _dark.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            side: BorderSide(
              color: nameController.text == network ? _dark.accent : Colors.transparent,
            ),
          ),
      ],
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: TextStyle(color: _dark.error, fontSize: 11)),
    );
  }
}
