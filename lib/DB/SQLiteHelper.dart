import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatDatabaseHelper {
  static final ChatDatabaseHelper instance = ChatDatabaseHelper._init();
  static Database? _database;

  ChatDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (chat_id) REFERENCES chats (id)
      )
    ''');
  }

  Future<int> insertChat(Map<String, dynamic> chat) async {
    final db = await instance.database;
    return await db.insert('chats', chat);
  }

  Future<int> insertMessage(Map<String, dynamic> message) async {
    final db = await instance.database;
    return await db.insert('messages', message);
  }

  Future<List<Map<String, dynamic>>> getChats() async {
    final db = await instance.database;
    return await db.query('chats', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getMessages(int chatId) async {
    final db = await instance.database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'created_at ASC',
    );
  }

  // New function to delete a chat and its related messages
  Future<int> deleteChat(int chatId) async {
    final db = await instance.database;
    // First, delete the related messages
    await db.delete(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
    // Then, delete the chat
    return await db.delete(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }
}
