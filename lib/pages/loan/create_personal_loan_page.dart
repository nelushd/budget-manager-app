import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/loan_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';

class CreatePersonalLoanPage extends StatefulWidget {
  final LoanModel? existing;

  const CreatePersonalLoanPage({super.key, this.existing});

  @override
  State<CreatePersonalLoanPage> createState() => _CreatePersonalLoanPageState();
}

class _CreatePersonalLoanPageState extends State<CreatePersonalLoanPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
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
      _totalController.text = _fmt(existing.totalAmount);
      _paidController.text = existing.paidAmount > 0 ? _fmt(existing.paidAmount) : '';
      if (existing.startDate.isNotEmpty) startDate = PeriodCalculator.parseDate(existing.startDate);
      if (existing.dueDate != null) dueDate = PeriodCalculator.parseDate(existing.dueDate!);
      _noteController.text = existing.note;
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
      final totalAmount = double.parse(_totalController.text.trim());
      final paidAmount = double.tryParse(_paidController.text.trim()) ?? 0;

      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: _nameController.text.trim(),
          totalAmount: totalAmount,
          startDate: PeriodCalculator.formatDate(startDate),
          dueDate: dueDate != null ? PeriodCalculator.formatDate(dueDate!) : null,
          note: _noteController.text.trim(),
        );
        await _firestoreService.updateLoan(updated);
      } else {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final loan = LoanModel(
          userId: userId,
          name: _nameController.text.trim(),
          loanType: 'personal',
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          startDate: PeriodCalculator.formatDate(startDate),
          dueDate: dueDate != null ? PeriodCalculator.formatDate(dueDate!) : null,
          accountId: selectedAccountId,
          note: _noteController.text.trim(),
          createdDate: DateTime.now().millisecondsSinceEpoch,
        );
        await _firestoreService.addLoan(loan);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error saving personal loan: $error');
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Personal Loan' : 'Create Personal Loan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                    decoration: InputDecoration(
                      hintText: 'e.g. Borrowed from Sam',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AmountField(label: 'Total Loan Amount', controller: _totalController, onChanged: (_) => setState(() {})),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: AmountField(label: 'Paid Amount', controller: _paidController)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Loan Start Date'),
                  _dateField(PeriodCalculator.formatDate(startDate), () => _pickDate(isStart: true)),
                  const SizedBox(height: 18),
                  const SectionLabel('Due Date (Optional)'),
                  _dateField(
                    dueDate != null ? PeriodCalculator.formatDate(dueDate!) : 'Choose a date',
                    () => _pickDate(isStart: false),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('When do you need to pay back this personal loan?', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
                  const SizedBox(height: 20),
                  const Text('Account Selection (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      "Please select an account if this is a new loan. If it's an old loan, don't select an account.",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedAccountId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    ),
                    hint: const Text('No wallet selected'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No wallet selected')),
                      ...accounts.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (value) => setState(() => selectedAccountId = value),
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Note (Optional)'),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    ),
                  ),
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

  Widget _dateField(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(children: [const Icon(Icons.event, color: Colors.grey), const SizedBox(width: 10), Text(label)]),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
