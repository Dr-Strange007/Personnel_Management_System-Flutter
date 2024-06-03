import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'AMS_Screen.dart';
import 'auth_screen.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FingerprintLoginPage extends StatefulWidget {
  @override
  _FingerprintLoginPageState createState() => _FingerprintLoginPageState();
}

class _FingerprintLoginPageState extends State<FingerprintLoginPage> {

  Timer? _inactivityTimer;
  final int _inactivityDuration = 60;
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  final String apiUrl = 'http://192.168.1.130:8000/api';  // Change to your API URL
  bool _isFingerprintAvailable = false;
  bool _isAuthenticated = false;
  bool _isCheckingIn = true;
  bool _isMatching = false;
  String? _employeeId;  // This should store the employee ID
  String? _userName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
      _initializeUserDetails();
      _startInactivityTimer();
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: _inactivityDuration), _handleInactivity);
  }

  void _resetInactivityTimer() {
    _startInactivityTimer();
  }

  void _handleInactivity() {
    // Handle inactivity (e.g., log out the user)
    _logout();
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()), // Change to your login page
    );
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

  Future<void> _initializeUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? employeeId = prefs.getString('userId');
    print("employeeId ; $employeeId");
    String? userName = prefs.getString('userName');
    print("UserName ; $userName");

    if (employeeId != null && userName != null) {
      setState(() {
        _employeeId = employeeId;
        _userName = userName;
      });
    } else {
      print("No user data found, please login.");
    }
  }

  Future<int?> _fetchUserIdFromEmployeeId(String employeeId) async {
    var response = await http.get(Uri.parse('$apiUrl/get-user-id/?employee_id=$employeeId'));
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['id'];
    } else {
      // User not found, handle the case or create a new user
      print("User not found, need to create a new user");
      return null;
    }
  }

  Future<int?> _createUser(String employeeId, String? userName, String? email) async {
    var newUser = {
      'employee_id': employeeId,
      'name': userName,
      'email': '',  // Optional: Add default values or leave blank
      'uid': employeeId, // Optional: Set employee_id as uid if suitable
    };
    var response = await http.post(
        Uri.parse('$apiUrl/users/add/'),
        body: jsonEncode(newUser),
        headers: {'Content-Type': 'application/json'}
    );
    if (response.statusCode == 201) {  // Assuming 201 Created status code
      var data = jsonDecode(response.body);
      return data['id'];  // Assuming response includes the new user ID
    } else {
      print('Failed to create user: ${response.body}');
      return null;
    }
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? employeeId = prefs.getString('userId');
    String? userName = prefs.getString('userName');
    String? email = prefs.getString('userEmail');

    print("Employee_ID :  $employeeId");

    int? userId = await _fetchUserIdFromEmployeeId(employeeId!);
    tz.initializeTimeZones();
    var dhaka = tz.getLocation('Asia/Dhaka');
    var now = tz.TZDateTime.now(dhaka);
    var today = now.toIso8601String().split('T')[0];
    print("Todays Date in Dhaka: $today");
    var timeNow = now.toIso8601String().split('T')[1].split('.')[0];
    print("Todays Time Now ; $timeNow");
    print("User_ID :  $userId");

    if (userId == null) {
      // User does not exist, create a new one
      userId = await _createUser(employeeId, userName, email);
      if (userId == null) {
        print("Failed to create a new user for employee ID: $employeeId");
        return;
      }
    }
    print('UserId $userId');

    // Fetch existing attendance log for today
    var checkResponse = await http.get(Uri.parse('$apiUrl/attendance_logs/?user_id=$userId&date=$today'));
    print('Response status: ${checkResponse.statusCode}');
    print('Response body: ${checkResponse.body}');
    var existingLogs = jsonDecode(checkResponse.body);

    // Filter the existing logs by user_id and date
    var filteredLogs = existingLogs.where((log) {
      return log['user'] == userId && log['date'] == today;
    }).toList();


    if (filteredLogs.isEmpty ) {
      // No entry for today, create a new one with entering time
      var newLog = {
        'user': userId,  // Using the fetched user ID
        'name' : userName,
        'date': today,
        'entering_time': timeNow,
        'similarity': 0.95,
        'method': 'finger_id'
      };
      var postUri = Uri.parse('$apiUrl/attendance_logs/');
      var Atten_Post = await http.post(postUri, body: jsonEncode(newLog), headers: {'Content-Type': 'application/json'});
      print("Attendance Post Response: ${Atten_Post.body}");
      if (Atten_Post.statusCode == 201) {
        showAlertDialog(context, "Attendance Logged", "Checked In");
        setState(() {
          _isCheckingIn = false;  // Toggle to false after successful check-in
        });
      } else {
        print("Failed to log attendance: ${Atten_Post.body}");
        showAlertDialog(context, "Error", "Failed to log attendance. Please try again.");
      }
    } else {
      // Entry for today exists, update leaving time
      var existingLog = filteredLogs[0]; // Assuming the API returns a list
      var updateUri = Uri.parse('$apiUrl/attendance_logs/${existingLog['id']}/');
      var updateLog = {
        'leaving_time': timeNow,
      };
      var updateResponse = await http.patch(updateUri, body: jsonEncode(updateLog), headers: {'Content-Type': 'application/json'});
      print("Attendance Update Response: ${updateResponse.body}");
      if (updateResponse.statusCode == 200) {
        showAlertDialog(context, "Checked Out", "Leaving Time Updated");
        setState(() {
          _isCheckingIn = false;  // Reset to true to allow checking in the next day
        });
      } else {
        print("Failed to update attendance: ${updateResponse.body}");
        showAlertDialog(context, "Error", "Failed to update attendance. Please try again.");
      }
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
            createButton(_isCheckingIn ? "Attendance with Fingerprint" : "Check Out with Fingerprint", _authenticate),
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
