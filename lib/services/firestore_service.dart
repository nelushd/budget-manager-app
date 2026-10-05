import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/credit_card_payment_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/recurring_payment_model.dart';
import '../models/lending_model.dart';
import '../models/lending_repayment_model.dart';
import '../models/loan_model.dart';
import '../models/loan_payment_model.dart';
import '../models/transfer_model.dart';
import '../utils/frequency.dart';
import '../utils/period_calculator.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _accounts {
    return _firestore.collection('accounts');
  }

  CollectionReference<Map<String, dynamic>> get _categories {
    return _firestore.collection('categories');
  }

  CollectionReference<Map<String, dynamic>> get _transactions {
    return _firestore.collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> get _creditCardPayments {
    return _firestore.collection('creditCardPayments');
  }

  CollectionReference<Map<String, dynamic>> get _budgets {
    return _firestore.collection('budgets');
  }

  CollectionReference<Map<String, dynamic>> get _recurringExpenses {
    return _firestore.collection('recurringExpenses');
  }

  CollectionReference<Map<String, dynamic>> get _recurringPayments {
    return _firestore.collection('recurringPayments');
  }

  CollectionReference<Map<String, dynamic>> get _lendings {
    return _firestore.collection('lendings');
  }

  CollectionReference<Map<String, dynamic>> get _lendingRepayments {
    return _firestore.collection('lendingRepayments');
  }

  CollectionReference<Map<String, dynamic>> get _loans {
    return _firestore.collection('loans');
  }

  CollectionReference<Map<String, dynamic>> get _loanPayments {
    return _firestore.collection('loanPayments');
  }

  CollectionReference<Map<String, dynamic>> get _transfers {
    return _firestore.collection('transfers');
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================
  // ACCOUNTS
  // ============================================================

  Future<String> addAccount(AccountModel account) async {
    if (account.name.trim().isEmpty) {
      throw ArgumentError('Account name cannot be empty.');
    }

    if (account.isDefault) {
      await _removeDefaultFromOtherAccounts();
    }

    final document = await _accounts.add(account.toFirestore());
    return document.id;
  }

  Future<List<AccountModel>> getAccounts() async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _accounts;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.get();

    final accounts = snapshot.docs.map((document) {
      return AccountModel.fromFirestore(
        document.id,
        document.data(),
      );
    }).toList();

    accounts.sort((first, second) {
      if (first.isDefault != second.isDefault) {
        return first.isDefault ? -1 : 1;
      }

      return first.createdAt.compareTo(second.createdAt);
    });

    return accounts;
  }

  Stream<List<AccountModel>> watchAccounts() {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _accounts;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      final accounts = snapshot.docs.map((document) {
        return AccountModel.fromFirestore(
          document.id,
          document.data(),
        );
      }).toList();

      accounts.sort((first, second) {
        if (first.isDefault != second.isDefault) {
          return first.isDefault ? -1 : 1;
        }

        return first.createdAt.compareTo(second.createdAt);
      });

      return accounts;
    });
  }

  Future<AccountModel?> getAccountById(String accountId) async {
    if (accountId.trim().isEmpty) {
      return null;
    }

    final document = await _accounts.doc(accountId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return AccountModel.fromFirestore(
      document.id,
      document.data()!,
    );
  }

  Future<void> updateAccount(AccountModel account) async {
    final accountId = account.id;

    if (accountId == null || accountId.isEmpty) {
      throw ArgumentError('Account ID is required.');
    }

    if (account.isDefault) {
      await _removeDefaultFromOtherAccounts(
        excludedAccountId: accountId,
      );
    }

    await _accounts.doc(accountId).update(account.toFirestore());
  }

  Future<void> makeCreditCardPayment({
    required String cardId,
    required String accountId,
    required double amount,
  }) async {
    if (cardId.trim().isEmpty || accountId.trim().isEmpty) {
      throw ArgumentError('Card and payment account are required.');
    }
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    if (cardId == accountId) {
      throw ArgumentError('A credit card cannot pay itself.');
    }

    final cardRef = _accounts.doc(cardId);
    final accountRef = _accounts.doc(accountId);
    final paymentRef = _creditCardPayments.doc();
    final now = DateTime.now();
    await _firestore.runTransaction((transaction) async {
      final cardSnapshot = await transaction.get(cardRef);
      final accountSnapshot = await transaction.get(accountRef);
      if (!cardSnapshot.exists || cardSnapshot.data() == null) {
        throw StateError('The credit card does not exist.');
      }
      if (!accountSnapshot.exists || accountSnapshot.data() == null) {
        throw StateError('The selected payment account does not exist.');
      }

      final cardData = cardSnapshot.data()!;
      final accountData = accountSnapshot.data()!;
      if (cardData['userId']?.toString() != _currentUserId ||
          accountData['userId']?.toString() != _currentUserId) {
        throw StateError('The selected account is not yours.');
      }
      final cardBalance = (cardData['balance'] as num?)?.toDouble() ?? 0;
      final accountBalance = (accountData['balance'] as num?)?.toDouble() ?? 0;
      if (amount > cardBalance) {
        throw StateError('Payment cannot exceed the credit card balance.');
      }
      if (amount > accountBalance) {
        throw StateError('The selected account does not have enough balance.');
      }

      final payment = CreditCardPaymentModel(
        userId: _currentUserId ?? '',
        cardId: cardId,
        accountId: accountId,
        amount: amount,
        date: PeriodCalculator.formatDate(now),
        time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        createdAt: now.millisecondsSinceEpoch,
      );
      transaction.set(paymentRef, payment.toFirestore());
      transaction.update(cardRef, {'balance': cardBalance - amount});
      transaction.update(accountRef, {'balance': accountBalance - amount});
    });
  }

  Future<List<CreditCardPaymentModel>> getCreditCardPayments(String cardId) async {
    final snapshot = await _creditCardPayments
        .where('userId', isEqualTo: _currentUserId)
        .where('cardId', isEqualTo: cardId)
        .get();
    final payments = snapshot.docs
        .map((document) => CreditCardPaymentModel.fromFirestore(document.id, document.data()))
        .toList();
    payments.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return payments;
  }

  Future<void> deleteAccount(String accountId) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError('Account ID is required.');
    }

    final relatedTransactions = await _transactions
        .where('userId', isEqualTo: _currentUserId)
        .where('accountId', isEqualTo: accountId)
        .limit(1)
        .get();

    if (relatedTransactions.docs.isNotEmpty) {
      throw StateError(
        'This account has transactions and cannot be deleted.',
      );
    }

    await _accounts.doc(accountId).delete();
  }

  Future<void> setDefaultAccount(String accountId) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError('Account ID is required.');
    }

    final batch = _firestore.batch();
    final snapshot =
        await _accounts.where('userId', isEqualTo: _currentUserId).get();

    bool accountFound = false;

    for (final document in snapshot.docs) {
      final isSelectedAccount = document.id == accountId;

      if (isSelectedAccount) {
        accountFound = true;
      }

      batch.update(
        document.reference,
        {'isDefault': isSelectedAccount},
      );
    }

    if (!accountFound) {
      throw StateError('The selected account does not exist.');
    }

    await batch.commit();
  }

  Future<void> _removeDefaultFromOtherAccounts({
    String? excludedAccountId,
  }) async {
    final snapshot = await _accounts
        .where('userId', isEqualTo: _currentUserId)
        .where('isDefault', isEqualTo: true)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final document in snapshot.docs) {
      if (document.id != excludedAccountId) {
        batch.update(
          document.reference,
          {'isDefault': false},
        );
      }
    }

    await batch.commit();
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  Future<String> addCategory(CategoryModel category) async {
    if (category.name.trim().isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }

    if (category.type != 'income' && category.type != 'expense') {
      throw ArgumentError(
        'Category type must be income or expense.',
      );
    }

    final document = await _categories.add(
      category.toFirestore(),
    );

    return document.id;
  }

  static const String kGlobalCategoryUserId = '__global__';

  static const List<Map<String, String>> _additionalGlobalIncomeCategories = [
    {'name': 'Business Income', 'iconName': 'business'},
    {'name': 'Investment Return', 'iconName': 'trending_up'},
    {'name': 'Rental Income', 'iconName': 'home_work'},
    {'name': 'Side Hustles', 'iconName': 'work_history'},
    {'name': 'Dividends', 'iconName': 'account_balance'},
    {'name': 'Refunds', 'iconName': 'currency_exchange'},
    {'name': 'Bank Interest', 'iconName': 'percent'},
  ];

  static const List<Map<String, String>> _globalExpenseCategories = [
    {'name': 'Electricity', 'iconName': 'electric_bolt'},
    {'name': 'Rent', 'iconName': 'home'},
    {'name': 'Give Lending', 'iconName': 'account_balance'},
    {'name': 'Water', 'iconName': 'water_drop'},
    {'name': 'Gas', 'iconName': 'local_fire_department'},
    {'name': 'Garbage', 'iconName': 'delete_outline'},
    {'name': 'Groceries', 'iconName': 'shopping_cart'},
    {'name': 'Phone', 'iconName': 'smartphone'},
    {'name': 'Internet', 'iconName': 'wifi'},
    {'name': 'TV', 'iconName': 'tv'},
    {'name': 'Domestic Help', 'iconName': 'cleaning_services'},
    {'name': 'Transport', 'iconName': 'directions_bus'},
    {'name': 'Fuel', 'iconName': 'local_gas_station'},
    {'name': 'Vehicle', 'iconName': 'directions_car'},
    {'name': 'Parking', 'iconName': 'local_parking'},
    {'name': 'Tuition', 'iconName': 'school'},
    {'name': 'Books', 'iconName': 'menu_book'},
    {'name': 'Dental', 'iconName': 'medical_services'},
    {'name': 'Clothing', 'iconName': 'checkroom'},
    {'name': 'Salon', 'iconName': 'content_cut'},
    {'name': 'Gym', 'iconName': 'fitness_center'},
    {'name': 'Dining', 'iconName': 'restaurant'},
    {'name': 'Movies', 'iconName': 'movie'},
    {'name': 'Travel', 'iconName': 'flight'},
    {'name': 'Hobbies', 'iconName': 'palette'},
    {'name': 'Credit Cards', 'iconName': 'credit_card'},
    {'name': 'Savings', 'iconName': 'savings_alt'},
    {'name': 'Gifts', 'iconName': 'gifts'},
    {'name': 'Emergency', 'iconName': 'warning_amber'},
    {'name': 'Subs', 'iconName': 'subscriptions'},
    {'name': 'Credit Card Interest', 'iconName': 'credit_card'},
    {'name': 'Bank Charges', 'iconName': 'bank_charges'},
    {'name': 'Goal Saving', 'iconName': 'savings_alt'},
  ];

  Future<void> _ensureAdditionalGlobalIncomeCategories() async {
    if (_currentUserId == null) return;

    final snapshot = await _categories
        .where('type', isEqualTo: 'income')
        .where('userId', isEqualTo: kGlobalCategoryUserId)
        .get();
    final existingNames = {
      for (final document in snapshot.docs)
        document.data()['name']?.toString().trim().toLowerCase(),
    };
    final missing = _additionalGlobalIncomeCategories.where(
      (category) => !existingNames.contains(category['name']!.toLowerCase()),
    );

    if (missing.isEmpty) return;

    final batch = _firestore.batch();
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    for (final category in missing) {
      final documentId = category['name']!
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final reference = _categories.doc('global_income_$documentId');
      batch.set(reference, {
        'userId': kGlobalCategoryUserId,
        'name': category['name'],
        'type': 'income',
        'iconName': category['iconName'],
        'isDefault': true,
        'createdAt': createdAt,
      });
    }
    await batch.commit();
  }

  Future<void> _ensureGlobalExpenseCategories() async {
    if (_currentUserId == null) return;

    final snapshot = await _categories
        .where('type', isEqualTo: 'expense')
        .where('userId', isEqualTo: kGlobalCategoryUserId)
        .get();
    final existingNames = {
      for (final document in snapshot.docs)
        document.data()['name']?.toString().trim().toLowerCase(),
    };
    final missing = _globalExpenseCategories.where(
      (category) => !existingNames.contains(category['name']!.toLowerCase()),
    );

    if (missing.isEmpty) return;

    final batch = _firestore.batch();
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    for (final category in missing) {
      final documentId = category['name']!
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final reference = _categories.doc('global_expense_$documentId');
      batch.set(reference, {
        'userId': kGlobalCategoryUserId,
        'name': category['name'],
        'type': 'expense',
        'iconName': category['iconName'],
        'isDefault': true,
        'createdAt': createdAt,
      });
    }
    await batch.commit();
  }

  Future<List<CategoryModel>> getCategoriesByType(
    String type,
  ) async {
    if (type == 'income') {
      await _ensureAdditionalGlobalIncomeCategories();
    } else if (type == 'expense') {
      await _ensureGlobalExpenseCategories();
    }

    final userId = _currentUserId;

    final ownQuery = userId == null
        ? _categories.where('type', isEqualTo: type)
        : _categories.where('type', isEqualTo: type).where('userId', isEqualTo: userId);
    final globalQuery = _categories
        .where('type', isEqualTo: type)
        .where('userId', isEqualTo: kGlobalCategoryUserId);

    final results = await Future.wait([ownQuery.get(), globalQuery.get()]);

    final ownCategories = results[0].docs.map((document) {
      return CategoryModel.fromFirestore(document.id, document.data());
    }).toList();

    final globalCategories = results[1].docs.map((document) {
      return CategoryModel.fromFirestore(document.id, document.data());
    }).toList();

    // A user's own category always wins over a same-named global one —
    // preserves continuity for any account that already had its own copy
    // (with real transaction/budget history attached) before the shared
    // list existed.
    final ownNames = {for (final c in ownCategories) c.name};
    final categories = [
      ...ownCategories,
      ...globalCategories.where((c) => !ownNames.contains(c.name)),
    ];

    categories.sort((first, second) {
      if (first.isDefault != second.isDefault) {
        return first.isDefault ? -1 : 1;
      }

      return first.createdAt.compareTo(second.createdAt);
    });

    return categories;
  }

  Stream<List<CategoryModel>> watchCategoriesByType(
    String type,
  ) {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query =
        _categories.where('type', isEqualTo: type);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      final categories = snapshot.docs.map((document) {
        return CategoryModel.fromFirestore(
          document.id,
          document.data(),
        );
      }).toList();

      categories.sort((first, second) {
        if (first.isDefault != second.isDefault) {
          return first.isDefault ? -1 : 1;
        }

        return first.createdAt.compareTo(second.createdAt);
      });

      return categories;
    });
  }

  Future<CategoryModel?> getCategoryById(
    String categoryId,
  ) async {
    if (categoryId.trim().isEmpty) {
      return null;
    }

    final document = await _categories.doc(categoryId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return CategoryModel.fromFirestore(
      document.id,
      document.data()!,
    );
  }

  Future<void> updateCategory(CategoryModel category) async {
    final categoryId = category.id;

    if (categoryId == null || categoryId.isEmpty) {
      throw ArgumentError('Category ID is required.');
    }

    await _categories.doc(categoryId).update(
          category.toFirestore(),
        );
  }

  Future<void> deleteCategory(String categoryId) async {
    if (categoryId.trim().isEmpty) {
      throw ArgumentError('Category ID is required.');
    }

    final relatedTransactions = await _transactions
        .where('userId', isEqualTo: _currentUserId)
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();

    if (relatedTransactions.docs.isNotEmpty) {
      throw StateError(
        'This category has transactions and cannot be deleted.',
      );
    }

    await _categories.doc(categoryId).delete();
  }

  double _signedBalanceChange(
    String? accountType,
    String transactionType,
    double amount,
  ) {
    final isIncome = transactionType == 'income';
    final increasesBalance =
        accountType == 'credit_card' ? !isIncome : isIncome;
    return increasesBalance ? amount : -amount;
  }

  Future<String> addTransaction(
    TransactionModel transactionModel,
  ) async {
    if (transactionModel.accountId.trim().isEmpty) {
      throw ArgumentError('Account ID is required.');
    }

    if (transactionModel.categoryId.trim().isEmpty) {
      throw ArgumentError('Category ID is required.');
    }

    if (transactionModel.amount <= 0) {
      throw ArgumentError(
        'Transaction amount must be greater than zero.',
      );
    }

    final transactionReference = _transactions.doc();
    final accountReference = _accounts.doc(
      transactionModel.accountId,
    );

    await _firestore.runTransaction((firestoreTransaction) async {
      final accountSnapshot = await firestoreTransaction.get(
        accountReference,
      );

      if (!accountSnapshot.exists ||
          accountSnapshot.data() == null) {
        throw StateError('The selected account does not exist.');
      }

      final accountData = accountSnapshot.data()!;
      final currentBalance =
          (accountData['balance'] as num?)?.toDouble() ?? 0;

      final balanceChange = _signedBalanceChange(
        accountData['type'] as String?,
        transactionModel.type,
        transactionModel.amount,
      );

      final newBalance = currentBalance + balanceChange;

      firestoreTransaction.update(
        accountReference,
        {'balance': newBalance},
      );

      firestoreTransaction.set(
        transactionReference,
        transactionModel.toFirestore(),
      );
    });

    return transactionReference.id;
  }

  Future<List<TransactionModel>> getTransactions() async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _transactions;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.get();

    final transactions = snapshot.docs.map((document) {
      return TransactionModel.fromFirestore(
        document.id,
        document.data(),
      );
    }).toList();

    transactions.sort(
      (first, second) =>
          second.createdAt.compareTo(first.createdAt),
    );

    return transactions;
  }

  Future<List<TransactionModel>> getTransactionsByType(
    String type,
  ) async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query =
        _transactions.where('type', isEqualTo: type);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.get();

    final transactions = snapshot.docs.map((document) {
      return TransactionModel.fromFirestore(
        document.id,
        document.data(),
      );
    }).toList();

    transactions.sort(
      (first, second) =>
          second.createdAt.compareTo(first.createdAt),
    );

    return transactions;
  }

  Future<List<TransactionModel>> getTransactionsByAccount(
    String accountId,
  ) async {
    final snapshot = await _transactions
        .where('userId', isEqualTo: _currentUserId)
        .where('accountId', isEqualTo: accountId)
        .get();

    final transactions = snapshot.docs.map((document) {
      return TransactionModel.fromFirestore(
        document.id,
        document.data(),
      );
    }).toList();

    transactions.sort(
      (first, second) =>
          second.createdAt.compareTo(first.createdAt),
    );

    return transactions;
  }

  Stream<List<TransactionModel>> watchTransactions() {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _transactions;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      final transactions = snapshot.docs.map((document) {
        return TransactionModel.fromFirestore(
          document.id,
          document.data(),
        );
      }).toList();

      transactions.sort(
        (first, second) =>
            second.createdAt.compareTo(first.createdAt),
      );

      return transactions;
    });
  }

  Future<TransactionModel?> getTransactionById(
    String transactionId,
  ) async {
    if (transactionId.trim().isEmpty) {
      return null;
    }

    final document = await _transactions
        .doc(transactionId)
        .get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return TransactionModel.fromFirestore(
      document.id,
      document.data()!,
    );
  }

  Future<void> updateTransaction(
    TransactionModel updatedTransaction,
  ) async {
    final transactionId = updatedTransaction.id;

    if (transactionId == null || transactionId.isEmpty) {
      throw ArgumentError('Transaction ID is required.');
    }

    final transactionReference = _transactions.doc(
      transactionId,
    );

    await _firestore.runTransaction((firestoreTransaction) async {
      final oldTransactionSnapshot =
          await firestoreTransaction.get(transactionReference);

      if (!oldTransactionSnapshot.exists ||
          oldTransactionSnapshot.data() == null) {
        throw StateError('The transaction does not exist.');
      }

      final oldTransaction = TransactionModel.fromFirestore(
        oldTransactionSnapshot.id,
        oldTransactionSnapshot.data()!,
      );

      final oldAccountReference = _accounts.doc(
        oldTransaction.accountId,
      );

      final newAccountReference = _accounts.doc(
        updatedTransaction.accountId,
      );

      if (oldTransaction.accountId ==
          updatedTransaction.accountId) {
        final accountSnapshot = await firestoreTransaction.get(
          oldAccountReference,
        );

        if (!accountSnapshot.exists ||
            accountSnapshot.data() == null) {
          throw StateError('The selected account does not exist.');
        }

        final currentBalance =
            (accountSnapshot.data()!['balance'] as num?)
                    ?.toDouble() ??
                0;

        final accountType = accountSnapshot.data()!['type'] as String?;

        final reversedOldAmount = -_signedBalanceChange(
          accountType,
          oldTransaction.type,
          oldTransaction.amount,
        );

        final appliedNewAmount = _signedBalanceChange(
          accountType,
          updatedTransaction.type,
          updatedTransaction.amount,
        );

        firestoreTransaction.update(
          oldAccountReference,
          {
            'balance':
                currentBalance +
                reversedOldAmount +
                appliedNewAmount,
          },
        );
      } else {
        final oldAccountSnapshot =
            await firestoreTransaction.get(
          oldAccountReference,
        );

        final newAccountSnapshot =
            await firestoreTransaction.get(
          newAccountReference,
        );

        if (!oldAccountSnapshot.exists ||
            oldAccountSnapshot.data() == null) {
          throw StateError('The old account does not exist.');
        }

        if (!newAccountSnapshot.exists ||
            newAccountSnapshot.data() == null) {
          throw StateError('The new account does not exist.');
        }

        final oldAccountBalance =
            (oldAccountSnapshot.data()!['balance'] as num?)
                    ?.toDouble() ??
                0;

        final newAccountBalance =
            (newAccountSnapshot.data()!['balance'] as num?)
                    ?.toDouble() ??
                0;

        final reversedOldAmount = -_signedBalanceChange(
          oldAccountSnapshot.data()!['type'] as String?,
          oldTransaction.type,
          oldTransaction.amount,
        );

        final appliedNewAmount = _signedBalanceChange(
          newAccountSnapshot.data()!['type'] as String?,
          updatedTransaction.type,
          updatedTransaction.amount,
        );

        firestoreTransaction.update(
          oldAccountReference,
          {
            'balance':
                oldAccountBalance + reversedOldAmount,
          },
        );

        firestoreTransaction.update(
          newAccountReference,
          {
            'balance':
                newAccountBalance + appliedNewAmount,
          },
        );
      }

      firestoreTransaction.update(
        transactionReference,
        updatedTransaction.toFirestore(),
      );
    });
  }

  Future<void> deleteTransaction(
    String transactionId,
  ) async {
    if (transactionId.trim().isEmpty) {
      throw ArgumentError('Transaction ID is required.');
    }

    final transactionReference = _transactions.doc(
      transactionId,
    );

    await _firestore.runTransaction((firestoreTransaction) async {
      final transactionSnapshot =
          await firestoreTransaction.get(transactionReference);

      if (!transactionSnapshot.exists ||
          transactionSnapshot.data() == null) {
        throw StateError('The transaction does not exist.');
      }

      final existingTransaction =
          TransactionModel.fromFirestore(
        transactionSnapshot.id,
        transactionSnapshot.data()!,
      );

      final accountReference = _accounts.doc(
        existingTransaction.accountId,
      );

      final accountSnapshot = await firestoreTransaction.get(
        accountReference,
      );

      if (!accountSnapshot.exists ||
          accountSnapshot.data() == null) {
        throw StateError('The related account does not exist.');
      }

      final currentBalance =
          (accountSnapshot.data()!['balance'] as num?)
                  ?.toDouble() ??
              0;

      final reversedAmount = -_signedBalanceChange(
        accountSnapshot.data()!['type'] as String?,
        existingTransaction.type,
        existingTransaction.amount,
      );

      firestoreTransaction.update(
        accountReference,
        {'balance': currentBalance + reversedAmount},
      );

      firestoreTransaction.delete(transactionReference);
    });
  }

  // ============================================================
  // BUDGETS
  // ============================================================

  Future<String> addBudget(BudgetModel budget) async {
    if (budget.budgetName.trim().isEmpty) {
      throw ArgumentError('Budget name cannot be empty.');
    }

    final document = await _budgets.add(budget.toFirestore());
    return document.id;
  }

  Future<List<BudgetModel>> getBudgets() async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _budgets;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.get();

    final budgets = snapshot.docs.map((document) {
      return BudgetModel.fromFirestore(
        document.id,
        document.data(),
      );
    }).toList();

    budgets.sort((first, second) => second.createdDate.compareTo(first.createdDate));
    return budgets;
  }

  Stream<List<BudgetModel>> watchBudgets() {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _budgets;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      final budgets = snapshot.docs.map((document) {
        return BudgetModel.fromFirestore(
          document.id,
          document.data(),
        );
      }).toList();

      budgets.sort((first, second) => second.createdDate.compareTo(first.createdDate));
      return budgets;
    });
  }

  Future<BudgetModel?> getBudgetById(String budgetId) async {
    if (budgetId.trim().isEmpty) {
      return null;
    }

    final document = await _budgets.doc(budgetId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return BudgetModel.fromFirestore(document.id, document.data()!);
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final budgetId = budget.id;

    if (budgetId == null || budgetId.isEmpty) {
      throw ArgumentError('Budget ID is required.');
    }

    await _budgets.doc(budgetId).update(budget.toFirestore());
  }

  Future<void> deleteBudget(String budgetId) async {
    if (budgetId.trim().isEmpty) {
      throw ArgumentError('Budget ID is required.');
    }

    await _budgets.doc(budgetId).delete();
  }
  Future<double> getSpentForCategoryInRange(
    String categoryId,
    String start,
    String end,
  ) async {
    final snapshot = await _transactions
        .where('userId', isEqualTo: _currentUserId)
        .where('type', isEqualTo: 'expense')
        .where('categoryId', isEqualTo: categoryId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    double total = 0;
    for (final document in snapshot.docs) {
      total += (document.data()['amount'] as num?)?.toDouble() ?? 0;
    }

    return total;
  }

  Future<List<TransactionModel>> getTransactionsForCategoryInRange(
    String categoryId,
    String start,
    String end,
  ) async {
    final snapshot = await _transactions
        .where('userId', isEqualTo: _currentUserId)
        .where('type', isEqualTo: 'expense')
        .where('categoryId', isEqualTo: categoryId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    return snapshot.docs
        .map((document) =>
            TransactionModel.fromFirestore(document.id, document.data()))
        .toList();
  }

  // ============================================================
  // RECURRING EXPENSES
  // ============================================================

  Future<String> addRecurringExpense(RecurringExpenseModel expense) async {
    if (expense.name.trim().isEmpty) {
      throw ArgumentError('Recurring expense name cannot be empty.');
    }

    final document = await _recurringExpenses.add(expense.toFirestore());
    return document.id;
  }

  Future<List<RecurringExpenseModel>> getRecurringExpenses() async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _recurringExpenses;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.get();

    final expenses = snapshot.docs
        .map((document) => RecurringExpenseModel.fromFirestore(document.id, document.data()))
        .toList();

    expenses.sort((first, second) => first.nextDueDate.compareTo(second.nextDueDate));
    return expenses;
  }

  Stream<List<RecurringExpenseModel>> watchRecurringExpenses() {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _recurringExpenses;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      final expenses = snapshot.docs
          .map((document) => RecurringExpenseModel.fromFirestore(document.id, document.data()))
          .toList();

      expenses.sort((first, second) => first.nextDueDate.compareTo(second.nextDueDate));
      return expenses;
    });
  }

  Future<RecurringExpenseModel?> getRecurringExpenseById(String expenseId) async {
    if (expenseId.trim().isEmpty) {
      return null;
    }

    final document = await _recurringExpenses.doc(expenseId).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return RecurringExpenseModel.fromFirestore(document.id, document.data()!);
  }

  Future<void> updateRecurringExpense(RecurringExpenseModel expense) async {
    final expenseId = expense.id;

    if (expenseId == null || expenseId.isEmpty) {
      throw ArgumentError('Recurring expense ID is required.');
    }

    await _recurringExpenses.doc(expenseId).update(expense.toFirestore());
  }

  Future<void> deleteRecurringExpense(String expenseId) async {
    if (expenseId.trim().isEmpty) {
      throw ArgumentError('Recurring expense ID is required.');
    }

    await _recurringExpenses.doc(expenseId).delete();
  }

  Future<List<RecurringPaymentModel>> getRecurringPayments(String expenseId) async {
    final snapshot = await _recurringPayments.where('expenseId', isEqualTo: expenseId).get();

    final payments = snapshot.docs
        .map((document) => RecurringPaymentModel.fromFirestore(document.id, document.data()))
        .toList();

    payments.sort((first, second) => second.paymentDate.compareTo(first.paymentDate));
    return payments;
  }

  /// Records this cycle's payment as a real transaction (via [addTransaction],
  /// so the account balance updates exactly like a manual expense would),
  /// logs it in `recurringPayments`, and advances `nextDueDate` by the
  /// expense's frequency.
  Future<void> markRecurringPaid(String expenseId, String accountId) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError('Payment account is required.');
    }

    final expense = await getRecurringExpenseById(expenseId);
    if (expense == null) {
      throw StateError('The recurring expense does not exist.');
    }

    final now = DateTime.now();
    final todayString = PeriodCalculator.formatDate(now);

    final transaction = TransactionModel(
      userId: expense.userId,
      amount: expense.amount,
      type: 'expense',
      categoryId: expense.categoryId,
      accountId: accountId,
      note: 'Recurring: ${expense.name}',
      receiptPath: null,
      date: todayString,
      time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now.millisecondsSinceEpoch,
    );

    final transactionId = await addTransaction(transaction);

    await _recurringPayments.add(
      RecurringPaymentModel(
        expenseId: expenseId,
        accountId: accountId,
        transactionId: transactionId,
        paymentDate: todayString,
        amount: expense.amount,
        status: 'paid',
      ).toFirestore(),
    );

    final currentDue = expense.nextDueDate.isNotEmpty
        ? PeriodCalculator.parseDate(expense.nextDueDate)
        : now;
    final anchor = currentDue.isBefore(now) ? now : currentDue;
    final nextDue = advanceDate(anchor, expense.frequency);

    await updateRecurringExpense(
      expense.copyWith(nextDueDate: PeriodCalculator.formatDate(nextDue)),
    );
  }

  // ============================================================
  // LENDINGS 
  // ============================================================

  Future<String> addLending(LendingModel lending) async {
    if (lending.name.trim().isEmpty) {
      throw ArgumentError('Lending name cannot be empty.');
    }

    final documentRef = _lendings.doc();

    if (lending.accountId != null && lending.accountId!.isNotEmpty) {
      final accountRef = _accounts.doc(lending.accountId);
      await _firestore.runTransaction((transaction) async {
        final accountSnapshot = await transaction.get(accountRef);
        if (!accountSnapshot.exists || accountSnapshot.data() == null) {
          throw StateError('The selected account does not exist.');
        }
        final currentBalance = (accountSnapshot.data()!['balance'] as num?)?.toDouble() ?? 0;
        transaction.update(accountRef, {'balance': currentBalance - lending.totalAmount});
        transaction.set(documentRef, lending.toFirestore());
      });
    } else {
      await documentRef.set(lending.toFirestore());
    }

    return documentRef.id;
  }

  Future<List<LendingModel>> getLendings() async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _lendings;
    if (userId != null) query = query.where('userId', isEqualTo: userId);

    final snapshot = await query.get();
    final lendings = snapshot.docs
        .map((document) => LendingModel.fromFirestore(document.id, document.data()))
        .toList();

    lendings.sort((first, second) => second.createdDate.compareTo(first.createdDate));
    return lendings;
  }

  Future<LendingModel?> getLendingById(String lendingId) async {
    if (lendingId.trim().isEmpty) return null;

    final document = await _lendings.doc(lendingId).get();
    if (!document.exists || document.data() == null) return null;

    return LendingModel.fromFirestore(document.id, document.data()!);
  }

  Future<void> updateLending(LendingModel lending) async {
    final lendingId = lending.id;
    if (lendingId == null || lendingId.isEmpty) {
      throw ArgumentError('Lending ID is required.');
    }
    await _lendings.doc(lendingId).update(lending.toFirestore());
  }

  Future<void> deleteLending(String lendingId) async {
    if (lendingId.trim().isEmpty) {
      throw ArgumentError('Lending ID is required.');
    }
    await _lendings.doc(lendingId).delete();
  }

  Future<void> addLendingRepayment(LendingRepaymentModel repayment) async {
    if (repayment.accountId.trim().isEmpty) {
      throw ArgumentError('Repayment account is required.');
    }

    if (repayment.amount <= 0) {
      throw ArgumentError('Repayment amount must be greater than zero.');
    }

    final lendingRef = _lendings.doc(repayment.lendingId);
    final repaymentRef = _lendingRepayments.doc();

    await _firestore.runTransaction((transaction) async {
      final lendingSnapshot = await transaction.get(lendingRef);
      if (!lendingSnapshot.exists || lendingSnapshot.data() == null) {
        throw StateError('The lending does not exist.');
      }
      final lending = LendingModel.fromFirestore(lendingSnapshot.id, lendingSnapshot.data()!);
      if (lending.receivedAmount + repayment.amount > lending.totalAmount) {
        throw StateError('Repayment cannot exceed the remaining lending balance.');
      }
      final newReceived = lending.receivedAmount + repayment.amount;

      final accountRef = _accounts.doc(repayment.accountId);
      final accountSnapshot = await transaction.get(accountRef);
      if (!accountSnapshot.exists || accountSnapshot.data() == null) {
        throw StateError('The selected repayment account does not exist.');
      }
      final accountData = accountSnapshot.data()!;
      if (accountData['userId']?.toString() != _currentUserId) {
        throw StateError('The selected repayment account is not yours.');
      }
      final currentBalance = (accountData['balance'] as num?)?.toDouble() ?? 0;

      transaction.set(repaymentRef, repayment.toFirestore());
      transaction.update(lendingRef, {'receivedAmount': newReceived});
      transaction.update(accountRef, {'balance': currentBalance + repayment.amount});
    });
  }

  Future<List<LendingRepaymentModel>> getLendingRepayments(String lendingId) async {
    final snapshot = await _lendingRepayments.where('lendingId', isEqualTo: lendingId).get();
    final repayments = snapshot.docs
        .map((document) => LendingRepaymentModel.fromFirestore(document.id, document.data()))
        .toList();

    repayments.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return repayments;
  }

  // ============================================================
  // LOANS 
  // ============================================================

  Future<String> addLoan(LoanModel loan) async {
    if (loan.name.trim().isEmpty) {
      throw ArgumentError('Loan name cannot be empty.');
    }

    final documentRef = _loans.doc();

    if (loan.accountId != null && loan.accountId!.isNotEmpty) {
      final accountRef = _accounts.doc(loan.accountId);
      await _firestore.runTransaction((transaction) async {
        final accountSnapshot = await transaction.get(accountRef);
        if (!accountSnapshot.exists || accountSnapshot.data() == null) {
          throw StateError('The selected account does not exist.');
        }
        final currentBalance = (accountSnapshot.data()!['balance'] as num?)?.toDouble() ?? 0;
        transaction.update(accountRef, {'balance': currentBalance + loan.totalAmount});
        transaction.set(documentRef, loan.toFirestore());
      });
    } else {
      await documentRef.set(loan.toFirestore());
    }

    return documentRef.id;
  }

  Future<List<LoanModel>> getLoans() async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _loans;
    if (userId != null) query = query.where('userId', isEqualTo: userId);

    final snapshot = await query.get();
    final loans = snapshot.docs
        .map((document) => LoanModel.fromFirestore(document.id, document.data()))
        .toList();

    loans.sort((first, second) => second.createdDate.compareTo(first.createdDate));
    return loans;
  }

  Future<LoanModel?> getLoanById(String loanId) async {
    if (loanId.trim().isEmpty) return null;

    final document = await _loans.doc(loanId).get();
    if (!document.exists || document.data() == null) return null;

    return LoanModel.fromFirestore(document.id, document.data()!);
  }

  Future<void> updateLoan(LoanModel loan) async {
    final loanId = loan.id;
    if (loanId == null || loanId.isEmpty) {
      throw ArgumentError('Loan ID is required.');
    }
    await _loans.doc(loanId).update(loan.toFirestore());
  }

  Future<void> deleteLoan(String loanId) async {
    if (loanId.trim().isEmpty) {
      throw ArgumentError('Loan ID is required.');
    }
    await _loans.doc(loanId).delete();
  }

  Future<void> addLoanPayment(LoanPaymentModel payment) async {
    if (payment.accountId.trim().isEmpty) {
      throw ArgumentError('Payment account is required.');
    }

    if (payment.amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final loanRef = _loans.doc(payment.loanId);
    final paymentRef = _loanPayments.doc();

    await _firestore.runTransaction((transaction) async {
      final loanSnapshot = await transaction.get(loanRef);
      if (!loanSnapshot.exists || loanSnapshot.data() == null) {
        throw StateError('The loan does not exist.');
      }
      final loan = LoanModel.fromFirestore(loanSnapshot.id, loanSnapshot.data()!);
      if (loan.paidAmount + payment.amount > loan.totalAmount) {
        throw StateError('Payment cannot exceed the remaining loan balance.');
      }

      final accountRef = _accounts.doc(payment.accountId);
      final accountSnapshot = await transaction.get(accountRef);
      if (!accountSnapshot.exists || accountSnapshot.data() == null) {
        throw StateError('The selected payment account does not exist.');
      }
      final accountData = accountSnapshot.data()!;
      if (accountData['userId']?.toString() != _currentUserId) {
        throw StateError('The selected payment account is not yours.');
      }
      final currentBalance = (accountData['balance'] as num?)?.toDouble() ?? 0;
      if (currentBalance < payment.amount) {
        throw StateError('The selected account does not have enough balance.');
      }
      final newPaid = loan.paidAmount + payment.amount;

      String? nextDue = loan.nextDueDate;
      if (loan.isBank && loan.monthlyPaymentDay != null) {
        final current = (nextDue != null && nextDue.isNotEmpty)
            ? PeriodCalculator.parseDate(nextDue)
            : PeriodCalculator.parseDate(loan.startDate);
        final advanced = DateTime(current.year, current.month + 1, loan.monthlyPaymentDay!);
        nextDue = PeriodCalculator.formatDate(advanced);
      }

      transaction.set(paymentRef, payment.toFirestore());
      transaction.update(loanRef, {
        'paidAmount': newPaid,
        if (nextDue != loan.nextDueDate) 'nextDueDate': nextDue,
      });
      transaction.update(accountRef, {'balance': currentBalance - payment.amount});
    });
  }

  Future<List<LoanPaymentModel>> getLoanPayments(String loanId) async {
    final snapshot = await _loanPayments.where('loanId', isEqualTo: loanId).get();
    final payments = snapshot.docs
        .map((document) => LoanPaymentModel.fromFirestore(document.id, document.data()))
        .toList();

    payments.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return payments;
  }

  // ============================================================
  // TRANSFERS 
  // ============================================================

  Future<String> addTransfer(TransferModel transfer) async {
    if (transfer.fromAccountId.trim().isEmpty ||
        transfer.toAccountId.trim().isEmpty) {
      throw ArgumentError('Both accounts are required.');
    }

    if (transfer.fromAccountId == transfer.toAccountId) {
      throw ArgumentError('Choose two different accounts.');
    }

    if (transfer.amount <= 0) {
      throw ArgumentError('Transfer amount must be greater than zero.');
    }

    final transferReference = _transfers.doc();
    final fromReference = _accounts.doc(transfer.fromAccountId);
    final toReference = _accounts.doc(transfer.toAccountId);

    await _firestore.runTransaction((firestoreTransaction) async {
      final fromSnapshot = await firestoreTransaction.get(fromReference);
      final toSnapshot = await firestoreTransaction.get(toReference);

      if (!fromSnapshot.exists || fromSnapshot.data() == null) {
        throw StateError('The source account does not exist.');
      }

      if (!toSnapshot.exists || toSnapshot.data() == null) {
        throw StateError('The destination account does not exist.');
      }

      final fromBalance =
          (fromSnapshot.data()!['balance'] as num?)?.toDouble() ?? 0;
      final toBalance =
          (toSnapshot.data()!['balance'] as num?)?.toDouble() ?? 0;

      firestoreTransaction.update(fromReference, {
        'balance': fromBalance - transfer.amount - transfer.fee,
      });
      firestoreTransaction.update(toReference, {
        'balance': toBalance + transfer.amount,
      });
      firestoreTransaction.set(transferReference, transfer.toFirestore());
    });

    return transferReference.id;
  }

  Future<List<TransferModel>> getTransfers() async {
    final userId = _currentUserId;
    Query<Map<String, dynamic>> query = _transfers;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.get();

    final transfers = snapshot.docs.map((document) {
      return TransferModel.fromFirestore(document.id, document.data());
    }).toList();

    transfers.sort(
      (first, second) => second.createdAt.compareTo(first.createdAt),
    );

    return transfers;
  }
}