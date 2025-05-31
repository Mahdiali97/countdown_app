import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'main.dart';

class DatabaseService {
  static Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    String dbPath = path.join(await getDatabasesPath(), 'countdown_events.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            date INTEGER NOT NULL,
            category TEXT,
            colorValue INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insertEvent(CountdownEvent event) async {
    await init();
    return await _db!.insert('events', event.toMap());
  }

  Future<List<CountdownEvent>> getAllEvents() async {
    await init();
    final maps = await _db!.query('events');
    return maps.map((e) => CountdownEvent.fromMap(e)).toList();
  }

  Future<void> deleteEvent(int id) async {
    await init();
    await _db!.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // Add this to your DatabaseService class (both mobile and web versions)
  Future<void> debugDatabase() async {
    final events = await getAllEvents();
    print('=== DEBUG DATABASE: ${events.length} events ===');
    for (final event in events) {
      print(event);
    }
  }
}