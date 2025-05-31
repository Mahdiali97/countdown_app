import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'main.dart';

class DatabaseService {
  static const String boxName = 'eventsBox';

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Future<int> insertEvent(CountdownEvent event) async {
    await init();
    final box = Hive.box(boxName);
    int key = await box.add(event.toMap());
    return key;
  }

  Future<List<CountdownEvent>> getAllEvents() async {
    await init();
    final box = Hive.box(boxName);
    return box.values
        .map((e) => CountdownEvent.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> deleteEvent(int id) async {
    await init();
    final box = Hive.box(boxName);
    await box.delete(id);
  }

  // ADD THIS METHOD FOR DEBUGGING
  Future<void> debugBoxContents() async {
    await init();
    final box = Hive.box(boxName);
    print('Hive box "$boxName" contains ${box.length} items.');
    for (var key in box.keys) {
      print('Key: $key, Value: ${box.get(key)}');
    }
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