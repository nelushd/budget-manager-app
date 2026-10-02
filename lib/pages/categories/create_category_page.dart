import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
import '../../models/category_model.dart';

/// Common icon used for every manually created category — users don't pick
/// an icon anymore, keeping category creation to just a name.
const String kDefaultCategoryIconName = 'category';

/// Dark palette matching Home/Analytics/Transactions/Add Transaction/SMS Parser.
class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF1B2430);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2E3A4A);
}

class CreateCategoryPage extends StatefulWidget {
  final String transactionType; // income or expense

  const CreateCategoryPage({
    super.key,
    required this.transactionType,
  });

  @override
  State<CreateCategoryPage> createState() => _CreateCategoryPageState();
}

class _CreateCategoryPageState extends State<CreateCategoryPage> {
  final FirestoreService firestoreService = FirestoreService.instance;
  final nameController = TextEditingController();

  late String type;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    type = widget.transactionType;
  }

  Future<void> _saveCategory() async {
    final name = nameController.text.trim();

    if (name.isEmpty) return;

    setState(() => isSaving = true);

    final category = CategoryModel(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      name: name,
      type: type,
      iconName: kDefaultCategoryIconName,
      isDefault: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await firestoreService.addCategory(category);

    if (!mounted) return;
    Navigator.pop(context, category);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = type == 'income';
    final accentColor =
        isIncome ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    final title = isIncome ? 'Create Income Category' : 'Create Expense Category';

    return Scaffold(
      backgroundColor: _Dark.bg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _Dark.bg,
        foregroundColor: _Dark.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _Dark.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: _Dark.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter category name',
                hintStyle: const TextStyle(color: _Dark.textSecondary),
                filled: true,
                fillColor: _Dark.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _Dark.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _Dark.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accentColor),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _Dark.textPrimary,
                      side: const BorderSide(color: _Dark.divider),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving || nameController.text.trim().isEmpty
                        ? null
                        : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _Dark.card,
                      disabledForegroundColor: _Dark.textSecondary,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
