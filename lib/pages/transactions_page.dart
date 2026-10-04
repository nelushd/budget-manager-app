import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_entry.dart';
import '../services/firestore_service.dart';
import '../utils/activity_builder.dart';

class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF1B2430);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2E3A4A);
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);
}

class TransactionsPage extends StatefulWidget {
  final String initialMode;
  final String title;

  const TransactionsPage({
    super.key,
    this.initialMode = 'all',
    this.title = 'Transactions',
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  bool _isLoading = true;
  List<ActivityEntry> _allEntries = [];

  late String _mode;
  String _nameQuery = '';
  String _amountQuery = '';
  String _categoryFilter = 'All Categories';
  bool _useDateRange = false;
  int _filterMonth = DateTime.now().month;
  int _filterYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await loadActivityFeed(FirestoreService.instance);
      if (!mounted) return;
      setState(() {
        _allEntries = entries;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading transactions: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<String> get _categoryOptions {
    final names = _allEntries
        .where((e) => e.kind == 'income' || e.kind == 'expense')
        .map((e) => e.title)
        .toSet()
        .toList();
    names.sort();
    return ['All Categories', ...names];
  }

  int get _activeFilterCount {
    var count = 0;
    if (_mode != 'all') count++;
    if (_useDateRange) count++;
    if (_nameQuery.isNotEmpty) count++;
    if (_amountQuery.isNotEmpty) count++;
    if (_categoryFilter != 'All Categories') count++;
    return count;
  }

  List<ActivityEntry> get _filtered {
    final amountQuery = double.tryParse(_amountQuery);

    return _allEntries.where((entry) {
      switch (_mode) {
        case 'income':
          if (entry.kind != 'income') return false;
          break;
        case 'expense':
          if (entry.kind != 'expense') return false;
          break;
        case 'cashIn':
          if (!entry.isInflow) return false;
          break;
        case 'cashOut':
          if (entry.isInflow) return false;
          break;
      }

      if (_useDateRange &&
          (entry.date.month != _filterMonth || entry.date.year != _filterYear)) {
        return false;
      }

      if (_nameQuery.isNotEmpty &&
          !entry.title.toLowerCase().contains(_nameQuery.toLowerCase())) {
        return false;
      }

      if (amountQuery != null && entry.amount != amountQuery) {
        return false;
      }

      if (_categoryFilter != 'All Categories' && entry.title != _categoryFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<ActivityEntry>> get _groupedByDate {
    final grouped = <String, List<ActivityEntry>>{};
    for (final entry in _filtered) {
      final key = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-'
          '${entry.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  String _formatAmount(double amount) => 'Rs ${NumberFormat('#,##0.00').format(amount)}';

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);

    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedByDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      backgroundColor: _Dark.bg,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, color: _Dark.textPrimary)),
        backgroundColor: _Dark.bg,
        foregroundColor: _Dark.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton.icon(
                onPressed: _showFilters,
                icon: Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  backgroundColor: _Dark.accent,
                  textColor: _Dark.bg,
                  label: Text('$_activeFilterCount'),
                  child: const Icon(Icons.tune_rounded, size: 20, color: _Dark.textPrimary),
                ),
                label: const Text('Filters', style: TextStyle(color: _Dark.textPrimary)),
                style: TextButton.styleFrom(foregroundColor: _Dark.textPrimary),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Dark.accent))
          : groups.isEmpty
              ? const Center(
                  child: Text(
                    'No transactions match these filters.',
                    style: TextStyle(color: _Dark.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _Dark.accent,
                  backgroundColor: _Dark.card,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final dayEntries = groups[index].value;
                      final date = dayEntries.first.date;
                      final dayIn = dayEntries
                          .where((e) => e.isInflow)
                          .fold(0.0, (sum, e) => sum + e.amount);
                      final dayOut = dayEntries
                          .where((e) => !e.isInflow)
                          .fold(0.0, (sum, e) => sum + e.amount);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _dayLabel(date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: _Dark.textPrimary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (dayIn > 0)
                                      Text(
                                        '+ ${_formatAmount(dayIn)}',
                                        style: const TextStyle(
                                          color: _Dark.success,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (dayIn > 0 && dayOut > 0) const SizedBox(width: 8),
                                    if (dayOut > 0)
                                      Text(
                                        '- ${_formatAmount(dayOut)}',
                                        style: const TextStyle(
                                          color: _Dark.error,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: _Dark.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _Dark.divider),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < dayEntries.length; i++)
                                    Column(
                                      children: [
                                        _entryTile(dayEntries[i]),
                                        if (i != dayEntries.length - 1)
                                          Divider(height: 1, color: _Dark.divider),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _entryTile(ActivityEntry entry) {
    final color = entry.isInflow ? _Dark.success : _Dark.error;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _Dark.textPrimary),
                ),
                if (entry.subtitle.isNotEmpty)
                  Text(entry.subtitle, style: const TextStyle(color: _Dark.textSecondary, fontSize: 12)),
                if (entry.kind == 'loan' || entry.kind == 'lending')
                  Text(
                    entry.note ?? '',
                    style: const TextStyle(color: _Dark.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          Text(
            '${entry.isInflow ? '+' : '-'} ${_formatAmount(entry.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }

  InputDecoration _darkInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _Dark.textSecondary),
      prefixIcon: Icon(icon, color: _Dark.textSecondary),
      filled: true,
      fillColor: _Dark.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _Dark.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _Dark.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _Dark.accent),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _Dark.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filters',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _Dark.textPrimary),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setSheetState(() {
                                      _mode = 'all';
                                      _useDateRange = false;
                                      _nameQuery = '';
                                      _amountQuery = '';
                                      _categoryFilter = 'All Categories';
                                    });
                                  },
                                  style: TextButton.styleFrom(foregroundColor: _Dark.accent),
                                  child: const Text('Clear Filters'),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(Icons.close, color: _Dark.textPrimary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _filterSectionLabel('MODE'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _modeChip('All', 'all', setSheetState),
                            _modeChip('Income', 'income', setSheetState),
                            _modeChip('Expense', 'expense', setSheetState),
                            _modeChip('Cash In', 'cashIn', setSheetState),
                            _modeChip('Cash Out', 'cashOut', setSheetState),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _filterSectionLabel('DATE RANGE'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All time'),
                              selected: !_useDateRange,
                              onSelected: (_) => setSheetState(() => _useDateRange = false),
                              selectedColor: _Dark.accent,
                              backgroundColor: _Dark.card,
                              labelStyle: TextStyle(color: !_useDateRange ? _Dark.bg : _Dark.textSecondary),
                              side: BorderSide(color: !_useDateRange ? _Dark.accent : _Dark.divider),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Date Range'),
                              selected: _useDateRange,
                              onSelected: (_) => setSheetState(() => _useDateRange = true),
                              selectedColor: _Dark.accent,
                              backgroundColor: _Dark.card,
                              labelStyle: TextStyle(color: _useDateRange ? _Dark.bg : _Dark.textSecondary),
                              side: BorderSide(color: _useDateRange ? _Dark.accent : _Dark.divider),
                            ),
                          ],
                        ),
                        if (_useDateRange) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _filterMonth,
                                  dropdownColor: _Dark.card,
                                  style: const TextStyle(color: _Dark.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Month',
                                    labelStyle: const TextStyle(color: _Dark.textSecondary),
                                    filled: true,
                                    fillColor: _Dark.card,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: _Dark.divider),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: _Dark.divider),
                                    ),
                                  ),
                                  items: List.generate(12, (i) => i + 1)
                                      .map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(DateFormat('MMM').format(DateTime(2000, m))),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) setSheetState(() => _filterMonth = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _filterYear,
                                  dropdownColor: _Dark.card,
                                  style: const TextStyle(color: _Dark.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Year',
                                    labelStyle: const TextStyle(color: _Dark.textSecondary),
                                    filled: true,
                                    fillColor: _Dark.card,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: _Dark.divider),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: _Dark.divider),
                                    ),
                                  ),
                                  items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) setSheetState(() => _filterYear = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        _filterSectionLabel('SEARCH BY NAME'),
                        const SizedBox(height: 10),
                        TextField(
                          style: const TextStyle(color: _Dark.textPrimary),
                          decoration: _darkInputDecoration(hint: 'Search transaction name', icon: Icons.search),
                          controller: TextEditingController(text: _nameQuery)
                            ..selection = TextSelection.collapsed(offset: _nameQuery.length),
                          onChanged: (value) => _nameQuery = value,
                        ),
                        const SizedBox(height: 20),
                        _filterSectionLabel('SEARCH BY AMOUNT'),
                        const SizedBox(height: 10),
                        TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: _Dark.textPrimary),
                          decoration: _darkInputDecoration(hint: 'Enter amount', icon: Icons.attach_money),
                          controller: TextEditingController(text: _amountQuery)
                            ..selection = TextSelection.collapsed(offset: _amountQuery.length),
                          onChanged: (value) => _amountQuery = value,
                        ),
                        const SizedBox(height: 20),
                        _filterSectionLabel('CATEGORY'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categoryOptions.map((name) {
                            final selected = _categoryFilter == name;
                            return ChoiceChip(
                              label: Text(name),
                              selected: selected,
                              onSelected: (_) => setSheetState(() => _categoryFilter = name),
                              selectedColor: _Dark.accent,
                              backgroundColor: _Dark.card,
                              labelStyle: TextStyle(color: selected ? _Dark.bg : _Dark.textSecondary),
                              side: BorderSide(color: selected ? _Dark.accent : _Dark.divider),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {});
                              Navigator.pop(sheetContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _Dark.accent,
                              foregroundColor: _Dark.bg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Apply${_activeFilterCount > 0 ? ' ($_activeFilterCount)' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    ).then((_) => setState(() {}));
  }

  Widget _filterSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _Dark.textSecondary, letterSpacing: 1),
    );
  }

  Widget _modeChip(String label, String value, StateSetter setSheetState) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setSheetState(() => _mode = value),
      selectedColor: _Dark.accent,
      backgroundColor: _Dark.card,
      labelStyle: TextStyle(color: selected ? _Dark.bg : _Dark.textSecondary, fontWeight: FontWeight.w600),
      side: BorderSide(color: selected ? _Dark.accent : _Dark.divider),
    );
  }
}
