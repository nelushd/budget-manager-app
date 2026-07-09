import 'package:flutter/material.dart';

import '../../data/database_helper.dart';
import '../../models/account_model.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final nameController = TextEditingController();
  final balanceController = TextEditingController();

  Future<void> saveAccount() async {
    if (nameController.text.trim().isEmpty) return;

    final account = AccountModel(
      name: nameController.text.trim(),
      balance: double.tryParse(balanceController.text) ?? 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseHelper.instance.insertAccount(account);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Account Name",
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Initial Balance",
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveAccount,
                child: const Text("Save"),
              ),
            )
          ],
        ),
      ),
    );
  }
}