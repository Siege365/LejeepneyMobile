// Database Helper - Put your SQLite/Firebase/API database code here
// Example using SQLite (sqflite package)

// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  // static Database? _database;

  // Future<Database> get database async {
  //   if (_database != null) return _database!;
  //   _database = await _initDB('app_database.db');
  //   return _database!;
  // }

  // Future<Database> _initDB(String filePath) async {
  //   final dbPath = await getDatabasesPath();
  //   final path = join(dbPath, filePath);
  //
  //   return await openDatabase(
  //     path,
  //     version: 1,
  //     onCreate: _createDB,
  //   );
  // }

  // Future _createDB(Database db, int version) async {
  //   await db.execute('''
  //     CREATE TABLE users (
  //       id TEXT PRIMARY KEY,
  //       name TEXT NOT NULL,
  //       email TEXT NOT NULL,
  //       role TEXT NOT NULL
  //     )
  //   ''');
  // }

  // Add your database methods here:
  // - createUser()
  // - getUsers()
  // - updateUser()
  // - deleteUser()
}
