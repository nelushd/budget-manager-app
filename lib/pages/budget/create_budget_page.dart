import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/category_color.dart';
import '../../utils/category_icon.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/dark_finance_widgets.dart';
import '../categories/categories_page.dart';
import '../categories/create_category_page.dart';

/// A budget always covers exactly one category and always resets monthly —
/// so there's nothing to name and nothing to allocate between categories,
/// just "which category" and "how much per month".
class CreateBudgetPage extends StatefulWidget {
  final BudgetModel? existing;

  const CreateBudgetPage({super.key, this.existing});

  @override
  State<CreateBudgetPage> createState() => _CreateBudgetPageState();
}

class _CreateBudgetPageState extends State<CreateBudgetPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final TextEditingController _amountController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  List<CategoryModel> categories = [];
  CategoryModel? _selectedCategory;

  /// Category ids that already have a budget (from other budgets — the one
  /// being edited, if any, doesn't count against itself).
  Set<String> _categoriesWithBudgets = {};

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = existing.budgetAmount == existing.budgetAmount.roundToDouble()
          ? existing.budgetAmount.toStringAsFixed(0)
          : existing.budgetAmount.toString();
    }

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final results = await Future.wait([
        _firestoreService.getCategoriesByType('expense'),
        _firestoreService.getBudgets(),
      ]);
      if (!mounted) return;

      final loadedCategories = results[0] as List<CategoryModel>;
      final existingBudgets = results[1] as List<BudgetModel>;

      final usedCategoryIds = <String>{
        for (final budget in existingBudgets)
          if (budget.id != widget.existing?.id)
            for (final allocation in budget.categoryAllocations) allocation.categoryId,
      };

      CategoryModel? preselected = _selectedCategory;
      final existing = widget.existing;
      if (preselected == null && existing != null && existing.categoryAllocations.isNotEmpty) {
        final categoryId = existing.categoryAllocations.first.categoryId;
        for (final category in loadedCategories) {
          if (category.id == categoryId) {
            preselected = category;
            break;
          }
        }
      }

      setState(() {
        categories = loadedCategories;
        _categoriesWithBudgets = usedCategoryIds;
        _selectedCategory = preselected;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading categories for budget: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  /// Opens the same category picker used when adding a transaction, so
  /// budget categories come from one shared list/flow instead of a
  /// budget-specific picker.
  Future<void> _selectCategory() async {
    final result = await showCategorySelectionModal(context, type: 'expense');
    if (!mounted || result == null) return;

    if (result == 'create') {
      final created = await Navigator.push<CategoryModel>(
        context,
        MaterialPageRoute(builder: (_) => const CreateCategoryPage(transactionType: 'expense')),
      );
      if (created != null) {
        setState(() => categories = [...categories, created]);
        _pickCategory(created);
      }
      return;
    }

    if (result is CategoryModel) {
      _pickCategory(result);
    }
  }

  void _pickCategory(CategoryModel category) {
    final id = category.id;
    if (id == null) return;

    if (_categoriesWithBudgets.contains(id)) {
      _showMessage('You already have a budget for this category.', isError: true);
      return;
    }

    setState(() => _selectedCategory = category);
  }

  Future<void> _save() async {
    final category = _selectedCategory;

    if (category?.id == null) {
      _showMessage('Please select a category.', isError: true);
      return;
    }
    if (_amount <= 0) {
      _showMessage('Please enter a budget amount.', isError: true);
      return;
    }

    setState(() => isSaving = true);

    try {
      final allocation = BudgetAllocation(categoryId: category!.id!, allocatedAmount: _amount);
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();

      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          budgetName: category.name,
          period: 'monthly',
          budgetAmount: _amount,
          categoryAllocations: [allocation],
        );
        await _firestoreService.updateBudget(updated);
      } else {
        final budget = BudgetModel(
          userId: userId,
          budgetName: category.name,
          period: 'monthly',
          budgetAmount: _amount,
          status: 'active',
          startDate: PeriodCalculator.formatDate(now),
          categoryAllocations: [allocation],
          createdDate: now.millisecondsSinceEpoch,
        );
        await _firestoreService.addBudget(budget);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error saving budget: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage('Unable to save the budget.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? FinanceDark.error : Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final category = _selectedCategory;

    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Budget' : 'Create Budget',
          style: const TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w800),
        ),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FinanceDark.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DarkSectionLabel('Category'),
                  const SizedBox(height: 8),
                  if (category == null)
                    GestureDetector(
                      onTap: _selectCategory,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: FinanceDark.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FinanceDark.divider),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: FinanceDark.accent),
                            SizedBox(width: 10),
                            Text(
                              'Select Category',
                              style: TextStyle(fontWeight: FontWeight.w600, color: FinanceDark.accent),
                            ),
                            Spacer(),
                            Icon(Icons.chevron_right, color: FinanceDark.textSecondary),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: FinanceDark.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FinanceDark.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colorForCategory(category.id).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              getCategoryIcon(category.iconName),
                              color: colorForCategory(category.id),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              category.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: FinanceDark.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: _selectCategory,
                            child: const Text('Change', style: TextStyle(color: FinanceDark.accent)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  const DarkSectionLabel('Monthly Budget Amount'),
                  const SizedBox(height: 8),
                  DarkAmountTile(controller: _amountController),
                  const SizedBox(height: 8),
                  const Text(
                    'This budget resets automatically every month.',
                    style: TextStyle(color: FinanceDark.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 26),
                  DarkActionButton(
                    label: isSaving
                        ? 'Saving...'
                        : (_isEditing ? 'Save Changes' : 'Create Budget'),
                    onPressed: isSaving ? null : _save,
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
