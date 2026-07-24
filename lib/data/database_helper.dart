import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('budget_app.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // migrate categories table: drop and recreate with iconName
          await db.execute('DROP TABLE IF EXISTS categories');
          await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        iconName TEXT NOT NULL,
        isDefault INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

          // re-insert default categories
          await _insertDefaultData(db);
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        currency TEXT NOT NULL,
        balance REAL NOT NULL,
        isDefault INTEGER NOT NULL,
        isIncluded INTEGER NOT NULL,
        createdAt INTEGER NOT NULL 
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        iconName TEXT NOT NULL,
        isDefault INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        categoryId INTEGER NOT NULL,
        accountId INTEGER NOT NULL,
        note TEXT,
        receiptPath TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (accountId) REFERENCES accounts (id)
      )
    ''');

    await _insertDefaultData(db);
  }

  Future<void> _insertDefaultData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('accounts', {
      'name': 'Cash',
      'currency': 'LKR',
      'balance': 0.0,
      'isDefault': 1,
      'isIncluded': 1,
      'createdAt': now,
    });

    final defaultCategories = [
      // Income
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

      // Expenses
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

      // Other / Savings
      {'name': 'Savings', 'type': 'expense', 'iconName': 'savings'},
      {'name': 'Gifts', 'type': 'expense', 'iconName': 'card_giftcard'},
      {'name': 'Emergency', 'type': 'expense', 'iconName': 'warning_amber'},
      {'name': 'Subscriptions', 'type': 'expense', 'iconName': 'subscriptions'},
      {'name': 'Credit Card Interest', 'type': 'expense', 'iconName': 'credit_card'},
      {'name': 'Bank Charges', 'type': 'expense', 'iconName': 'account_balance'},
    ];

    for (final category in defaultCategories) {
      await db.insert('categories', {
        'name': category['name'],
        'type': category['type'],
        'iconName': category['iconName'],
        'isDefault': 1,
        'createdAt': now,
      });
    }
  }

  Future<int> insertAccount(AccountModel account) async {
    final db = await instance.database;
    return await db.insert('accounts', account.toMap());
  }

  Future<List<AccountModel>> getAccounts() async {
    final db = await instance.database;
    final result = await db.query('accounts', orderBy: 'createdAt DESC');

    return result.map((map) => AccountModel.fromMap(map)).toList();
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    final db = await instance.database;

    final result = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'isDefault DESC, name ASC',
    );

    return result.map((map) => CategoryModel.fromMap(map)).toList();
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;

    final transactionId = await db.insert(
      'transactions',
      transaction.toMap(),
    );

    final account = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [transaction.accountId],
      limit: 1,
    );

    if (account.isNotEmpty) {
      final currentBalance = account.first['balance'] as double;

      double newBalance = currentBalance;

      if (transaction.type == 'income') {
        newBalance += transaction.amount;
      } else {
        newBalance -= transaction.amount;
      }

      await db.update(
        'accounts',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [transaction.accountId],
      );
    }

    return transactionId;
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await instance.database;

    final result = await db.query(
      'transactions',
      orderBy: 'createdAt DESC',
    );

    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}