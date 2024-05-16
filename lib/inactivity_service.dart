import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InactivityService with WidgetsBindingObserver {
  static final InactivityService _instance = InactivityService._internal();
  Timer? _timer;

  factory InactivityService() {
    return _instance;
  }

  InactivityService._internal();

  void startTracking(VoidCallback onTimeout) {
    WidgetsBinding.instance!.addObserver(this);
    _startTimer(onTimeout);
  }

  void stopTracking() {
    WidgetsBinding.instance!.removeObserver(this);
    _timer?.cancel();
  }

  void resetTimer(VoidCallback onTimeout) {
    _timer?.cancel();
    _startTimer(onTimeout);
  }

  void _startTimer(VoidCallback onTimeout) {
    _timer = Timer(Duration(minutes: 1), onTimeout);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resetTimer(() {
        SystemNavigator.pop();
      });
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      SystemNavigator.pop();
    }
  }
}
