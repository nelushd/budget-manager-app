import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/category_icon.dart';
import '../accounts/accounts_page.dart';
import '../categories/categories_page.dart';
import '../categories/create_category_page.dart'; 
import '../../models/receipt_scan_result.dart';
import '../../services/receipt_scanner_service.dart';

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
  final ReceiptScannerService receiptScannerService = ReceiptScannerService.instance;
  bool isScanningReceipt = false;
  final FirestoreService firestoreService = FirestoreService.instance;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  List<AccountModel> accounts = [];
  List<CategoryModel> categories = [];

  AccountModel? selectedAccount;
  CategoryModel? selectedCategory;

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  late String selectedType;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    selectedType = widget.transactionType;

    amountController.addListener(_refreshPage);

    loadData();
  }

  void _refreshPage() {
    if (mounted) {
      setState(() {});
    }
  }

  List<CategoryModel> get _displayCategories {
    if (selectedCategory == null || categories.isEmpty) {
      return categories;
    }

    final selectedIndex = categories.indexWhere(
      (category) => category.id == selectedCategory!.id,
    );

    if (selectedIndex <= 0) {
      return categories;
    }

    final reordered = List<CategoryModel>.from(categories);
    final selected = reordered.removeAt(selectedIndex);
    reordered.insert(0, selected);
    return reordered;
  }

  Future<void> loadData() async {
    try {
      final loadedAccounts = await firestoreService.getAccounts();

      final loadedCategories = await firestoreService.getCategoriesByType(selectedType);

      if (!mounted) return;

      setState(() {
        accounts = loadedAccounts;
        categories = loadedCategories;
        isLoading = false;

        if (accounts.isNotEmpty) {
          final selectedAccountStillExists =
              selectedAccount != null &&
                  accounts.any(
                    (account) => account.id == selectedAccount!.id,
                  );

          if (!selectedAccountStillExists) {
            final defaultAccounts =
                accounts.where((account) => account.isDefault).toList();

            selectedAccount = defaultAccounts.isNotEmpty
                ? defaultAccounts.first
                : accounts.first;
          }
        } else {
          selectedAccount = null;
        }

        if (categories.isNotEmpty) {
          final selectedCategoryStillExists =
              selectedCategory != null &&
                  categories.any(
                    (category) =>
                        category.id == selectedCategory!.id,
                  );

          if (!selectedCategoryStillExists) {
            selectedCategory = categories.first;
          }
        } else {
          selectedCategory = null;
        }
      });

      debugPrint(
        'Loaded accounts: ${accounts.length}, '
        'categories: ${categories.length}, '
        'type: $selectedType',
      );
    } catch (error, stackTrace) {
      debugPrint('Error loading transaction data: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load accounts and categories.',
        isError: true,
      );
    }
  }

  Future<void> _changeTransactionType(String newType) async {
    if (selectedType == newType) return;

    setState(() {
      selectedType = newType;
      selectedCategory = null;
      categories = [];
      isLoading = true;
    });

    try {
      final loadedCategories =
    await firestoreService.getCategoriesByType(selectedType);

      if (!mounted) return;

      setState(() {
        categories = loadedCategories;
        selectedCategory =
            loadedCategories.isNotEmpty ? loadedCategories.first : null;
        isLoading = false;
      });

      debugPrint(
        'Changed transaction type to $selectedType. '
        'Loaded ${categories.length} categories.',
      );
    } catch (error, stackTrace) {
      debugPrint('Error changing transaction type: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load $newType categories.',
        isError: true,
      );
    }
  }

  Future<void> saveTransaction() async {
    if (isSaving) return;

    final amountText =
        amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (amountText.isEmpty || amount == null || amount <= 0) {
      _showMessage(
        'Please enter a valid amount.',
        isError: true,
      );
      return;
    }

    if (selectedCategory == null) {
      _showMessage(
        'Please select a category.',
        isError: true,
      );
      return;
    }

    if (selectedAccount == null) {
      _showMessage(
        'Please select an account.',
        isError: true,
      );
      return;
    }

    if (selectedCategory!.id == null ||
        selectedAccount!.id == null) {
      _showMessage(
        'The selected category or account is invalid.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final now = DateTime.now();

      final transaction = TransactionModel(
        amount: amount,
        type: selectedType,
        categoryId: selectedCategory!.id!,
        accountId: selectedAccount!.id!,
        note: noteController.text.trim(),
        receiptPath: null,
        date:
            '${selectedDate.year}-'
            '${selectedDate.month.toString().padLeft(2, '0')}-'
            '${selectedDate.day.toString().padLeft(2, '0')}',
        time:
            '${selectedTime.hour.toString().padLeft(2, '0')}:'
            '${selectedTime.minute.toString().padLeft(2, '0')}',
        createdAt: now.millisecondsSinceEpoch,
      );

     await firestoreService.addTransaction(transaction);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error saving transaction: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save the transaction.',
        isError: true,
      );
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      selectedDate = pickedDate;
    });
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      selectedTime = pickedTime;
    });
  }

  Future<void> _showCategoryModal(
    BuildContext context,
  ) async {
    try {
      debugPrint(
        'Opening category modal for type: $selectedType',
      );

      final result = await showCategorySelectionModal(
        context,
        selectedCategory: selectedCategory,
        type: selectedType,
      );

      if (!mounted) return;

      if (result == 'create') {
        final createdCategory = await Navigator.push<CategoryModel>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateCategoryPage(
              transactionType: selectedType,
            ),
          ),
        );

        await loadData();

        if (!mounted) return;

        if (createdCategory != null) {
          setState(() {
            selectedCategory = createdCategory;
          });
        }
      } else if (result is CategoryModel) {
        setState(() {
          selectedCategory = result;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Error showing category modal: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _showMessage(
        'Unable to open the category selector.',
        isError: true,
      );
    }
  }

  void _showScanOptions(BuildContext context) {
    final accentColor = selectedType == 'income'
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Scan Bill or Receipt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a printed or handwritten bill. '
                  'The extracted details will be added to this form.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                _scanOptionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Use the camera to scan a bill',
                  accentColor: accentColor,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _takeReceiptPhoto();
                  },
                ),
                const SizedBox(height: 10),
                _scanOptionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select an existing receipt image',
                  accentColor: accentColor,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _chooseReceiptImage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scanOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: accentColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takeReceiptPhoto() async {
    await _scanReceipt(
      () => receiptScannerService.scanFromCamera(),
    );
  }

  Future<void> _chooseReceiptImage() async {
    await _scanReceipt(
      () => receiptScannerService.scanFromGallery(),
    );
  }

  Future<void> _scanReceipt(
    Future<ReceiptScanResult?> Function() scanAction,
  ) async {
    if (isScanningReceipt) return;

    setState(() {
      isScanningReceipt = true;
    });

    try {
      final ReceiptScanResult? result = await scanAction();

      if (!mounted || result == null) return;

      _applyReceiptResult(result);

      _showMessage(
        'Receipt scanned. Review the details before saving.',
      );
    } catch (error, stackTrace) {
      debugPrint('Receipt scanning error: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _showMessage(
        'Could not scan the receipt.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isScanningReceipt = false;
        });
      }
    }
  }

  void _applyReceiptResult(ReceiptScanResult result) {
    setState(() {
      if (result.amount != null) {
        amountController.text =
            result.amount!.toStringAsFixed(2);
      }

      if (result.date != null) {
        selectedDate = result.date!;
      }

      if (result.time != null) {
        selectedTime = result.time!;
      }

      if (result.notes != null &&
          noteController.text.trim().isEmpty) {
        noteController.text = result.notes!;
      }

      if (result.category != null) {
        selectedCategory =
            _findMatchingCategory(result.category!);
      }
    });
  }

  CategoryModel? _findMatchingCategory(
    String suggestedCategory,
  ) {
    final String normalizedSuggestion =
        suggestedCategory.trim().toLowerCase();

    for (final CategoryModel category in categories) {
      if (category.name.trim().toLowerCase() ==
          normalizedSuggestion) {
        return category;
      }
    }

    return selectedCategory;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? const Color(0xFFB91C1C) : Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = selectedType == 'income';

    final accentColor = isIncome
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    final parsedAmount = double.tryParse(
          amountController.text.trim().replaceAll(',', ''),
        ) ??
        0;

    final canSave = parsedAmount > 0 &&
        selectedAccount != null &&
        selectedCategory != null &&
        !isSaving;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Add Transaction',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: accentColor,
              ),
            )
          : SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Income / Expense switch
                  Container(
                    height: 58,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _transactionTypeButton(
                            title: 'Income',
                            icon: Icons.arrow_downward_rounded,
                            type: 'income',
                            selectedColor:
                                const Color(0xFF22C55E),
                          ),
                        ),
                        Expanded(
                          child: _transactionTypeButton(
                            title: 'Expense',
                            icon: Icons.arrow_upward_rounded,
                            type: 'expense',
                            selectedColor:
                                const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Amount and Scan Receipt card
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      20,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL AMOUNT',
                          style: TextStyle(
                            color:
                                accentColor.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Rs ',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Flexible(
                              child: TextField(
                                controller: amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: TextStyle(
                                    color: accentColor.withValues(
                                      alpha: 0.24,
                                    ),
                                    fontSize: 46,
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
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: isScanningReceipt
                              ? null
                              : () => _showScanOptions(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(0xFF6B7280),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: accentColor.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(24),
                            ),
                          ),
                          icon: isScanningReceipt
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(
                                  Icons.document_scanner_outlined,
                                  size: 19,
                                ),
                          label: Text(
                            isScanningReceipt
                                ? 'Scanning...'
                                : 'Scan Receipt',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                        child: categories.isEmpty
                            ? Container(
                                height: 88,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  'No $selectedType categories',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 88,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.zero,
                                  itemCount: _displayCategories.length,
                                  itemBuilder: (context, index) {
                                    final category =
                                        _displayCategories[index];

                                    final isSelected =
                                        selectedCategory?.id ==
                                            category.id;

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedCategory =
                                              category;
                                        });
                                      },
                                      child: Container(
                                        width: 86,
                                        margin:
                                            const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? accentColor.withValues(
                                                  alpha: 0.10,
                                                )
                                              : Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? accentColor
                                                : Colors.grey[300]!,
                                            width:
                                                isSelected ? 1.6 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              getCategoryIcon(
                                                category.iconName,
                                              ),
                                              size: 24,
                                              color: isSelected
                                                  ? accentColor
                                                  : Colors.black,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              category.name,
                                              textAlign:
                                                  TextAlign.center,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w600,
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
                        onTap: () =>
                            _showCategoryModal(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
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
                              '${selectedDate.year}-'
                              '${selectedDate.month.toString().padLeft(2, '0')}-'
                              '${selectedDate.day.toString().padLeft(2, '0')}',
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

                  // Account heading
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
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
                              builder: (_) =>
                                  const AccountsPage(
                                openCreate: true,
                              ),
                            ),
                          );

                          await loadData();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add new account',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (accounts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      child: const Text(
                        'No accounts are available. Add an account to continue.',
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: accounts.map((account) {
                          final isSelected =
                              selectedAccount?.id == account.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedAccount = account;
                              });
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor.withValues(
                                        alpha: 0.1,
                                      )
                                    : Colors.grey[100],
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? accentColor
                                          : Colors.black,
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
                      onPressed:
                          canSave ? saveTransaction : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey[300],
                        disabledForegroundColor:
                            Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Transaction',
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

  Widget _transactionTypeButton({
    required String title,
    required IconData icon,
    required String type,
    required Color selectedColor,
  }) {
    final isSelected = selectedType == type;

    return GestureDetector(
      onTap: () => _changeTransactionType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : Colors.grey[500],
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : Colors.grey[500],
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
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
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
          borderSide: BorderSide(
            color: Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: selectedType == 'income'
                ? const Color(0xFF22C55E)
                : const Color(0xFFEF4444),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    amountController.removeListener(_refreshPage);

    amountController.dispose();
    noteController.dispose();

    super.dispose();
  }
}