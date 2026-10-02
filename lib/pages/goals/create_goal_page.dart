import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../models/goal_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/finance_widgets.dart';
import '../accounts/create_account_page.dart';

/// Common icon used for every manually created goal — no per-goal icon
/// picker, matching how categories now get one shared default icon too.
const String _defaultGoalIconName = 'flag';

class CreateGoalPage extends StatefulWidget {
  const CreateGoalPage({super.key});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime? _targetDate;
  bool isSaving = false;
  bool isLoading = true;

  List<AccountModel> accounts = [];
  AccountModel? selectedAccount;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final loaded = await _firestoreService.getAccounts();
      if (!mounted) return;
      setState(() {
        accounts = loaded;
        selectedAccount ??= accounts.isNotEmpty
            ? accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first)
            : null;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading accounts for goal: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _createAccount() async {
    final created = await showCreateAccountSheet(context);
    if (created == null) return;
    await _loadAccounts();
    if (!mounted) return;
    setState(() => selectedAccount = created);
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (double.tryParse(_targetController.text.trim()) ?? 0) > 0 &&
      _targetDate != null &&
      selectedAccount != null;

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();

      final goal = GoalModel(
        userId: userId,
        goalName: _nameController.text.trim(),
        targetAmount: double.parse(_targetController.text.trim()),
        currentAmount: 0,
        targetDate: PeriodCalculator.formatDate(_targetDate!),
        notes: _notesController.text.trim(),
        iconName: _defaultGoalIconName,
        status: 'active',
        accountId: selectedAccount!.id,
        createdDate: now.millisecondsSinceEpoch,
      );

      await _firestoreService.addGoal(goal);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Error creating goal: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create the goal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Goal'),
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
                  const SectionLabel('Goal Name'),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g. Emergency Fund, Europe Vacation',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel('Account'),
                      TextButton.icon(
                        onPressed: _createAccount,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create account'),
                      ),
                    ],
                  ),
                  if (accounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No accounts yet. Create one to link this goal.'),
                    )
                  else
                    SizedBox(
                      height: 64,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          final selected = selectedAccount?.id == account.id;
                          return GestureDetector(
                            onTap: () => setState(() => selectedAccount = account),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? AppColors.primary : Colors.grey[300]!,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    account.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: selected ? AppColors.primary : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'Rs ${account.balance.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selected ? AppColors.primary : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  AmountField(
                    label: 'Target Amount',
                    controller: _targetController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('Target Date'),
                  GestureDetector(
                    onTap: _pickTargetDate,
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
                          Text(
                            _targetDate != null
                                ? PeriodCalculator.formatDate(_targetDate!)
                                : 'When do you want to reach this goal?',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('Notes (optional)'),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Why is this goal important to you?',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  PrimaryActionButton(
                    label: isSaving ? 'Saving...' : 'Create Goal',
                    onPressed: isSaving || !_canSave ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
