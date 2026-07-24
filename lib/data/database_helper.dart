import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _accountsCollection = 'accounts';
  static const String _categoriesCollection = 'categories';
  static const String _transactionsCollection = 'transactions';
  static const String _metaCollection = '_meta';
  static const String _configDocId = 'config';
  static const String _countersDocId = 'counters';

  DatabaseHelper._init();

  CollectionReference<Map<String, dynamic>> get _accountsRef =>
      _firestore.collection(_accountsCollection);

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection(_categoriesCollection);

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection(_transactionsCollection);

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection(_metaCollection).doc(_configDocId);

  DocumentReference<Map<String, dynamic>> get _countersRef =>
      _firestore.collection(_metaCollection).doc(_countersDocId);

  Future<void> _ensureSeeded() async {
    await _firestore.runTransaction((transaction) async {
      final configSnapshot = await transaction.get(_configRef);
      final configData = configSnapshot.data();

      if (configData?['seeded'] == true) {
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      transaction.set(
        _accountsRef.doc('1'),
        {
          'id': 1,
          'name': 'Cash',
          'currency': 'LKR',
          'balance': 0.0,
          'isDefault': true,
          'isIncluded': true,
          'createdAt': now,
        },
      );

      final defaultCategories = [
        {'name': 'Salary', 'type': 'income', 'iconName': 'payments'},
        {'name': 'Freelance Income', 'type': 'income', 'iconName': 'laptop_mac'},
        {'name': 'Business Income', 'type': 'income', 'iconName': 'business_center'},
        {'name': 'Investment Returns', 'type': 'income', 'iconName': 'trending_up'},
        {'name': 'Bonus', 'type': 'income', 'iconName': 'workspace_premium'},
        {'name': 'Side Hustles', 'type': 'income', 'iconName': 'computer'},
        {'name': 'Gift Received', 'type': 'income', 'iconName': 'card_giftcard'},
        {'name': 'Rental Income', 'type': 'income', 'iconName': 'home_work'},
        {'name': 'Dividends', 'type': 'income', 'iconName': 'account_balance'},
        {'name': 'Refunds', 'type': 'income', 'iconName': 'assignment_return'},
        {'name': 'Bank Interest', 'type': 'income', 'iconName': 'savings'},
        {'name': 'Rent', 'type': 'expense', 'iconName': 'home'},
        {'name': 'Electricity', 'type': 'expense', 'iconName': 'electric_bolt'},
        {'name': 'Water', 'type': 'expense', 'iconName': 'water_drop'},
        {'name': 'Gas', 'type': 'expense', 'iconName': 'local_fire_department'},
        {'name': 'Garbage', 'type': 'expense', 'iconName': 'delete_outline'},
        {'name': 'Groceries', 'type': 'expense', 'iconName': 'shopping_cart'},
        {'name': 'Phone', 'type': 'expense', 'iconName': 'smartphone'},
        {'name': 'Internet', 'type': 'expense', 'iconName': 'wifi'},
        {'name': 'TV', 'type': 'expense', 'iconName': 'tv'},
        {'name': 'Domestic Help', 'type': 'expense', 'iconName': 'cleaning_services'},
        {'name': 'Transport', 'type': 'expense', 'iconName': 'directions_bus'},
        {'name': 'Fuel', 'type': 'expense', 'iconName': 'local_gas_station'},
        {'name': 'Vehicle', 'type': 'expense', 'iconName': 'directions_car'},
        {'name': 'Parking', 'type': 'expense', 'iconName': 'local_parking'},
        {'name': 'Tuition', 'type': 'expense', 'iconName': 'school'},
        {'name': 'Books', 'type': 'expense', 'iconName': 'menu_book'},
        {'name': 'Activities', 'type': 'expense', 'iconName': 'sports_soccer'},
        {'name': 'Doctor', 'type': 'expense', 'iconName': 'medical_services'},
        {'name': 'Meds', 'type': 'expense', 'iconName': 'medication'},
        {'name': 'Insurance', 'type': 'expense', 'iconName': 'health_and_safety'},
        {'name': 'Dental', 'type': 'expense', 'iconName': 'masks'},
        {'name': 'Clothing', 'type': 'expense', 'iconName': 'checkroom'},
        {'name': 'Salon', 'type': 'expense', 'iconName': 'content_cut'},
        {'name': 'Gym', 'type': 'expense', 'iconName': 'fitness_center'},
        {'name': 'Dining', 'type': 'expense', 'iconName': 'restaurant'},
        {'name': 'Movies', 'type': 'expense', 'iconName': 'movie'},
        {'name': 'Travel', 'type': 'expense', 'iconName': 'flight'},
        {'name': 'Hobbies', 'type': 'expense', 'iconName': 'palette'},
        {'name': 'Credit Cards', 'type': 'expense', 'iconName': 'credit_card'},
        {'name': 'Savings', 'type': 'expense', 'iconName': 'savings'},
        {'name': 'Gifts', 'type': 'expense', 'iconName': 'card_giftcard'},
        {'name': 'Emergency', 'type': 'expense', 'iconName': 'warning_amber'},
        {'name': 'Subscriptions', 'type': 'expense', 'iconName': 'subscriptions'},
        {'name': 'Credit Card Interest', 'type': 'expense', 'iconName': 'credit_card'},
        {'name': 'Bank Charges', 'type': 'expense', 'iconName': 'account_balance'},
      ];

      for (var index = 0; index < defaultCategories.length; index++) {
        final category = defaultCategories[index];
        final categoryId = index + 1;

        transaction.set(
          _categoriesRef.doc(categoryId.toString()),
          {
            'id': categoryId,
            'name': category['name'],
            'type': category['type'],
            'iconName': category['iconName'],
            'isDefault': true,
            'createdAt': now,
          },
        );
      }

      transaction.set(
        _countersRef,
        {
          'accountId': 1,
          'categoryId': defaultCategories.length,
          'transactionId': 0,
        },
        SetOptions(merge: true),
      );

      transaction.set(
        _configRef,
        {'seeded': true},
        SetOptions(merge: true),
      );
    });
  }

  Future<int> _nextId(Transaction transaction, String counterField) async {
    final counterSnapshot = await transaction.get(_countersRef);
    final counterData = counterSnapshot.data() ?? <String, dynamic>{};
    final current = (counterData[counterField] as num?)?.toInt() ?? 0;
    final next = current + 1;

    transaction.set(
      _countersRef,
      {counterField: next},
      SetOptions(merge: true),
    );

    return next;
  }

  Future<int> _insertWithCounter({
    required String collectionName,
    required String counterField,
    required Map<String, dynamic> data,
  }) async {
    await _ensureSeeded();

    return _firestore.runTransaction((transaction) async {
      final id = await _nextId(transaction, counterField);
      transaction.set(
        _firestore.collection(collectionName).doc(id.toString()),
        {...data, 'id': id},
      );
      return id;
    });
  }

  Future<int> insertAccount(AccountModel account) async {
    return _insertWithCounter(
      collectionName: _accountsCollection,
      counterField: 'accountId',
      data: account.toMap(),
    );
  }

  Future<List<AccountModel>> getAccounts() async {
    await _ensureSeeded();

    final snapshot = await _accountsRef.get();
    final accounts = snapshot.docs
        .map((doc) => AccountModel.fromMap(doc.data()))
        .toList();

    accounts.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return accounts;
  }

  Future<int> insertCategory(CategoryModel category) async {
    return _insertWithCounter(
      collectionName: _categoriesCollection,
      counterField: 'categoryId',
      data: category.toMap(),
    );
  }

  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    await _ensureSeeded();

    final snapshot = await _categoriesRef.where('type', isEqualTo: type).get();
    final categories = snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data()))
        .toList();

    categories.sort((left, right) {
      final defaultComparison =
          (right.isDefault ? 1 : 0).compareTo(left.isDefault ? 1 : 0);

      if (defaultComparison != 0) {
        return defaultComparison;
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return categories;
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    await _ensureSeeded();

    return _firestore.runTransaction((transactionRef) async {
      final accountRef = _accountsRef.doc(transaction.accountId.toString());
      final accountSnapshot = await transactionRef.get(accountRef);
      final countersSnapshot = await transactionRef.get(_countersRef);
      final countersData = countersSnapshot.data() ?? <String, dynamic>{};
      final currentTransactionId =
          (countersData['transactionId'] as num?)?.toInt() ?? 0;
      final transactionId = currentTransactionId + 1;

      transactionRef.set(
        _countersRef,
        {'transactionId': transactionId},
        SetOptions(merge: true),
      );

      transactionRef.set(
        _transactionsRef.doc(transactionId.toString()),
        {...transaction.toMap(), 'id': transactionId},
      );

      final accountData = accountSnapshot.data();
      if (accountData != null) {
        final currentBalance =
            (accountData['balance'] as num?)?.toDouble() ?? 0.0;

        final updatedBalance = transaction.type == 'income'
            ? currentBalance + transaction.amount
            : currentBalance - transaction.amount;

        transactionRef.update(accountRef, {'balance': updatedBalance});
      }

      return transactionId;
    });
  }

  Future<List<TransactionModel>> getTransactions() async {
    await _ensureSeeded();

    final snapshot = await _transactionsRef.get();
    final transactions = snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data()))
        .toList();

    transactions.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return transactions;
  }

  Future<void> close() async {
    return;
  }
}