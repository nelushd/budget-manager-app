import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

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
    final snapshot = await _accounts.get();

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
    return _accounts.snapshots().map((snapshot) {
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

  Future<void> deleteAccount(String accountId) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError('Account ID is required.');
    }

    final relatedTransactions = await _transactions
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
    final snapshot = await _accounts.get();

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

  Future<List<CategoryModel>> getCategoriesByType(
    String type,
  ) async {
    final snapshot = await _categories
        .where('type', isEqualTo: type)
        .get();

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
  }

  Stream<List<CategoryModel>> watchCategoriesByType(
    String type,
  ) {
    return _categories
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
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

  // ============================================================
  // TRANSACTIONS
  // ============================================================

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

      final balanceChange =
          transactionModel.type == 'income'
              ? transactionModel.amount
              : -transactionModel.amount;

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
    final snapshot = await _transactions.get();

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
    final snapshot = await _transactions
        .where('type', isEqualTo: type)
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

  Future<List<TransactionModel>> getTransactionsByAccount(
    String accountId,
  ) async {
    final snapshot = await _transactions
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
    return _transactions.snapshots().map((snapshot) {
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

        final reversedOldAmount =
            oldTransaction.type == 'income'
                ? -oldTransaction.amount
                : oldTransaction.amount;

        final appliedNewAmount =
            updatedTransaction.type == 'income'
                ? updatedTransaction.amount
                : -updatedTransaction.amount;

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

        final reversedOldAmount =
            oldTransaction.type == 'income'
                ? -oldTransaction.amount
                : oldTransaction.amount;

        final appliedNewAmount =
            updatedTransaction.type == 'income'
                ? updatedTransaction.amount
                : -updatedTransaction.amount;

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

      final reversedAmount =
          existingTransaction.type == 'income'
              ? -existingTransaction.amount
              : existingTransaction.amount;

      firestoreTransaction.update(
        accountReference,
        {'balance': currentBalance + reversedAmount},
      );

      firestoreTransaction.delete(transactionReference);
    });
  }
}