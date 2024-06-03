import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'AMS_Screen.dart';
import 'image_bloc.dart';  // Adjust the path as necessary
import 'package:flutter_face_api/face_api.dart' as faceApi;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MyFaceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ImageBloc(),
      child: MyFaceHomePage(),
    );
  }
}

class MyFaceHomePage extends StatefulWidget {
  @override
  _MyFaceHomePageState createState() => _MyFaceHomePageState();
}

class _MyFaceHomePageState extends State<MyFaceHomePage> {
  final String apiUrl = 'http://192.168.1.130:8000/api'; // Change to your API URL
  Completer<void> _initCompleter = Completer<void>();
  Future<void>? _initFuture;
  late bool _isFaceRegistered = false;
  String _registeredFilePath = "";
  String _similarity = "nil";
  String _liveness = "nil";
  double _faceMatchScore = 0.0;
  Image imageDisplay = Image.asset('assets/images/portrait.png');
  bool _isCheckingIn = true;
  String? _userId;
  int? userId;
  bool _isMatching = false;
  int? id;
  String? remoteImagePath = '';
  String? finalImagePath = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  void _initializeApp() {
    if (_initFuture != null) {
      return;
    }
    _initFuture = initializeUserDetails()
        .then((_) {
      BlocProvider.of<ImageBloc>(context, listen: false).add(LoadImage());
      _initCompleter.complete();
    })
        .catchError((error) {
      _initCompleter.completeError(error);
    });
  }

  Future<void> initializeUserDetails() async {
    var url = Uri.parse('http://192.168.1.111:8080/dscsc_for_app/api/getScoreCardMarks');
    var info1 = {
        'name': 'John Doe',
        'age': "30"

    };
    try {
      var response = await http.post(url, body: (info1));

      if (response.statusCode == 200) {
        print('Data sent successfully');
        print(json.decode(response.body));
      } else {
        print('Failed to send data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data: $e');
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? employeeId = prefs.getString('userId');
    print("UserID on Face $prefs.getString('userId')");
    if (employeeId == null) {
      print("No employee ID found. Please login.");
      return; // Redirect to login or show error
    }

    print("User Id/Employee Id: $employeeId");
    userId = await _fetchUserIdFromEmployeeId(employeeId);
    print("User_ID 1: $userId");


    if (userId == null) {
      // User not found, try to create new user
      String? userName = prefs.getString('userName');
      String? email = prefs.getString('email');
      String? phone = prefs.getString('phone');
      userId = await _createUser(employeeId, userName, email, phone);
      print("MyFaceHomePage UserId : $userId");
      prefs.setInt('Id',userId!);
      if (userId == null) {
        print("Failed to create a new user.");
        return; // Handle error appropriately
      }
    }

    print("User_ID: $userId");
    prefs.setInt("id", userId!);
    await fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    var response = await http.get(Uri.parse('$apiUrl/users/$userId/'));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data['face_image_path'] != null && data['face_image_path'].isNotEmpty) {
        _isFaceRegistered = true;
        await _loadFaceImage(data['face_image_path']);
      } else {
        _isFaceRegistered = false;
        print("User has no face image registered. Show 'Register Face' button.");
        // Show button allowing them to register/upload a face image
      }
    } else {
      print("Failed to fetch user details: ${response.statusCode}");
    }
  }

