import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/recurring_expense_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/category_icon.dart';
import '../../utils/frequency.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../categories/categories_page.dart';
import '../categories/create_category_page.dart';

/// Frequencies selectable here — daily/bi-weekly are still supported by the
/// data model (an older expense could still have one), just not offered
/// when creating or editing.
const List<String> _selectableFrequencies = ['weekly', 'monthly', 'quarterly', 'yearly'];

class AddRecurringPage extends StatefulWidget {
  final RecurringExpenseModel? existing;

  const AddRecurringPage({super.key, this.existing});

  @override
  State<AddRecurringPage> createState() => _AddRecurringPageState();
}

class _AddRecurringPageState extends State<AddRecurringPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final TextEditingController _amountController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  List<AccountModel> accounts = [];
  CategoryModel? selectedCategory;
  String frequency = 'monthly';
  int dayOfMonth = 1;
  DateTime startDate = DateTime.now();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = existing.amount == existing.amount.roundToDouble()
          ? existing.amount.toStringAsFixed(0)
          : existing.amount.toString();
      frequency = _selectableFrequencies.contains(existing.frequency) ? existing.frequency : 'monthly';
      if (existing.startDate.isNotEmpty) {
        startDate = PeriodCalculator.parseDate(existing.startDate);
      }
      if (frequency == 'monthly' && existing.nextDueDate.isNotEmpty) {
        dayOfMonth = PeriodCalculator.parseDate(existing.nextDueDate).day.clamp(1, 31);
      }
    }

    _load();
  }

  Future<void> _load() async {
    try {
      final loadedAccounts = await _firestoreService.getAccounts();
      CategoryModel? existingCategory;
      final existing = widget.existing;
      if (existing != null) {
        existingCategory = await _firestoreService.getCategoryById(existing.categoryId);
      }

      if (!mounted) return;
      setState(() {
        accounts = loadedAccounts;
        selectedCategory ??= existingCategory;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading recurring form data: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectCategory() async {
    final result = await showCategorySelectionModal(
      context,
      selectedCategory: selectedCategory,
      type: 'expense',
    );
    if (!mounted || result == null) return;

    if (result == 'create') {
      final created = await Navigator.push<CategoryModel>(
        context,
        MaterialPageRoute(builder: (_) => const CreateCategoryPage(transactionType: 'expense')),
      );
      if (created != null) setState(() => selectedCategory = created);
      return;
    }

    if (result is CategoryModel) {
      setState(() => selectedCategory = result);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => startDate = picked);
  }

  DateTime _computeNextDueDate() {
    if (frequency == 'monthly') {
      final today = DateTime(startDate.year, startDate.month, startDate.day);
      final thisMonth = DateTime(startDate.year, startDate.month, dayOfMonth);
      if (!thisMonth.isBefore(today)) return thisMonth;
      return DateTime(startDate.year, startDate.month + 1, dayOfMonth);
    }
    return startDate;
  }

  bool get _canSave =>
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0 &&
      selectedCategory != null &&
      (_isEditing || accounts.isNotEmpty);

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => isSaving = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final nextDue = _computeNextDueDate();

      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: selectedCategory!.name,
          amount: amount,
          categoryId: selectedCategory!.id,
          frequency: frequency,
          startDate: PeriodCalculator.formatDate(startDate),
          nextDueDate: PeriodCalculator.formatDate(nextDue),
        );
        await _firestoreService.updateRecurringExpense(updated);
      } else {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final defaultAccount = accounts.firstWhere(
          (a) => a.isDefault,
          orElse: () => accounts.first,
        );

        final expense = RecurringExpenseModel(
          userId: userId,
          name: selectedCategory!.name,
          amount: amount,
          categoryId: selectedCategory!.id!,
          frequency: frequency,
          startDate: PeriodCalculator.formatDate(startDate),
          nextDueDate: PeriodCalculator.formatDate(nextDue),
          reminderDays: 0,
          accountId: defaultAccount.id!,
          status: 'active',
          createdDate: DateTime.now().millisecondsSinceEpoch,
        );
        await _firestoreService.addRecurringExpense(expense);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error saving recurring expense: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this recurring expense.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recurring Expense' : 'Add Recurring Expense'),
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
                  AmountField(
                    label: 'Amount',
                    controller: _amountController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('Category'),
                  GestureDetector(
                    onTap: _selectCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedCategory != null
                                ? getCategoryIcon(selectedCategory!.iconName)
                                : Icons.category_outlined,
                            color: selectedCategory != null ? AppColors.primary : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedCategory?.name ?? 'Select Category',
                              style: TextStyle(
                                fontWeight: selectedCategory != null ? FontWeight.w700 : FontWeight.w400,
                                color: selectedCategory != null ? Colors.black87 : Colors.grey[500],
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('Frequency'),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    items: _selectableFrequencies
                        .map((f) => DropdownMenuItem(value: f, child: Text(frequencyLabel(f))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => frequency = value);
                    },
                  ),
                  if (frequency == 'monthly') ...[
                    const SizedBox(height: 20),
                    const SectionLabel('Day of Month'),
                    DropdownButtonFormField<int>(
                      initialValue: dayOfMonth,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      items: List.generate(31, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => dayOfMonth = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  const SectionLabel('Start Date'),
                  GestureDetector(
                    onTap: _pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(PeriodCalculator.formatDate(startDate)),
                        ],
                      ),
                    ),
                  ),
                  if (!_isEditing && accounts.isEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Add an account first — recurring expenses need one to pay from.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  PrimaryActionButton(
                    label: isSaving ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Add Expense'),
                    onPressed: isSaving || !_canSave ? null : _save,
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
