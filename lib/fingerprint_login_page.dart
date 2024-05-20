import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'AMS_Screen.dart';

class FingerprintLoginPage extends StatefulWidget {
  @override
  _FingerprintLoginPageState createState() => _FingerprintLoginPageState();
}

class _FingerprintLoginPageState extends State<FingerprintLoginPage> {
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isFingerprintAvailable = false;
  bool _isAuthenticated = false;
  bool _isCheckingIn = true;
  bool _isMatching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
    _currentUser = _auth.currentUser;
    checkAttendanceStatus();
  }

  Future<void> _checkBiometrics() async {
    bool hasBiometrics;
    try {
      hasBiometrics = await _localAuthentication.canCheckBiometrics;
    } catch (e) {
      hasBiometrics = false;
      print('Error checking biometrics: $e');
    }
    if (!mounted) return;
    setState(() {
      _isFingerprintAvailable = hasBiometrics;
    });
  }

  Future<void> _authenticate() async {
    bool isAuthenticated = false;
    setState(() {
      _isMatching = true;
    });
    try {
      isAuthenticated = await _localAuthentication.authenticate(
        localizedReason: 'Please authenticate to log in',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (e) {
      print('Error during authentication: $e');
    }
    if (!mounted) return;
    if (isAuthenticated) {
      setState(() {
        _isAuthenticated = true;
      });
      await logAttendance();
    }
    setState(() {
      _isMatching = false;
    });
  }

  Future<void> logAttendance() async {
    var now = DateTime.now();
    var today = now.toIso8601String().split('T')[0];
    var timeNow = now.toIso8601String().split('T')[1].split('.')[0]; // Only the time part

    // Check if an attendance log already exists for today
    var attendanceQuery = await _firestore
        .collection('attendance_logs')
        .where('user_id', isEqualTo: _currentUser?.uid)
        .where('date', isEqualTo: today)
        .get();

    if (attendanceQuery.docs.isEmpty) {
      // No entry for today, create a new one with entering time
      await _firestore.collection('attendance_logs').add({
        'user_id': _currentUser?.uid,
        'name': _currentUser?.displayName,
        'employee_id': _currentUser?.uid,
        'date': today,
        'entering_time': timeNow,
        'method': 'Fingerprint',
        // Other relevant details
      });
      showAlertDialog(context, "Attendance logged", "Checked In");
      print("Entering time logged.");
    } else {
      // Entry for today exists, update it with leaving time
      var attendanceDoc = attendanceQuery.docs.first;
      await _firestore.collection('attendance_logs').doc(attendanceDoc.id).update({
        'leaving_time': timeNow,
      });
      showAlertDialog(context, "Attendance logged", "Checked Out");
      print("Leaving time logged.");
    }
  }

  Future<void> checkAttendanceStatus() async {
    var now = DateTime.now();
    var today = now.toIso8601String().split('T')[0];

    var attendanceQuery = await _firestore
        .collection('attendance_logs')
        .where('user_id', isEqualTo: _currentUser?.uid)
        .where('date', isEqualTo: today)
        .get();

    if (attendanceQuery.docs.isNotEmpty) {
      setState(() {
        _isCheckingIn = false;
      });
    } else {
      setState(() {
        _isCheckingIn = true;
      });
    }
  }

  void showAlertDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => AttendanceSelectionPage()),
                  (Route<dynamic> route) => false,
            ),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget createButton(String text, VoidCallback onPress) => Container(
    width: 250,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, backgroundColor: Colors.blue,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: _isMatching ? null : onPress,
      child: _isMatching
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(width: 10),
          Text("Matching..."),
        ],
      )
          : Text(text, style: TextStyle(fontSize: 16)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fingerprint Authentication'),
      ),
      body: Center(
        child: _isFingerprintAvailable
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            createButton(_isCheckingIn ? "Check In with Fingerprint" : "Check Out with Fingerprint", _authenticate),
            SizedBox(height: 20),
            _isAuthenticated
                ? Text('Attendance Logged successfully with fingerprint')
                : SizedBox(),
          ],
        )
            : Text('Fingerprint not available on this device'),
      ),
    );
  }
}
