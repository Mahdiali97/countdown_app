import 'package:flutter/material.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'dart:async';
import 'database_service.dart';

void main() {
  runApp(const MyApp());
}

class CountdownEvent {
  final int? id;
  final String name;
  final DateTime date;
  final String category;
  final Color color;

  CountdownEvent({
    this.id,
    required this.name,
    required this.date,
    this.category = 'General',
    this.color = Colors.blue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.millisecondsSinceEpoch,
      'category': category,
      'colorValue': color.value,
    };
  }

  factory CountdownEvent.fromMap(Map<String, dynamic> map) {
    return CountdownEvent(
      id: map['id'],
      name: map['name'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      category: map['category'] ?? 'General',
      color: Color(map['colorValue'] ?? Colors.blue.value),
    );
  }

  @override
  String toString() {
    return 'CountdownEvent{id: $id, name: $name, date: $date, category: $category}';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Countdown Master',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    _animationController.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CountdownHomePage()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Countdown Master',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Never miss important moments',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CountdownHomePage extends StatefulWidget {
  const CountdownHomePage({super.key});

  @override
  State<CountdownHomePage> createState() => _CountdownHomePageState();
}

class _CountdownHomePageState extends State<CountdownHomePage> {
  List<CountdownEvent> _events = [];
  final DatabaseService _dbService = DatabaseService();
  Timer? _checkEventsTimer;
  final Set<int> _notifiedEventIds = {};

  @override
  void initState() {
    super.initState();
    _loadEvents().then((_) {
      _checkUpcomingEvents();
      
      // Set up timer to check events every minute
      _checkEventsTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _checkAllEvents(),
      );
    });
  }

  @override
  void dispose() {
    _checkEventsTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadEvents() async {
    print('Loading events from database...');
    final events = await _dbService.getAllEvents();
    print('Loaded ${events.length} events from database');
    setState(() {
      _events = events;
    });
    print('UI updated with ${_events.length} events');
  }

  Future<void> _addEvent(CountdownEvent event) async {
    print('Adding event: ${event.name}, Date: ${event.date}');
    await _dbService.insertEvent(event);
    print('Inserted. Reloading events...');
    await _loadEvents();
    
    // Show a success notification
    ElegantNotification.success(
      title: const Text("Success"),
      description: Text("Event '${event.name}' added successfully"),
      toastDuration: const Duration(seconds: 3),
    ).show(context);
  }

  Future<void> _deleteEvent(int id) async {
    print('Deleting event with id: $id');
    await _dbService.deleteEvent(id);
    await _loadEvents();
    
    // Show a notification when event is deleted
    ElegantNotification.info(
      title: const Text("Event Deleted"),
      description: const Text("Event has been removed successfully"),
      toastDuration: const Duration(seconds: 3),
    ).show(context);
  }

  void _showAddEventDialog() async {
    print('Opening add event dialog');
    final CountdownEvent? newEvent = await showDialog<CountdownEvent>(
      context: context,
      builder: (context) => const AddEventDialog(),
    );
    print('Dialog returned: $newEvent');
    if (newEvent != null) {
      print('Adding new event: ${newEvent.name}');
      await _addEvent(newEvent);
    } else {
      print('No event was created (user cancelled or invalid data)');
    }
  }

  int _daysLeft(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  void _checkUpcomingEvents() {
    for (final event in _events) {
      final daysLeft = _daysLeft(event.date);
      
      // Notify for events happening tomorrow
      if (daysLeft == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ElegantNotification.info(
              title: const Text("Event Tomorrow"),
              description: Text("'${event.name}' is happening tomorrow!"),
              icon: Icon(Icons.event_available, color: event.color),
              toastDuration: const Duration(seconds: 5),
            ).show(context);
          }
        });
      }
    }
  }

  void _checkAllEvents() {
    _checkUpcomingEvents();
    _checkArrivedEvents();
  }

  void _checkArrivedEvents() {
    final now = DateTime.now();
    for (final event in _events) {
      // Check if event has just arrived (within the last minute)
      final difference = event.date.difference(now);
      
      if (difference <= Duration.zero && 
          difference > const Duration(minutes: -1) &&
          !_notifiedEventIds.contains(event.id)) {
        
        // Show notification for arrived event
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ElegantNotification.success(
              title: const Text("Event Arrived!"),
              description: Text("'${event.name}' has arrived!"),
              icon: Icon(Icons.celebration, color: event.color),
              toastDuration: const Duration(seconds: 5),
            ).show(context);
          }
        });
        
