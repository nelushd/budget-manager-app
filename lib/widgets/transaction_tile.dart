import 'package:flutter/material.dart';

class TransactionTile extends StatelessWidget {
  final String title;
  final String category;
  final double amount;
  final String type; // 'income' or 'expense'
  final DateTime date;

  const TransactionTile({
    Key? key,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isExpense = type == 'expense';
    final amountColor = isExpense ? Colors.red : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: amountColor.withOpacity(0.2),
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: amountColor,
        ),
      ),
      title: Text(title),
      subtitle: Text(category),
      trailing: Text(
        '${isExpense ? '-' : '+'}\$$amount',
        style: TextStyle(
          color: amountColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
