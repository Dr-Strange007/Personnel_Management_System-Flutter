import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_geofencing/easy_geofencing.dart';
import 'package:easy_geofencing/enums/geofence_status.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'AMS_Screen.dart';
import 'auth_screen.dart';

class MyGeoHomePage extends StatefulWidget {
  MyGeoHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyGeoHomePageState createState() => _MyGeoHomePageState();
}

class _MyGeoHomePageState extends State<MyGeoHomePage> {
  String geofenceStatus = '';
  bool isReady = false;
  Position? position;

  // Static geofence center coordinates
  static const double staticLatitude = 23.83636343; // Example latitude
  static const double staticLongitude = 90.3681472; // Example longitude
  static const int radius = 100; // Radius in meters

  final StreamController<GeofenceStatus> _broadcastGeofenceStatusController =
  StreamController<GeofenceStatus>.broadcast();
  StreamSubscription<GeofenceStatus>? _originalStreamSubscription;

  Future<void> requestPermissions() async {
    final statuses = await [
      Permission.location,
      Permission.locationAlways,
      Permission.locationWhenInUse
    ].request();
    print("Permission statuses: $statuses");
  }

  @override
  void initState() {
    super.initState();
    print("Initializing state...");
    requestPermissions().then((_) {
      print("Permissions requested.");
      startGeofencingService();
    });
  }

  void startGeofencingService() {
    print("Starting geofencing service...");
    EasyGeofencing.startGeofenceService(
      pointedLatitude: staticLatitude.toString(),
      pointedLongitude: staticLongitude.toString(),
      radiusMeter: radius.toString(),
      eventPeriodInSeconds: 5,
    );
    print("Geofencing service started.");
    initializeBroadcastStream();
  }

  void initializeBroadcastStream() {
    if (_originalStreamSubscription == null) {
      print("Initializing broadcast stream...");
      var originalStream = EasyGeofencing.getGeofenceStream();
      if (originalStream != null) {
        _originalStreamSubscription = originalStream.listen(
              (status) {
            print("Status from geofence stream: $status");
            _broadcastGeofenceStatusController.add(status);

            if (status == GeofenceStatus.enter) {
              SchedulerBinding.instance?.addPostFrameCallback((_) {
                print("Navigating to MyFaceApp...");
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceSelectionPage(),
                  ),
                );
              });
            } else if (status == GeofenceStatus.exit) {
              _showGeofenceExitDialog();
            }
          },
          onError: (error) {
            print("Error from geofence stream: $error");
            _broadcastGeofenceStatusController.addError(error);
          },
          onDone: () {
            print("Geofence stream closed");
            _broadcastGeofenceStatusController.close();
          },
        );
      } else {
        print("Original geofence stream is null. Retrying initialization...");
        // Retry initializing the broadcast stream after a delay
        Future.delayed(Duration(seconds: 5), initializeBroadcastStream);
      }
    } else {
      print("Broadcast stream already initialized.");
    }
  }

  void _showGeofenceExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Geofence Alert"),
        content: Text("You are not inside the radius. Please enter the designated area."),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close the dialog first
              await stopGeofencingService(); // Ensure the geofencing service is stopped
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => AuthScreen()),
                    (Route<dynamic> route) => false,
              );
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print("Disposing stream and controller...");
    _originalStreamSubscription?.cancel(); // Cancel the original stream subscription
    _originalStreamSubscription = null;
    _broadcastGeofenceStatusController.close(); // Close the broadcast stream controller
    super.dispose();
  }

  Future<void> stopGeofencingService() async {
    print("Stopping geofencing service...");
    await EasyGeofencing.stopGeofenceService();
      await _originalStreamSubscription!.cancel();
      _originalStreamSubscription = null;

    setState(() {
      isReady = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text("Geofence Center: Latitude $staticLatitude, Longitude $staticLongitude"),
            SizedBox(height: 10),
            Text("Geofence Radius: $radius meters"),
            SizedBox(height: 20),
            if (geofenceStatus.isEmpty)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Waiting for Geo fence Status. Please wait..."),
                  ],
                ),
              )
            else
              StreamBuilder<GeofenceStatus>(
                stream: _broadcastGeofenceStatusController.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    print("Geofence Status: ${snapshot.data}");
                    return Text(
                      "Geofence Status:\n${snapshot.data}",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    );
                  } else {
                    return Text(
                      "Waiting for geofence status...",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
