import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_geofencing/easy_geofencing.dart';
import 'package:easy_geofencing/enums/geofence_status.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';


import 'facial_recognition.dart';
import 'main.dart';

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

  StreamController<GeofenceStatus>? _broadcastGeofenceStatusController;
  StreamSubscription<GeofenceStatus>? _originalStreamSubscription;


  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.locationAlways,
      Permission.locationWhenInUse
    ].request();
  }
  @override
  void initState() {
    _originalStreamSubscription?.cancel(); // Cancel the original stream subscription
    _broadcastGeofenceStatusController?.close(); // Close the broadcast stream controller
    requestPermissions();
    super.initState();
    initializeBroadcastStream();
    //startGeofencingService(); // Consider where this should be ideally called
  }

  void initializeBroadcastStream() {
    _broadcastGeofenceStatusController?.close(); // Close the previous stream controller if exists
    _broadcastGeofenceStatusController = StreamController<GeofenceStatus>.broadcast();

    var originalStream = EasyGeofencing.getGeofenceStream();
    if (originalStream != null) {
      _originalStreamSubscription?.cancel(); // Cancel the previous subscription if exists
      _originalStreamSubscription = originalStream.listen(
              (status) {
            _broadcastGeofenceStatusController?.add(status);
          },
          onError: (error) {
            _broadcastGeofenceStatusController?.addError(error);
          },
          onDone: () {
            _broadcastGeofenceStatusController?.close();
          }
      );
    }
  }

  void startGeofencingService() {
    EasyGeofencing.startGeofenceService(
      pointedLatitude: staticLatitude.toString(),
      pointedLongitude: staticLongitude.toString(),
      radiusMeter: radius.toString(),
      eventPeriodInSeconds: 5,
    );

    // Listen to the broadcast stream multiple times as needed
    _broadcastGeofenceStatusController?.stream.listen((status) {
      setState(() {
        geofenceStatus = status.toString();
      });
    });

    // Additional listeners can be added similarly
  }

  @override
  void dispose() {
    _originalStreamSubscription?.cancel(); // Cancel the original stream subscription
    _broadcastGeofenceStatusController?.close(); // Close the broadcast stream controller
    super.dispose();
  }


  Future<void> stopGeofencingService() async {
    // Suppose EasyGeofencing.stopGeofenceService() returns a Future; if not, this part is fine as is
    await EasyGeofencing.stopGeofenceService();
    if (_originalStreamSubscription != null) {
      await _originalStreamSubscription!.cancel();
      _originalStreamSubscription = null;
    }
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
            ElevatedButton(
              onPressed: isReady ? null : () => startGeofencingService(),
              child: const Text("Start Geofencing"),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: () async =>{
                await stopGeofencingService(), // Ensure service is stopped before navigating
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyGeoHomePage(title: 'Easy Geofencing'),
                  ),
                ),
              },
              child: Text("Stop Geofencing"),
            ),
            SizedBox(height: 20),
            StreamBuilder<GeofenceStatus>(
              stream: _broadcastGeofenceStatusController?.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  print("Geofence Status:${snapshot.data}");
                  if (snapshot.data == GeofenceStatus.enter) {
                    SchedulerBinding.instance?.addPostFrameCallback((_) {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MyFaceApp(),
                          )
                      );
                    });
                  }

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