import 'package:flutter/material.dart';

import '../../data/database_helper.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/category_icon.dart';
import '../accounts/accounts_page.dart';
import '../categories/categories_page.dart';
import '../categories/create_category_page.dart';

class AddTransactionPage extends StatefulWidget {
  final String transactionType; // income or expense

  const AddTransactionPage({
    super.key,
    required this.transactionType,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final amountController = TextEditingController();
  final titleController = TextEditingController();
  final noteController = TextEditingController();

  List<AccountModel> accounts = [];
  List<CategoryModel> categories = [];

  AccountModel? selectedAccount;
  CategoryModel? selectedCategory;

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    loadData().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('Auto-opening category selector on page open');
        _showCategoryModal(context);
      });
    });

    amountController.addListener(() => setState(() {}));
    titleController.addListener(() => setState(() {}));
  }

  Future<void> loadData() async {
    final loadedAccounts = await DatabaseHelper.instance.getAccounts();
    final loadedCategories = await DatabaseHelper.instance
        .getCategoriesByType(widget.transactionType);

    if (!mounted) return;

    setState(() {
      accounts = loadedAccounts;
      categories = loadedCategories;

      if (accounts.isNotEmpty) {
        selectedAccount ??= accounts.first;
      }

      if (categories.isNotEmpty) {
        selectedCategory ??= categories.first;
      }
    });
    debugPrint('Loaded accounts: ${accounts.length}, categories: ${categories.length} for type ${widget.transactionType}');
  }

  Future<void> saveTransaction() async {
    if (amountController.text.trim().isEmpty ||
        titleController.text.trim().isEmpty ||
        selectedAccount == null ||
        selectedCategory == null) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      return;
    }

    final now = DateTime.now();

    final transaction = TransactionModel(
      title: titleController.text.trim(),
      amount: amount,
      type: widget.transactionType,
      categoryId: selectedCategory!.id!,
      accountId: selectedAccount!.id!,
      note: noteController.text.trim(),
      receiptPath: null,
      date:
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
      time:
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
      createdAt: now.millisecondsSinceEpoch,
    );

    await DatabaseHelper.instance.insertTransaction(transaction);

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  Future<void> _showCategoryModal(BuildContext context) async {
    try {
      debugPrint('Showing category modal...');
      final result = await showCategorySelectionModal(
        context,
        selectedCategory: selectedCategory,
        type: widget.transactionType,
      );

      debugPrint('Category modal result: $result');

      if (!mounted) return;

      if (result == 'create') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateCategoryPage(
              transactionType: widget.transactionType,
            ),
          ),
        );

        await loadData();
      } else if (result is CategoryModel) {
        setState(() {
          selectedCategory = result;
        });
      }
    } catch (e, st) {
      debugPrint('Error showing category modal: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.transactionType == 'income';
    final pageTitle = isIncome ? 'Add Income' : 'Add Expense';
    final accentColor =
        isIncome ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    final canSave = amountController.text.trim().isNotEmpty &&
        titleController.text.trim().isNotEmpty &&
        selectedAccount != null &&
        selectedCategory != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Rs ',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // Category
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 88,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = selectedCategory?.id == category.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategory = category;
                            });
                          },
                          child: Container(
                            width: 86,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.10)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? accentColor
                                    : Colors.grey[300]!,
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  getCategoryIcon(category.iconName),
                                  size: 24,
                                  color: isSelected
                                      ? accentColor
                                      : Colors.black,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  category.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? accentColor
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    debugPrint('Category more button tapped');
                    _showCategoryModal(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: _dateTimeBox(
                    title: 'Date',
                    icon: Icons.calendar_today,
                    text:
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateTimeBox(
                    title: 'Time',
                    icon: Icons.access_time,
                    text: selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // Account
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountsPage(openCreate: true),
                      ),
                    );

                    await loadData();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add new account'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: accounts.map((account) {
                  final isSelected = selectedAccount?.id == account.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAccount = account;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : Colors.grey[300]!,
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
                              color: isSelected ? accentColor : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rs ${account.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? accentColor
                                  : Colors.grey,
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

            _inputLabel('Title'),
            const SizedBox(height: 12),
            _textField(
              controller: titleController,
              hintText: 'Enter title',
            ),

            const SizedBox(height: 20),

            _inputLabel('Note'),
            const SizedBox(height: 12),
            _textField(
              controller: noteController,
              hintText: 'Add a note',
              maxLines: 3,
            ),

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canSave ? saveTransaction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
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
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14),
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
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }
}