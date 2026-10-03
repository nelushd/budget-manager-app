import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/lending_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../../widgets/finance/dark_finance_widgets.dart';

class CreateLendingPage extends StatefulWidget {
  final LendingModel? existing;

  const CreateLendingPage({super.key, this.existing});

  @override
  State<CreateLendingPage> createState() => _CreateLendingPageState();
}

class _CreateLendingPageState extends State<CreateLendingPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _receivedController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  DateTime startDate = DateTime.now();
  DateTime? dueDate;
  List<AccountModel> accounts = [];
  String? selectedAccountId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _totalController.text = existing.totalAmount == existing.totalAmount.roundToDouble()
          ? existing.totalAmount.toStringAsFixed(0)
          : existing.totalAmount.toString();
      _receivedController.text = existing.receivedAmount > 0
          ? (existing.receivedAmount == existing.receivedAmount.roundToDouble()
              ? existing.receivedAmount.toStringAsFixed(0)
              : existing.receivedAmount.toString())
          : '';
      _noteController.text = existing.note;
      if (existing.startDate.isNotEmpty) startDate = PeriodCalculator.parseDate(existing.startDate);
      if (existing.dueDate != null) dueDate = PeriodCalculator.parseDate(existing.dueDate!);
      selectedAccountId = existing.accountId;
    }

    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final loaded = await _firestoreService.getAccounts();
      if (!mounted) return;
      setState(() {
        accounts = loaded;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading accounts for lending: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : (dueDate ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        startDate = picked;
      } else {
        dueDate = picked;
      }
    });
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (double.tryParse(_totalController.text.trim()) ?? 0) > 0;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => isSaving = true);

    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: _nameController.text.trim(),
          totalAmount: double.parse(_totalController.text.trim()),
          receivedAmount: double.tryParse(_receivedController.text.trim()) ?? 0,
          startDate: PeriodCalculator.formatDate(startDate),
          dueDate: dueDate != null ? PeriodCalculator.formatDate(dueDate!) : null,
          note: _noteController.text.trim(),
        );
        await _firestoreService.updateLending(updated);
      } else {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final lending = LendingModel(
          userId: userId,
          name: _nameController.text.trim(),
          totalAmount: double.parse(_totalController.text.trim()),
          receivedAmount: double.tryParse(_receivedController.text.trim()) ?? 0,
          startDate: PeriodCalculator.formatDate(startDate),
          dueDate: dueDate != null ? PeriodCalculator.formatDate(dueDate!) : null,
          accountId: selectedAccountId,
          note: _noteController.text.trim(),
          createdDate: DateTime.now().millisecondsSinceEpoch,
        );
        await _firestoreService.addLending(lending);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error creating lending: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create the lending.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Lending' : 'Create Lending'),
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
                  const SectionLabel('Lending Name'),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: FinanceDark.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Loan to John',
                      filled: true,
                      fillColor: FinanceDark.card,
                      hintStyle: const TextStyle(color: FinanceDark.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FinanceDark.divider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AmountField(
                          label: 'Total Lending Amount',
                          controller: _totalController,
                          dark: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AmountField(label: 'Previously Received', controller: _receivedController, dark: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Lending Start Date'),
                  _dateField(PeriodCalculator.formatDate(startDate), () => _pickDate(isStart: true)),
                  const SizedBox(height: 18),
                  const SectionLabel('Due Date (Optional)'),
                  _dateField(
                    dueDate != null ? PeriodCalculator.formatDate(dueDate!) : 'Choose a date',
                    () => _pickDate(isStart: false),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'When do you expect to receive back this lending?',
                      style: const TextStyle(fontSize: 11, color: FinanceDark.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Select Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: FinanceDark.textPrimary)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Select the account used for this lending.',
                      style: const TextStyle(fontSize: 12, color: FinanceDark.textSecondary),
                    ),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedAccountId,
                    style: const TextStyle(color: FinanceDark.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: FinanceDark.card,
                      hintStyle: const TextStyle(color: FinanceDark.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FinanceDark.divider),
                      ),
                    ),
                    hint: const Text('Select Account'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No account selected')),
                      ...accounts.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (value) => setState(() => selectedAccountId = value),
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Note (Optional)'),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: const TextStyle(color: FinanceDark.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: FinanceDark.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FinanceDark.divider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  PrimaryActionButton(
                    label: isSaving ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Create Lending'),
                    onPressed: isSaving || !_canSave ? null : _save,
                  ),
                ],
              ),
            ),
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
        child: Row(
          children: [
            const Icon(Icons.event, color: FinanceDark.textSecondary),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: FinanceDark.textPrimary)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    _receivedController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
