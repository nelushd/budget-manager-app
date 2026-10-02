import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../constants/colors.dart';
import '../../models/account_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/finance/calculator_keypad.dart';

/// Opens account creation as a bottom sheet — scrollable and sized to its
/// content instead of a full page push. Returns the created account, or
/// null if dismissed without saving. [type] sets the new account's type
/// ('cash', 'bank', 'credit_card'); defaults to 'cash' for the generic "Add
/// Account" entry points. The name is always free text — "Sampath", "HNB",
/// "Cash", whatever the user actually calls the account.
Future<AccountModel?> showCreateAccountSheet(
  BuildContext context, {
  String type = 'cash',
}) {
  return showModalBottomSheet<AccountModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _CreateAccountSheetBody(type: type),
      );
    },
  );
}

class _CreateAccountSheetBody extends StatefulWidget {
  final String type;

  const _CreateAccountSheetBody({required this.type});

  @override
  State<_CreateAccountSheetBody> createState() => _CreateAccountSheetBodyState();
}

class _CreateAccountSheetBodyState extends State<_CreateAccountSheetBody> {
  final nameController = TextEditingController();
  final balanceController = TextEditingController();
  bool isSaving = false;

  bool get _isCreditCard => widget.type == 'credit_card';

  Future<void> _saveAccount() async {
    if (nameController.text.trim().isEmpty) return;

    setState(() => isSaving = true);

    final account = AccountModel(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      name: nameController.text.trim(),
      balance: double.tryParse(balanceController.text) ?? 0,
      type: widget.type,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final id = await FirestoreService.instance.addAccount(account);

    if (!mounted) return;
    Navigator.pop(context, account.copyWith(id: id));
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(
              _isCreditCard ? 'Add Credit Card' : 'Create Account',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _isCreditCard ? 'Card Name' : 'Account Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              readOnly: true,
              showCursor: true,
              onTap: () => showCalculatorKeypad(context, controller: balanceController),
              decoration: InputDecoration(
                labelText: _isCreditCard ? 'Current Balance' : 'Initial Balance',
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving || nameController.text.trim().isEmpty ? null : _saveAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
