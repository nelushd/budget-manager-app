import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/loan_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../../widgets/finance/dark_finance_widgets.dart';

class CreateBankLoanPage extends StatefulWidget {
  final LoanModel? existing;

  const CreateBankLoanPage({super.key, this.existing});

  @override
  State<CreateBankLoanPage> createState() => _CreateBankLoanPageState();
}

class _CreateBankLoanPageState extends State<CreateBankLoanPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _termController = TextEditingController();
  final TextEditingController _installmentController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  DateTime startDate = DateTime.now();
  int monthlyPaymentDay = 1;
  List<AccountModel> accounts = [];
  String? selectedAccountId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _totalController.text = _fmt(existing.totalAmount);
      if (existing.interestRate != null) _interestController.text = _fmt(existing.interestRate!);
      if (existing.termMonths != null) _termController.text = '${existing.termMonths}';
      if (existing.customInstallmentAmount != null) {
        _installmentController.text = _fmt(existing.customInstallmentAmount!);
      }
      if (existing.startDate.isNotEmpty) startDate = PeriodCalculator.parseDate(existing.startDate);
      monthlyPaymentDay = existing.monthlyPaymentDay ?? 1;
    }

    _loadAccounts();
  }

  String _fmt(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

  Future<void> _loadAccounts() async {
    try {
      final loaded = await _firestoreService.getAccounts();
      if (!mounted) return;
      setState(() {
        accounts = loaded;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading accounts for loan: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => startDate = picked);
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (double.tryParse(_totalController.text.trim()) ?? 0) > 0;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => isSaving = true);

    try {
      final totalAmount = double.parse(_totalController.text.trim());
      final interestRate = double.tryParse(_interestController.text.trim());
      final termMonths = int.tryParse(_termController.text.trim());
      final customInstallment = double.tryParse(_installmentController.text.trim());
      final paidAmount = double.tryParse(_paidController.text.trim()) ?? 0;

      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: _nameController.text.trim(),
          totalAmount: totalAmount,
          startDate: PeriodCalculator.formatDate(startDate),
          interestRate: interestRate,
          termMonths: termMonths,
          monthlyPaymentDay: monthlyPaymentDay,
          customInstallmentAmount: customInstallment,
        );
        await _firestoreService.updateLoan(updated);
      } else {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final nextDue = DateTime(startDate.year, startDate.month, monthlyPaymentDay);
        final firstDue = nextDue.isBefore(startDate)
            ? DateTime(startDate.year, startDate.month + 1, monthlyPaymentDay)
            : nextDue;

        final loan = LoanModel(
          userId: userId,
          name: _nameController.text.trim(),
          loanType: 'bank',
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          startDate: PeriodCalculator.formatDate(startDate),
          interestRate: interestRate,
          termMonths: termMonths,
          monthlyPaymentDay: monthlyPaymentDay,
          customInstallmentAmount: customInstallment,
          accountId: selectedAccountId,
          nextDueDate: PeriodCalculator.formatDate(firstDue),
          createdDate: DateTime.now().millisecondsSinceEpoch,
        );
        await _firestoreService.addLoan(loan);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error saving bank loan: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this loan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Bank Loan' : 'Create Bank Loan'),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Loan Name'),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: FinanceDark.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Home Loan',
                      filled: true,
                      fillColor: FinanceDark.card,
                      hintStyle: const TextStyle(color: FinanceDark.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinanceDark.divider)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AmountField(label: 'Total Loan Amount', controller: _totalController, dark: true, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 18),
                  const SectionLabel('Loan Start Date'),
                  _dateField(PeriodCalculator.formatDate(startDate), _pickStartDate),
                  const SizedBox(height: 20),
                  const Text('Account Selection (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Select the account where this loan amount will be received.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedAccountId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: FinanceDark.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinanceDark.divider)),
                    ),
                    hint: const Text('No wallet selected'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No wallet selected')),
                      ...accounts.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (value) => setState(() => selectedAccountId = value),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _plainField('Interest Rate (%)', _interestController, TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _plainField('Loan Term (Months)', _termController, TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Loan Monthly Payment Day'),
                  DropdownButtonFormField<int>(
                    initialValue: monthlyPaymentDay,
                    style: const TextStyle(color: FinanceDark.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: FinanceDark.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinanceDark.divider)),
                    ),
                    items: List.generate(31, (i) => i + 1)
                        .map((day) => DropdownMenuItem(value: day, child: Text('$day')))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => monthlyPaymentDay = value);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: const Text('This will be used as the payment day for each month.', style: TextStyle(fontSize: 11, color: FinanceDark.textSecondary)),
                  ),
                  const SizedBox(height: 18),
                  AmountField(label: 'Custom Installment Amount (Optional)', controller: _installmentController, dark: true),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: const Text('Leave empty to use calculated monthly payment', style: TextStyle(fontSize: 11, color: FinanceDark.textSecondary)),
                  ),
                  const SizedBox(height: 18),
                  if (!_isEditing) ...[
                    AmountField(label: 'Add Paid Amount (Optional)', controller: _paidController, dark: true),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 10),
                  PrimaryActionButton(
                    label: isSaving ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Create Loan'),
                    onPressed: isSaving || !_canSave ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _plainField(String label, TextEditingController controller, TextInputType keyboardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FinanceDark.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: FinanceDark.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinanceDark.divider)),
          ),
        ),
      ],
    );
  }

  Widget _dateField(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FinanceDark.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FinanceDark.divider),
        ),
        child: Row(children: [const Icon(Icons.event, color: FinanceDark.textSecondary), const SizedBox(width: 10), Text(label, style: const TextStyle(color: FinanceDark.textPrimary))]),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    _interestController.dispose();
    _termController.dispose();
    _installmentController.dispose();
    _paidController.dispose();
    super.dispose();
  }
}
