import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_screen.dart'; // Import the auth login page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AMS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: InactivityTracker(child: AuthScreen()), // Wrap your AuthScreen with InactivityTracker
    );
  }
}

class InactivityTracker extends StatefulWidget {
  final Widget child;

  const InactivityTracker({required this.child});

  @override
  _InactivityTrackerState createState() => _InactivityTrackerState();
}

class _InactivityTrackerState extends State<InactivityTracker> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer(Duration(minutes: 1), () {
      // Close the app completely and force it to restart
      SystemNavigator.pop();
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetTimer();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _clearAppState();
    }
  }

  void _clearAppState() {
    // Clear app state here, if any
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimer,
      onPanUpdate: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
