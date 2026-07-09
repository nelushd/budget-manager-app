import 'package:flutter/material.dart';

import '../../data/database_helper.dart';
import '../../models/account_model.dart';
import 'create_account_page.dart';

class AccountsPage extends StatefulWidget {
  final bool openCreate;

  const AccountsPage({super.key, this.openCreate = false});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<AccountModel> accounts = [];

  @override
  void initState() {
    super.initState();
    loadAccounts();
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openCreatePage();
      });
    }
  }

  Future<void> loadAccounts() async {
    accounts = await DatabaseHelper.instance.getAccounts();
    setState(() {});
  }

  Future<void> openCreatePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateAccountPage(),
      ),
    );

    loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Accounts"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openCreatePage,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final account = accounts[index];

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.account_balance_wallet),
              ),
              title: Text(account.name),
              subtitle: Text(account.currency),
              trailing: Text(
                "Rs. ${account.balance.toStringAsFixed(2)}",
              ),
            ),
          );
        },
      ),
    );
  }
}