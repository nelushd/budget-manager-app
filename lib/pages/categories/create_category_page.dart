import 'package:flutter/material.dart';

import '../../data/database_helper.dart';
import '../../models/category_model.dart';
import '../../utils/category_icon.dart';

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
  final nameController = TextEditingController();

  late String type;
  String selectedIconName = 'category';

  final List<String> incomeIcons = [
    'payments',
    'laptop_mac',
    'business_center',
    'trending_up',
    'workspace_premium',
    'computer',
    'card_giftcard',
    'home_work',
    'account_balance',
    'assignment_return',
    'savings',
  ];

  final List<String> expenseIcons = [
    'home',
    'electric_bolt',
    'water_drop',
    'local_fire_department',
    'delete_outline',
    'shopping_cart',
    'smartphone',
    'wifi',
    'tv',
    'cleaning_services',
    'directions_bus',
    'local_gas_station',
    'directions_car',
    'local_parking',
    'school',
    'menu_book',
    'sports_soccer',
    'medical_services',
    'medication',
    'health_and_safety',
    'masks',
    'checkroom',
    'content_cut',
    'fitness_center',
    'restaurant',
    'movie',
    'flight',
    'palette',
    'credit_card',
    'savings',
    'card_giftcard',
    'warning_amber',
    'subscriptions',
    'account_balance',
  ];

  @override
  void initState() {
    super.initState();
    type = widget.transactionType;
    selectedIconName = type == 'income' ? 'payments' : 'shopping_cart';
  }

  Future<void> _saveCategory() async {
    final name = nameController.text.trim();

    if (name.isEmpty) return;

    final category = CategoryModel(
      name: name,
      type: type,
      iconName: selectedIconName,
      isDefault: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseHelper.instance.insertCategory(category);

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

    final iconList = isIncome ? incomeIcons : expenseIcons;
    final title = isIncome ? 'Create Income Category' : 'Create Expense Category';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Enter category name',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Icon',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                itemCount: iconList.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final iconName = iconList[index];
                  final isSelected = selectedIconName == iconName;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedIconName = iconName;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.12)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? accentColor : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        getCategoryIcon(iconName),
                        color: isSelected ? accentColor : Colors.black,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey[300]!),
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
                    onPressed: _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
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