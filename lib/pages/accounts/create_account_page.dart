import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/finance/calculator_keypad.dart';
import '../../widgets/finance/dark_finance_widgets.dart';

/// Opens account creation as a bottom sheet — scrollable and sized to its
/// content instead of a full page push. Returns the created account, or
/// null if dismissed without saving. Regular accounts use one shared account
/// type and icon; credit cards have their own dedicated creation flow.
Future<AccountModel?> showCreateAccountSheet(
  BuildContext context,
) {
  return showModalBottomSheet<AccountModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinanceDark.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: const _CreateAccountSheetBody(),
      );
    },
  );
}

class _CreateAccountSheetBody extends StatefulWidget {
  const _CreateAccountSheetBody();

  @override
  State<_CreateAccountSheetBody> createState() => _CreateAccountSheetBodyState();
}

class _CreateAccountSheetBodyState extends State<_CreateAccountSheetBody> {
  final nameController = TextEditingController();
  final balanceController = TextEditingController();
  bool isSaving = false;

  Future<void> _saveAccount() async {
    if (nameController.text.trim().isEmpty) return;

    setState(() => isSaving = true);

    final account = AccountModel(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      name: nameController.text.trim(),
      balance: double.tryParse(balanceController.text) ?? 0,
      type: 'account',
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
                decoration: BoxDecoration(color: FinanceDark.divider, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(
              'Create Account',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: FinanceDark.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: FinanceDark.textPrimary),
              decoration: InputDecoration(
                labelText: 'Account Name',
                labelStyle: const TextStyle(color: FinanceDark.textSecondary),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FinanceDark.divider)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FinanceDark.accent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              readOnly: true,
              showCursor: true,
              onTap: () => showCalculatorKeypad(context, controller: balanceController, dark: true),
              style: const TextStyle(color: FinanceDark.textPrimary),
              decoration: InputDecoration(
                labelText: 'Initial Balance',
                labelStyle: const TextStyle(color: FinanceDark.textSecondary),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FinanceDark.divider)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FinanceDark.accent)),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving || nameController.text.trim().isEmpty ? null : _saveAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinanceDark.accent,
                  foregroundColor: FinanceDark.bg,
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
