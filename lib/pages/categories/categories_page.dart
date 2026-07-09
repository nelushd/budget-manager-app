import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../data/database_helper.dart';
import '../../utils/category_icon.dart';

/// Shows a reusable category selection modal.
/// Returns a `CategoryModel` when the user selects a category,
/// returns the string `'create'` when the user taps Create,
/// or `null` if dismissed.

Future<dynamic> showCategorySelectionModal(BuildContext context, {CategoryModel? selectedCategory, String? type}) async {
	List<CategoryModel> categories;
	if (type == null) {
		final income = await DatabaseHelper.instance.getCategoriesByType('income');
		final expense = await DatabaseHelper.instance.getCategoriesByType('expense');
		categories = [...income, ...expense];
	} else {
		categories = await DatabaseHelper.instance.getCategoriesByType(type);
	}

		debugPrint('Opening category modal, type=${type ?? 'all'}, categories=${categories.length}');
		// Debug: print category names and types to help diagnose missing items
		for (var c in categories) {
			debugPrint('Category: ${c.name} (type=${c.type}, icon=${c.iconName}, id=${c.id})');
		}

		return showModalBottomSheet<dynamic>(
			context: context,
			isScrollControlled: true,
			backgroundColor: Colors.white,
			shape: const RoundedRectangleBorder(
				borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

	const _CategorySelectionModal({required this.categories, required this.selectedCategory});

	@override
	State<_CategorySelectionModal> createState() => _CategorySelectionModalState();
}

class _CategorySelectionModalState extends State<_CategorySelectionModal> {
	late List<CategoryModel> filteredCategories;
	final searchController = TextEditingController();

	@override
	void initState() {
		super.initState();
		filteredCategories = widget.categories;
	}

	void _filterCategories(String query) {
		setState(() {
			if (query.isEmpty) {
				filteredCategories = widget.categories;
			} else {
				filteredCategories = widget.categories
						.where((cat) => cat.name.toLowerCase().contains(query.toLowerCase()))
						.toList();
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		// Build a bottom-sheet style select-category UI matching the sample architecture.
		final frequentlyUsed = filteredCategories.isNotEmpty
			? filteredCategories.take(3).toList()
			: <CategoryModel>[];

		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
			child: ConstrainedBox(
				constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						// Drag handle
						Center(
							child: Container(height: 4, width: 48, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
						),
						Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								const Expanded(
									child: Text('Select Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
								),
								ElevatedButton.icon(
									onPressed: () => Navigator.pop(context, 'create'),
									icon: const Icon(Icons.add, color: Colors.white),
									label: const Text('Create'),
									style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
								),
							],
						),
						const SizedBox(height: 12),
						TextField(
							controller: searchController,
							onChanged: _filterCategories,
							decoration: InputDecoration(
								hintText: 'Search categories',
								prefixIcon: const Icon(Icons.search),
								filled: true,
								fillColor: Colors.grey[100],
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
							),
						),
						const SizedBox(height: 16),
						// Frequently used
						if (frequentlyUsed.isNotEmpty) ...[
							Row(
								children: [
									Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8))),
									const SizedBox(width: 8),
									const Text('Frequently Used', style: TextStyle(fontWeight: FontWeight.bold)),
								],
							),
							const SizedBox(height: 8),
							SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(
									children: frequentlyUsed.map((c) {
										return Padding(
											padding: const EdgeInsets.only(right: 8),
											child: ActionChip(
												avatar: CircleAvatar(backgroundColor: Colors.grey[200], child: Icon(getCategoryIcon(c.iconName), color: Colors.black)),
												label: Text(c.name),
												onPressed: () => Navigator.pop(context, c),
											),
										);
									}).toList(),
								),
							),
							const SizedBox(height: 16),
						],
						// All categories header
						Row(
							children: [
								Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4))),
								const SizedBox(width: 8),
								const Text('ALL CATEGORIES', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600)),
								const SizedBox(width: 8),
								CircleAvatar(radius: 12, backgroundColor: Colors.green, child: Text('${filteredCategories.length}', style: const TextStyle(color: Colors.white, fontSize: 12))),
							],
						),
						const SizedBox(height: 12),
						// Grid of categories
						Expanded(
							child: GridView.count(
								crossAxisCount: 3,
								crossAxisSpacing: 12,
								mainAxisSpacing: 12,
								childAspectRatio: 0.9,
								children: filteredCategories.map((cat) {
									return GestureDetector(
										onTap: () => Navigator.pop(context, cat),
										child: Column(
											children: [
												Container(
													width: 72,
													height: 72,
													decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
													child: Center(child: Icon(getCategoryIcon(cat.iconName), size: 30)),
												),
												const SizedBox(height: 8),
												Text(cat.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
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

