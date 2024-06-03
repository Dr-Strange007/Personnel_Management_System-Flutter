import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'AMS_Screen.dart';
import 'auth_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ManualAttendancePage extends StatefulWidget {
  @override
  _ManualAttendancePageState createState() => _ManualAttendancePageState();
}

class _ManualAttendancePageState extends State<ManualAttendancePage> {
  final TextEditingController _reasonController = TextEditingController();
  final String apiUrl = 'http://192.168.1.130:8000/api'; // Your API URL
  bool _isLoading = false;
  String? _userId;
  int? userId;
  String? _userName;
  String? email;
  String? phone;
  bool _isCheckingIn = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? employeeId = prefs.getString('userId');
    userId = await _fetchUserIdFromEmployeeId(employeeId!);
    print("Manual UserId : $userId");
    if (userId !=null){
      setState(() {
        _userName = prefs.getString('userName');
        email = prefs.getString('email');
        phone = prefs.getString('phone');
      });
    }else if(userId == null){

      _userName = prefs.getString('userName');
      email = prefs.getString('email');
      phone = prefs.getString('phone');

      userId = await _createUser(employeeId, _userName, email, phone);

    }


    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not found, please login.')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AuthScreen())); // Your login route
    }
  }

  Future<int?> _fetchUserIdFromEmployeeId(String employeeId) async {
    var response = await http.get(Uri.parse('$apiUrl/get-user-id/?employee_id=$employeeId'));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['id'];
    } else if (response.statusCode == 404) {
      // User not found with employee ID, might prompt creation or handle it elsewhere
      print("User not found with employee ID: $employeeId, consider creating one.");
      return null;
    } else {
      // Handle other possible errors like 500 server error, etc.
      print("Failed to retrieve user with HTTP status: ${response.statusCode}");
      return null;
    }
  }

  Future<int?> _createUser(String employeeId, String? userName, String? email, String? phone) async {
    var newUser = {
      'employee_id': employeeId,
      'name': userName,
      'email': '',  // Optional: Add default values or leave blank
      'uid': employeeId, // Optional: Set employee_id as uid if suitable
      'phone' : phone,

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



  void _logAttendance() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please login to log attendance.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    tz.initializeTimeZones();
    var location = tz.getLocation('Asia/Dhaka');
    var now = tz.TZDateTime.now(location);
    var today = now.toIso8601String().split('T')[0];
    var timeNow = now.toIso8601String().split('T')[1].split('.')[0];
    print("Manual UserId : $userId");

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
      try {
        var newLog = {
          'user': userId,
          'name': _userName,
          'date': today,
          'entering_time': timeNow,
          'similarity': 100,
          'method': 'manual',
          'is_approved' : false,
        };
        final response = await http.post(
          Uri.parse('$apiUrl/attendance_logs/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newLog),
        );
        print("Manual Attendance Post Response: ${response.body}");
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Attendance logged and pending approval')));
        } else {
          throw Exception('Failed to log attendance');
        }
      } catch (e) {
        print('Manual Error : ${e.toString()}');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }

    else {
      // Entry for today exists, update leaving time
      try {
        var existingLog = filteredLogs[0]; // Assuming the API returns a list
        var updateUri = Uri.parse(
            '$apiUrl/attendance_logs/${existingLog['id']}/');
        var updateLog = {
          'leaving_time': timeNow,
          'is_approved' : false,
        };
        var updateResponse = await http.patch(
            updateUri, body: jsonEncode(updateLog),
            headers: {'Content-Type': 'application/json'});
        print("Attendance Update Response: ${updateResponse.body}");
        if (updateResponse.statusCode == 200) {
          showAlertDialog(context, "Checked Out", "Leaving Time Updated.Waiting for admin approval...");
          setState(() {
            _isCheckingIn =
            false; // Reset to true to allow checking in the next day
          });
        } else {
          print("Failed to update attendance: ${updateResponse.body}");
          showAlertDialog(context, "Error",
              "Failed to update attendance. Please try again.");
        }
      }catch (e) {
        print('Manual Error : ${e.toString()}');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      } finally {
        setState(() {
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual Attendance'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for Manual Attendance',
                hintText: 'Why are you logging manually?',
              ),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _logAttendance,
              child: Text('Log Attendance Manually'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
