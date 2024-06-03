import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
part 'image_event.dart';
part 'image_state.dart';

class ImageBloc extends Bloc<ImageEvent, ImageState> {
  ImageBloc() : super(ImageInitial()) {
    on<LoadImage>(_onLoadImage);
    on<RegisterImage>(_onRegisterImage);
    on<FetchUserDetailsEvent>(_onFetchUserDetails);// Add handler for matching faces
  }

  final http.Client httpClient = http.Client();
  final String apiUrl = 'http://192.168.1.130:8000/api';

  void _onLoadImage(LoadImage event, Emitter<ImageState> emit) async {
    emit(FaceRegistrationLoading());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString('face_image_path');
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      print('File exists: ${file.existsSync()}');  // Check if file actually exists
      emit(ImageLoaded(imagePath));
    } else {
      emit(FaceRegistrationNeeded());  // Emit this when no image is found
    }
  }

  FutureOr<void> _onRegisterImage(RegisterImage event, Emitter<ImageState> emit) async {
    emit(FaceRegistrationLoading());
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('id');
      print("Image Bloc UserId : $userId");
      if (userId == null) {
        emit(FaceRegistrationFailure("User ID is not available"));
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final File file = File('$path/registeredFace.jpg');
      final imageBytes = await event.file.readAsBytes();
      await file.writeAsBytes(imageBytes);

      final Uri uri = Uri.parse('$apiUrl/users/upload_face/');
      var request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'face.jpg'))
        ..fields['user_id'] = userId.toString();

      var response = await request.send();
      print("Image Bloc respomse : $response.statusCode");
      if (response.statusCode == 200) {
        final responseBody = await http.Response.fromStream(response);
        prefs.setString('face_image_path', file.path);
        emit(FaceRegistrationSuccess(file.path));
        print('Face registered successfully with path: ${file.path}');
      } else {
        final responseBody = await http.Response.fromStream(response);
        print("Failed to upload image: ${response.statusCode}, Body: ${responseBody.body}");
        emit(FaceRegistrationFailure("Failed to upload image: HTTP status code ${response.statusCode}, Details: ${responseBody.body}"));
      }
    } catch (e) {
      print("An error occurred during image registration: $e");
      emit(FaceRegistrationFailure("Error during image registration: $e"));
    }
  }




  void _onFetchUserDetails(FetchUserDetailsEvent event, Emitter<ImageState> emit) async {
    emit(FaceRegistrationLoading());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    if (userId == null) {
      emit(ImageError("User ID not found"));
      return;
    }

    var response = await http.get(Uri.parse('$apiUrl/get-user-id/?employee_id=$userId'));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data['face_image_path'] != null && data['face_image_path'].isNotEmpty) {
        var imageUrl = '$apiUrl/media/${data['face_image_path']}';
        emit(ImageLoaded(imageUrl));
        prefs.setString('face_image_path', imageUrl);  // Update path in preferences
      } else {
        emit(FaceRegistrationNeeded());
      }
    } else if (response.statusCode == 404) {
      // Handle user not found
      emit(ImageError("User not found"));
    } else {
      emit(ImageError("Failed to fetch user details: ${response.statusCode}"));
    }
  }
}