  Future<void> _loadFaceImage(String imagePath) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    print("Image Path ; $imagePath");
    if (imagePath != null && imagePath.isNotEmpty) {
      prefs.setString('face_image_path', imagePath);
      await _storeFaceImagePath(userId);
      print("Image loaded from path: $imagePath");
    } else {
      print("No image path stored");
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



  Future<String?> _storeFaceImagePath(int? userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? localImagePath = prefs.getString('face_image_path');

    if (localImagePath != null && await io.File(localImagePath).exists()) {
      await _setImageDisplay(localImagePath);
      return localImagePath;
    } else {
      // Fetch from backend
      var response = await http.get(Uri.parse('$apiUrl/users/$userId/face_image/'));
      if (response.statusCode == 200) {
        var userData = jsonDecode(response.body);
        String? imagePath = userData['image_url'];
        if (imagePath != null) {
          prefs.setString('face_image_path', imagePath);
          await _setImageDisplay(imagePath);
          return imagePath;
        }
      }
      print("Failed to fetch or invalid image path: ${response.statusCode}");
      return null;
    }
  }


  Future<int?> _createUser(String employeeId, String? userName, String? email, String? phone) async {
    var newUser = {
      'employee_id': employeeId,
      'name': userName,
      'email': email,  // Optional: Add default values or leave blank
      'uid': employeeId,
      'phone': phone// Optional: Set employee_id as uid if suitable
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

  Future<void> checkAttendanceStatus() async {
    if (_userId == null) return; // Ensure _userId is not null
    var now = DateTime.now();
    var today = now.toIso8601String().split('T')[0];

    print("Today ; $today");
    final response = await http.get(Uri.parse('$apiUrl/attendance_logs/?user=$userId&date=$today'));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        setState(() {
          _isCheckingIn = false; // Assuming "isCheckingIn" means the user has already checked in
        });
      }
    }
  }

  Future<void> downloadAndSaveImage(String imageUrl, String filename) async {
    var response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      var directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$filename';
      io.File file = io.File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      setState(() {
        _registeredFilePath = filePath;
        _isFaceRegistered = true;
      });
    } else {
      print('Failed to download image: ${response.statusCode}');
    }
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
    if (mounted) setState(() {
      _isMatching = true;
    });
    await matchFaces(currentImageBytes);
    if (mounted) setState(() {
      _isMatching = false;
    });
  }

