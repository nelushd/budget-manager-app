import 'package:flutter/material.dart';
import 'package:budget_manager_app/models/category_model.dart';
import 'package:budget_manager_app/services/firestore_service.dart';
import 'package:budget_manager_app/utils/category_icon.dart';

class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF1B2430);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2E3A4A);
}

Future<dynamic> showCategorySelectionModal(
  BuildContext context, {
  CategoryModel? selectedCategory,
  String? type,
}) async {
  List<CategoryModel> categories;

  if (type == null) {
    final income =
        await FirestoreService.instance.getCategoriesByType('income');

    final expense =
        await FirestoreService.instance.getCategoriesByType('expense');

    categories = [...income, ...expense];
  } else {
    categories =
        await FirestoreService.instance.getCategoriesByType(type);
  }

  debugPrint(
    'Opening category modal, '
    'type=${type ?? 'all'}, '
    'categories=${categories.length}',
  );

  for (final category in categories) {
    debugPrint(
      'Category: ${category.name} '
      '(type=${category.type}, '
      'icon=${category.iconName}, '
      'id=${category.id})',
    );
  }

  if (!context.mounted) {
    return null;
  }

  return showModalBottomSheet<dynamic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _Dark.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (context) {
      return _CategorySelectionModal(
        categories: categories,
        selectedCategory: selectedCategory,
      );
    },
  );
}

class _CategorySelectionModal extends StatefulWidget {
  final List<CategoryModel> categories;
  final CategoryModel? selectedCategory;

  const _CategorySelectionModal({
    required this.categories,
    required this.selectedCategory,
  });

  @override
  State<_CategorySelectionModal> createState() =>
      _CategorySelectionModalState();
}

class _CategorySelectionModalState
    extends State<_CategorySelectionModal> {
  late List<CategoryModel> filteredCategories;

  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredCategories = widget.categories;
  }

  void _filterCategories(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        filteredCategories = widget.categories;
      } else {
        filteredCategories = widget.categories.where((category) {
          return category.name
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 48,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _Dark.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Select Category',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _Dark.textPrimary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, 'create');
                  },
                  icon: const Icon(
                    Icons.add,
                    color: _Dark.bg,
                  ),
                  label: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Dark.accent,
                    foregroundColor: _Dark.bg,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: _filterCategories,
              style: const TextStyle(color: _Dark.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search categories',
                hintStyle: const TextStyle(color: _Dark.textSecondary),
                prefixIcon: const Icon(Icons.search, color: _Dark.textSecondary),
                filled: true,
                fillColor: _Dark.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _Dark.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _Dark.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _Dark.accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _Dark.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ALL CATEGORIES',
                  style: TextStyle(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: _Dark.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredCategories.isEmpty
                  ? const Center(
                      child: Text(
                        'No categories found',
                        style: TextStyle(color: _Dark.textSecondary),
                      ),
                    )
                  : GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                      children:
                          filteredCategories.map((category) {
                        final bool isSelected =
                            widget.selectedCategory?.id ==
                                category.id;

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(
                              context,
                              category,
                            );
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _Dark.accent.withValues(alpha: 0.16)
                                      : _Dark.card,
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? _Dark.accent
                                        : _Dark.divider,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    getCategoryIcon(
                                      category.iconName,
                                    ),
                                    size: 30,
                                    color: isSelected
                                        ? _Dark.accent
                                        : _Dark.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                category.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? _Dark.textPrimary : _Dark.textSecondary,
                                ),
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
