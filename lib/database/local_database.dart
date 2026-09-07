import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<Database> get database async {
    _database ??= await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'mali_wallet.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE transactions(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL, title TEXT NOT NULL, amount TEXT NOT NULL, time TEXT NOT NULL, is_expense INTEGER NOT NULL, icon_name TEXT NOT NULL, category TEXT NOT NULL)',
        );
      },
    );
  }

  Future<void> replaceTransactions(List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      for (final item in items) {
        await txn.insert('transactions', item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTransactions({int? userId}) async {
    final db = await database;
    return db.query('transactions', where: userId == null ? null : 'user_id = ?', whereArgs: userId == null ? null : [userId], orderBy: 'id DESC');
  }

  Future<void> insertTransaction(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert('transactions', item, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> item) async {
    final db = await database;
    await db.update('transactions', item, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}
