import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_face_api/face_api.dart' as faceApi; // Use an alias for faceApi

class MyFaceApp extends StatefulWidget {
  @override
  _MyFaceAppState createState() => _MyFaceAppState();
}

class _MyFaceAppState extends State<MyFaceApp> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isFaceRegistered = false;
  String _registeredFilePath = "";
  String _similarity = "nil";
  String _liveness = "nil";
  double _faceMatchScore = 0.0;
  Image imageDisplay = Image.asset('assets/images/portrait.png');

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    checkFaceRegistration();
  }

  Future<void> checkFaceRegistration() async {
    final doc = await _firestore.collection('users').doc(_currentUser?.uid).get();
    if (doc.exists && doc['face_image_path'] != null) {
      setState(() {
        _isFaceRegistered = true;
        _registeredFilePath = doc['face_image_path'];
        imageDisplay = Image.file(io.File(_registeredFilePath));
      });
    } else {
      setState(() {
        _isFaceRegistered = false;
      });
    }
  }

  Future<void> registerFace() async {
    if (_isFaceRegistered) {
      print("Face already registered.");
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      var imageBytes = await pickedFile.readAsBytes();
      setState(() {
        imageDisplay = Image.memory(imageBytes);
        _liveness = "nil"; // Reset liveliness when registering a new face
      });
      var filePath = await getLocalPath() + "/registeredFace.jpg";
      io.File(filePath).writeAsBytesSync(imageBytes);
      setState(() => _registeredFilePath = filePath);
      print("Face registered and saved at $filePath");

      // Save user data to Firestore
      await _firestore.collection('users').doc(_currentUser?.uid).set({
        'name': _currentUser?.displayName,
        'employee_id': _currentUser?.uid,
        'face_image_path': filePath,
        // Other user data
      }, SetOptions(merge: true));

      setState(() {
        _isFaceRegistered = true;
      });
    }
  }

  Future<String> getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> recognizeFace() async {
    if (!_isFaceRegistered) {
      print("Face not registered.");
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      print("No image captured.");
      return;
    }

    var currentImageBytes = await pickedFile.readAsBytes();
    await matchFaces(currentImageBytes);
  }

  Future<void> matchFaces(Uint8List currentImageBytes) async {
    try {
      print("Starting face matching...");
      var registeredImageBytes = io.File(_registeredFilePath).readAsBytesSync();
      print("Registered image size: ${registeredImageBytes.length}");

      var registeredImage = faceApi.MatchFacesImage();
      registeredImage.imageType = 1;
      registeredImage.bitmap = base64Encode(registeredImageBytes); // Assume imageType 1 is correct
      var currentImage = faceApi.MatchFacesImage();
      currentImage.imageType = 1;
      currentImage.bitmap = base64Encode(currentImageBytes);

      var request = faceApi.MatchFacesRequest();
      request.images = [registeredImage, currentImage];
      String value = await faceApi.FaceSDK.matchFaces(jsonEncode(request.toJson()));
      print("Face matching response: $value");

      var response = faceApi.MatchFacesResponse.fromJson(json.decode(value));
      if (response!.results.isNotEmpty && response.results[0]!.similarity != null) {
        setState(() {
          _similarity = "${(response.results[0]!.similarity! * 100).toStringAsFixed(2)}%";
          _faceMatchScore = response.results[0]!.similarity! * 100;
        });
        print("Match found: Similarity $_similarity");

        // Update Firestore only if similarity is 80% or above
        if (_faceMatchScore >= 80) {
          await logAttendance();
        }
      } else {
        setState(() {
          _similarity = "No match found";
          _faceMatchScore = 0.0;
        });
        print("No match found.");
      }
      await liveness();
    } catch (e) {
      print("An error occurred during face matching: $e");
      setState(() {
        _similarity = "Error in processing";
        _faceMatchScore = 0.0;
      });
    }
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
        'similarity': _similarity,
        'liveness': _liveness,
        // Other relevant details
      });
      print("Entering time logged.");
    } else {
      // Entry for today exists, update it with leaving time
      var attendanceDoc = attendanceQuery.docs.first;
      await _firestore.collection('attendance_logs').doc(attendanceDoc.id).update({
        'leaving_time': timeNow,
      });
      print("Leaving time logged.");
    }
  }

  Future<void> liveness() async {
    try {
      var result = await faceApi.FaceSDK.startLiveness();
      var livenessResponse = faceApi.LivenessResponse.fromJson(jsonDecode(result));

      setState(() {
        _liveness = livenessResponse!.liveness.toString();
      });
    } catch (e) {
      print("Error during liveness check: $e");
      setState(() {
        _liveness = "Error";
      });
    }
  }

  Widget createButton(String text, VoidCallback onPress) => Container(
    width: 250,
    child: TextButton(
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.all<Color>(Colors.blue),
        backgroundColor: MaterialStateProperty.all<Color>(Colors.black12),
      ),
      onPressed: onPress,
      child: Text(text),
    ),
  );

  Widget createImage(image, VoidCallback onPress) => InkWell(
    onTap: onPress,
    child: Container(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Image(height: 150, width: 150, image: image),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            createImage(imageDisplay.image, () => registerFace()),
            if (!_isFaceRegistered) createButton("Register Face", registerFace),
            createButton("Recognize Face", recognizeFace),
            Text("Similarity: $_similarity", style: TextStyle(fontSize: 18)),
            Text("Face Match Score: ${_faceMatchScore.toStringAsFixed(2)}%", style: TextStyle(fontSize: 18)),
            Text("Liveness: $_liveness", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
