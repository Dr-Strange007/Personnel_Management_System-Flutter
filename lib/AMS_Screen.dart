import 'package:flutter/material.dart';

import 'facial_recognition.dart';
import 'fingerprint_login_page.dart';
import 'manual_attendace.dart';

class AttendanceSelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance Log System"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AttendanceOption(
              title: "Finger ID",
              icon: Icons.fingerprint,
              color: Colors.blueAccent,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FingerprintLoginPage()),
                );
              },
            ),
            SizedBox(height: 20),
            AttendanceOption(
              title: "Facial Recognition",
              icon: Icons.face,
              color: Colors.green,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyFaceApp()),
                );
              },
            ),
            SizedBox(height: 20),
            AttendanceOption(
              title: "Manual",
              icon: Icons.edit,
              color: Colors.orange,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManualAttendancePage()),
                );

              },
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  AttendanceOption({
    required this.title,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withOpacity(0.1),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


