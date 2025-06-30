import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

class DatabaseService {
  final CollectionReference eventsCollection =
      FirebaseFirestore.instance.collection('events');

  Future<String> insertEvent(CountdownEvent event) async {
    final docRef = await eventsCollection.add(event.toMap());
    return docRef.id;
  }

  Future<List<CountdownEvent>> getAllEvents() async {
    final snapshot = await eventsCollection.get();
    return snapshot.docs
        .map((doc) => CountdownEvent.fromMap(doc.data() as Map<String, dynamic>, id: doc.id))
        .toList();
  }

  Future<void> deleteEvent(String id) async {
    await eventsCollection.doc(id).delete();
  }

  // Optional: For debugging
  Future<void> debugDatabase() async {
    final events = await getAllEvents();
    print('=== DEBUG DATABASE: ${events.length} events ===');
    for (final event in events) {
      print(event);
    }
  }
}