  Future<void> matchFaces(Uint8List currentImageBytes) async {
    try {
      print("Starting face matching...");
      if (_registeredFilePath.startsWith('http')) {
        await downloadAndSaveImage(_registeredFilePath, "$_userId face.jpg");
      }
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

      //var responseJson = await faceApi.matchFaces(request);
      var response = faceApi.MatchFacesResponse.fromJson(jsonDecode(value));
      if (response!.results.isNotEmpty && response.results[0]!.similarity != null) {
        if (mounted) setState(() {
          _similarity = "${(response.results[0]!.similarity! * 100).toStringAsFixed(2)}%";
          _faceMatchScore = response.results[0]!.similarity! * 100;
        });
        print("Match found: Similarity $_similarity");

        // Log attendance if similarity is 80% or above
        if (_faceMatchScore >= 80) {
          await logAttendance();
          print("matchFaces_similarity $_similarity");
        } else {
          showAlertDialog(context, "Face doesn't match", "Please try again or contact admin.");
        }
      } else {
        if (mounted) setState(() {
          _similarity = "No match found";
          _faceMatchScore = 0.0;
        });
        print("No match found.");
        showAlertDialog(context, "Face doesn't match", "Please try again or contact admin.");
      }
    } catch (e) {
      print("An error occurred during face matching: $e");
      setState(() {
        _similarity = "Error in processing $e";
        _faceMatchScore = 0.0;
      });
      showAlertDialog(context, "Error", "Attendance couldn't be logged. Try again or contact admin.");
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

  Future<void> logAttendance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userName = prefs.getString('userName');

    tz.initializeTimeZones();
    var location = tz.getLocation('Asia/Dhaka');
    var now = tz.TZDateTime.now(location);
    var today = now.toIso8601String().split('T')[0];
    print("Roday ; $today");

    var timeNow = now.toIso8601String().split('T')[1].split('.')[0];
    print("Today Time ; $timeNow");

    print("Todays Date in Dhaka: $today");
    print("Current Time Now: $timeNow");

    // Fetch existing attendance log for today
    var checkResponse = await http.get(Uri.parse('$apiUrl/attendance_logs/?user_id=$userId&date=$today'));
    print('Response status: ${checkResponse.statusCode}');
    print('Response body: ${checkResponse.body}');
    var existingLogs = jsonDecode(checkResponse.body);

    // Filter the existing logs by user_id and date
    var filteredLogs = existingLogs.where((log) {
      return log['user'] == userId && log['date'] == today;
    }).toList();
    print("filteredLogs_face : $filteredLogs");

    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (filteredLogs.isEmpty && _isCheckingIn) {
      String cleanedString = _similarity.replaceAll(RegExp(r'[^0-9.]'), '');
      double.parse(cleanedString);
      print("matchFaces_similarity2 $cleanedString");
      // No entry for today, create a new one with entering time
      var newLog = {
        'user': userId,
        'name': userName,
        'date': today,
        'entering_time': timeNow,
        'similarity': cleanedString,
        'method': 'face_id',
      };
      var postUri = Uri.parse('$apiUrl/attendance_logs/');
      var response = await http.post(postUri, body: jsonEncode(newLog), headers: headers);
      print("Attendance Post Response: ${response.body}");
      if (response.statusCode == 201) {
        showAlertDialog(context, "Attendance Logged", "Checked In");
        setState(() {
          _isCheckingIn = false;  // Toggle to false after successful check-in
        });
      } else {
        print("Failed to log attendance: ${response.body}");
        showAlertDialog(context, "Error", "Failed to log attendance. Please try again.");
      }
    } else if (!filteredLogs.isEmpty) {
      // Entry for today exists, update leaving time
      var existingLog = filteredLogs[0];  // Assuming the API returns a list
      var updateUri = Uri.parse('$apiUrl/attendance_logs/${existingLog['id']}/');
      var updateLog = {
        'leaving_time': timeNow,
      };
      var updateResponse = await http.patch(updateUri, body: jsonEncode(updateLog), headers: headers);
      print("Attendance Update Response: ${updateResponse.body}");
      if (updateResponse.statusCode == 200) {
        showAlertDialog(context, "Checked Out", "Leaving Time Updated");
        setState(() {
          _isCheckingIn = true;  // Reset to true to allow checking in the next day
        });
      } else {
        print("Failed to update attendance: ${updateResponse.body}");
        showAlertDialog(context, "Error", "Failed to update attendance. Please try again.");
      }
    }
  }

  Future<String> getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Helper method to determine the correct image provider
  Future<void> _setImageDisplay (String imagePath) async  {
    ImageProvider<Object> imageProvider;
    print("I should not be printed 0");
    if (imagePath.startsWith('http')) {
      // Correctly use NetworkImage for URLs
      imageProvider = NetworkImage(imagePath);
      print("I should not be printed 2");
    } else {
      // Local files continue to use FileImage
      imageProvider = FileImage(io.File(imagePath));
      print("I should not be printed 1");
    }
    if(mounted)setState(() {
      _registeredFilePath = imagePath;
      _isFaceRegistered = true;
      imageDisplay = Image(image: imageProvider);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition Attendance'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            BlocBuilder<ImageBloc, ImageState>(
              builder: (context, state) {
                return _buildImageState(context, state);
              },
            ),
            _isMatching
                ? Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text("Matching..."),
              ],
            )
                : ElevatedButton(
              onPressed: () => recognizeFace(),
              child: Text('Recognize Face'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageState(BuildContext context, ImageState state) {
    if (state is ImageLoaded) {
      // Trigger image display update
      _setImageDisplay(state.imagePath);  // Assuming imagePath changes trigger the update correctly

      // Return the current image display widget
      return imageDisplay;  // Ensure `imageDisplay` is updated by `_setImageDisplay`
    } else if (state is FaceRegistrationNeeded) {
      return Column(
        children: [
          Text("No face registered."),
          ElevatedButton(
            onPressed: _registerFace,
            child: Text('Register Face'),
          ),
        ],
      );
    } else if (state is ImageError) {
      return Text(state.error);
    } else if (state is FaceRegistrationLoading) {
      return CircularProgressIndicator();
    }
    return Text('Welcome! Please wait or tap to load your profile.');
  }


  void _registerFace() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      context.read<ImageBloc>().add(RegisterImage(file));
    }
  }
}
