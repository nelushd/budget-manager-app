import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../models/activity_entry.dart';
import '../models/category_model.dart';
import '../models/lending_model.dart';
import '../models/lending_repayment_model.dart';
import '../models/loan_model.dart';
import '../models/loan_payment_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import 'category_icon.dart';
import 'period_calculator.dart';

Future<List<ActivityEntry>> loadActivityFeed(FirestoreService service) async {
  final results = await Future.wait([
    service.getTransactions(),
    service.getAccounts(),
    service.getCategoriesByType('income'),
    service.getCategoriesByType('expense'),
    service.getLoans(),
    service.getLendings(),
  ]);

  final transactions = results[0] as List<TransactionModel>;
  final accounts = results[1] as List<AccountModel>;
  final incomeCategories = results[2] as List<CategoryModel>;
  final expenseCategories = results[3] as List<CategoryModel>;
  final loans = results[4] as List<LoanModel>;
  final lendings = results[5] as List<LendingModel>;

  final accountsById = {
    for (final account in accounts)
      if (account.id != null) account.id!: account,
  };
  final categoriesById = {
    for (final category in [...incomeCategories, ...expenseCategories])
      if (category.id != null) category.id!: category,
  };

  final loanPaymentLists = await Future.wait([
    for (final loan in loans)
      if (loan.id != null) service.getLoanPayments(loan.id!),
  ]);
  final loanPaymentsByLoanId = <String, List<LoanPaymentModel>>{
    for (var i = 0; i < loanPaymentLists.length; i++)
      loans.where((loan) => loan.id != null).toList()[i].id!:
          loanPaymentLists[i],
  };

  final lendingRepaymentLists = await Future.wait([
    for (final lending in lendings)
      if (lending.id != null) service.getLendingRepayments(lending.id!),
  ]);
  final lendingRepaymentsByLendingId = <String, List<LendingRepaymentModel>>{
    for (var i = 0; i < lendingRepaymentLists.length; i++)
      lendings.where((lending) => lending.id != null).toList()[i].id!:
          lendingRepaymentLists[i],
  };

  return buildActivityFeed(
    transactions: transactions,
    categoriesById: categoriesById,
    accountsById: accountsById,
    loans: loans,
    loanPaymentsByLoanId: loanPaymentsByLoanId,
    lendings: lendings,
    lendingRepaymentsByLendingId: lendingRepaymentsByLendingId,
  );
}

/// Merges real transactions with loan/lending cash movements into one
/// timeline. Loans and lendings move real money in/out of accounts (a new
/// loan credits an account, a lending payout debits one) but are never
/// recorded as `income`/`expense` transactions, so a feed built from
/// transactions alone would silently miss them.
List<ActivityEntry> buildActivityFeed({
  required List<TransactionModel> transactions,
  required Map<String, CategoryModel> categoriesById,
  required Map<String, AccountModel> accountsById,
  required List<LoanModel> loans,
  required Map<String, List<LoanPaymentModel>> loanPaymentsByLoanId,
  required List<LendingModel> lendings,
  required Map<String, List<LendingRepaymentModel>>
  lendingRepaymentsByLendingId,
}) {
  final entries = <ActivityEntry>[];

  for (final transaction in transactions) {
    final category = categoriesById[transaction.categoryId];
    final account = accountsById[transaction.accountId];

    entries.add(
      ActivityEntry(
        title: category?.name ?? 'Uncategorized',
        subtitle: account?.name ?? '',
        note: transaction.note,
        amount: transaction.amount,
        isInflow: transaction.type == 'income',
        kind: transaction.type,
        date: PeriodCalculator.parseDate(transaction.date),
        accountName: account?.name ?? '',
        icon: getCategoryIcon(category?.iconName ?? 'category'),
        transaction: transaction,
      ),
    );
  }

  for (final loan in loans) {
    final account = loan.accountId != null
        ? accountsById[loan.accountId]
        : null;

    if (account != null) {
      entries.add(
        ActivityEntry(
          title: 'Loan - ${loan.name}',
          subtitle: account.name,
          note: 'Loan received: ${loan.name}',
          amount: loan.totalAmount,
          isInflow: true,
          kind: 'loan',
          date: PeriodCalculator.parseDate(loan.startDate),
          accountName: account.name,
          icon: Icons.account_balance,
        ),
      );
    }

    for (final payment
        in loanPaymentsByLoanId[loan.id] ?? const <LoanPaymentModel>[]) {
      entries.add(
        ActivityEntry(
          title: 'Loan Payment - ${loan.name}',
          subtitle: account?.name ?? '',
          note: 'Payment for: ${loan.name}',
          amount: payment.amount,
          isInflow: false,
          kind: 'loan',
          date: PeriodCalculator.parseDate(payment.date),
          accountName: account?.name ?? '',
          icon: Icons.account_balance,
        ),
      );
    }
  }

  for (final lending in lendings) {
    final account = lending.accountId != null
        ? accountsById[lending.accountId]
        : null;

    if (account != null) {
      entries.add(
        ActivityEntry(
          title: 'Lending - ${lending.name}',
          subtitle: account.name,
          note: 'Lent to: ${lending.name}',
          amount: lending.totalAmount,
          isInflow: false,
          kind: 'lending',
          date: PeriodCalculator.parseDate(lending.startDate),
          accountName: account.name,
          icon: Icons.handshake_outlined,
        ),
      );
    }

    for (final repayment
        in lendingRepaymentsByLendingId[lending.id] ??
            const <LendingRepaymentModel>[]) {
      entries.add(
        ActivityEntry(
          title: 'Receive Lending - ${lending.name}',
          subtitle: account?.name ?? '',
          note: 'Payment received for: ${lending.name}',
          amount: repayment.amount,
          isInflow: true,
          kind: 'lending',
          date: PeriodCalculator.parseDate(repayment.date),
          accountName: account?.name ?? '',
          icon: Icons.handshake_outlined,
        ),
      );
    }
  }

  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
}