        // Mark this event as notified
        _notifiedEventIds.add(event.id!);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'My Events',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.shade800,
                      Colors.purple.shade400,
                    ],
                    stops: const [0.3, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -10,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.event_note,
                        size: 80,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  // Implement search functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: () {
                  // Implement filter functionality
                },
              ),
            ],
          ),
          _events.isEmpty
              ? SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events yet!',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first event',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = _events[index];
                    final daysLeft = _daysLeft(event.date);
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EventCountdownPage(event: event),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                event.color.withOpacity(0.8),
                                event.color.withOpacity(0.6),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _deleteEvent(event.id!);
                                      },
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      event.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        event.category,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  daysLeft >= 0
                                      ? '$daysLeft days left'
                                      : 'Event passed',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        daysLeft >= 0
                                            ? Colors.white
                                            : Colors.red.shade200,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    },
                    childCount: _events.length),
                ),
              ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "debug",
            onPressed: () async {
              print('=== DEBUG BUTTON PRESSED ===');
              await _dbService.debugDatabase();

              final testEvent = CountdownEvent(
                name: 'Test Event ${DateTime.now().millisecond}',
                date: DateTime.now().add(const Duration(days: 7)),
                category: 'Test',
                color: Colors.red,
              );
              print('Creating test event: $testEvent');
              await _addEvent(testEvent);
            },
            backgroundColor: Colors.grey,
            mini: true,
            child: const Icon(Icons.bug_report),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: "add",
            onPressed: _showAddEventDialog,
            tooltip: 'Add Event',
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class AddEventDialog extends StatefulWidget {
  const AddEventDialog({super.key});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _nameController = TextEditingController();
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  String _category = 'General';
  Color _selectedColor = Colors.blue;

  final List<String> _categories = [
    'General',
    'Birthday',
    'Anniversary',
    'Holiday',
    'Work',
    'Personal',
    'Travel',
    'Other',
  ];

  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  DateTime? get _combinedDateTime {
    if (_eventDate != null && _eventTime != null) {
      return DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
        _eventTime!.hour,
        _eventTime!.minute,
      );
    }
    return _eventDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add New Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _category = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventDate == null
                        ? 'No date selected'
                        : 'Date: ${_eventDate.toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        print('Date picked: $picked');
                        setState(() {
                          _eventDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventTime == null
                        ? 'No time selected'
                        : 'Time: ${_eventTime!.format(context)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        print('Time picked: $picked');
                        setState(() {
                          _eventTime = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: const Text('Pick Time'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose Color:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == color
                            ? Colors.black
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            print('Dialog cancelled');
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty && _eventDate != null) {
              final eventDateTime = _combinedDateTime ?? _eventDate!;
              final newEvent = CountdownEvent(
                name: _nameController.text,
                date: eventDateTime,
                category: _category,
                color: _selectedColor,
              );
              print('Creating event from dialog: $newEvent');
              Navigator.pop(context, newEvent);
            } else {
              print(
                'Invalid data: name=${_nameController.text}, date=$_eventDate',
              );
              
              // Show an error notification instead of a SnackBar
              ElegantNotification.error(
                title: const Text("Invalid Input"),
                description: const Text("Please enter event name and select a date"),
              ).show(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class EventCountdownPage extends StatefulWidget {
  final CountdownEvent event;
  const EventCountdownPage({super.key, required this.event});

  @override
  State<EventCountdownPage> createState() => _EventCountdownPageState();
}

class _EventCountdownPageState extends State<EventCountdownPage>
    with TickerProviderStateMixin {
  late Duration _remaining;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _notificationShown = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  void _updateRemaining() {
    final now = DateTime.now();
    setState(() {
      _remaining = widget.event.date.difference(now);
      
      // Check if countdown just reached zero and notification hasn't been shown yet
      if (_remaining.isNegative || _remaining == Duration.zero) {
        _remaining = Duration.zero;
        
        // Show notification only once when the countdown reaches zero
        if (!_notificationShown) {
          _showEventArrivedNotification();
          _notificationShown = true;
        }
      }
    });
  }

  void _showEventArrivedNotification() {
    // Use addPostFrameCallback to show notification after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Event Arrived!"),
          description: Text("'${widget.event.name}' has arrived!"),
          icon: Icon(Icons.celebration, color: widget.event.color),
          toastDuration: const Duration(seconds: 5),
        ).show(context);
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return '$days:${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.event.color.withOpacity(0.8),
              widget.event.color.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  widget.event.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              Expanded(
                child: Center(
                  child:
                      _remaining == Duration.zero
                          ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.celebration,
                                size: 100,
                                color: Colors.white,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Event has arrived!',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Countdown',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.timer,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              const Text(
                                'Time Remaining',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _formatDuration(_remaining),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Days : Hours : Minutes : Seconds',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
