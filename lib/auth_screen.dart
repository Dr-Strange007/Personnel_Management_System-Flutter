import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'geo_fence.dart';
import 'dart:convert';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final _auth;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final  _otpController = TextEditingController();
  final  _displayNameController = TextEditingController();
  String _verificationId = '';
  bool _rememberMe = false;
  bool _isSigningIn = false;
  bool _isSigningUp = false;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? setUserName;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _loadRememberedCredentials();
  }

  void _loadRememberedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('rememberMe') ?? false) {
      _emailController.text = prefs.getString('email') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      setState(() {
        _rememberMe = true;
      });
    }
  }
  bool _validatePassword() {
    String password = _newPasswordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match.")),
      );
      return false;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must be at least 8 characters long.")),
      );
      return false;
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must contain at least one uppercase letter.")),
      );
      return false;
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must contain at least one lowercase letter.")),
      );
      return false;
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must contain at least one number.")),
      );
      return false;
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must contain at least one special character.")),
      );
      return false;
    }

    return true;
  }

  void _showSetPasswordDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Set Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                suffixIcon: IconButton(
                  icon: Icon(_isNewPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isNewPasswordVisible = !_isNewPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isNewPasswordVisible,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isConfirmPasswordVisible,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_validatePassword()) {
                try {
                  // Set the new password
                  await user.updatePassword(_newPasswordController.text);
                  Navigator.of(context).pop(); // Close the dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyGeoHomePage(title: "Geo Fencing"),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to set password: ${e.toString()}")),
                  );
                }
              }
            },
            child: Text("Set Password"),
          ),
        ],
      ),
    );
  }
  void _showVerificationCodeDialog(String verificationId, Function(String) onCodeVerified) {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,  // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter the code"),
          content: TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: "SMS Code"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                onCodeVerified(codeController.text.trim());
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> _promptForDisplayName(User? user) async {
    if (user == null) return;
    // Assume you have a text controller and a dialog setup to handle this
    String? displayName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Set Display Name"),
        content: TextField(
          controller: _displayNameController,
          decoration: InputDecoration(hintText: "Enter display name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _displayNameController.text),
            child: Text("Save"),
          ),
        ],
      ),
    );
    print("User Name Phone 2: $displayName");
    if (displayName != null && displayName.isNotEmpty) {

      await user.updateDisplayName(displayName);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', displayName);
      await user.reload();
      setUserName = prefs.getString('userName'); // Ensure the user profile is updated
      print("User Name Phone 3: $setUserName");
    }
  }


  void _saveRememberedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('email', _emailController.text);
      await prefs.setString('password', _passwordController.text);
    } else {
      await prefs.setBool('rememberMe', false);
      await prefs.remove('email');
      await prefs.remove('password');
    }
  }

  void _signUpWithEmail() async {
    setState(() {
      _isSigningUp = true;
    });
    try {
      final newUser = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      newUser.user?.sendEmailVerification();

      await _promptForDisplayName(newUser.user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User created. Please verify your email.")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MyGeoHomePage(title: "Geo Fencing"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    setState(() {
      _isSigningUp = false;
    });
  }

  void _signUpWithPhone(String formattedPhoneNumber) async {
    setState(() {
      _isSigningUp = true;
    });

    // Start phone number verification
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          // Sign in the user with the credential
          final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          User? newUser = userCredential.user;
          if (newUser != null) {
            // Now prompt to set a password
            _showSetPasswordDialog(newUser);
          } else {
            throw Exception('Failed to create user account.');
          }
        } catch (e) {
          _handleError(e.toString());
          setState(() {
            _isSigningUp = false;
          });
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        _handleError("Failed to verify phone number: ${e.message}");
        setState(() {
          _isSigningUp = false;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        _showVerificationCodeDialog(verificationId, (String smsCode) {
          // Callback function that gets called with the SMS code
          _verifySmsCode(verificationId, smsCode);
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _handleError("Verification code retrieval timeout");
        setState(() {
          _isSigningUp = false;
        });
      },
    );
  }


  bool _isEmail(String input) {
    // Regular expression pattern to check if input is an email
    RegExp emailRegExp = RegExp(r'\S+@\S+\.\S+');
    return emailRegExp.hasMatch(input);
  }

  bool _isPhoneNumber(String input) {
    // Regular expression pattern to check if input is a phone number
    RegExp phoneRegExp = RegExp(r'^\+?[\d\s]{3,}$'); // Modify this regex based on your expected phone number format
    return phoneRegExp.hasMatch(input);
  }

  String? _formatPhoneNumber(String input) {
    if (input.startsWith('+880')) {
      return input;  // Correctly formatted
    } else if (input.startsWith('01')) {
      return '+88$input';  // Add the country code prefix +88
    } else if (input.startsWith('1')) {
      return '+880$input';  // Add the country code prefix +880
    } else {
      return null;  // Indicate an invalid phone number
    }
  }

  void _signUpBasedOnInput() {
    String input = _emailController.text.trim();
    if (_isEmail(input)) {
      _signUpWithEmail();
    } else if (_isPhoneNumber(input)) {
      String? formattedPhoneNumber = _formatPhoneNumber(input);
      if (formattedPhoneNumber != null) {
        _signUpWithPhone(formattedPhoneNumber);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a valid phone number")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid email or phone number")),
      );
    }
  }

  void _signInBasedOnInput() {
    String input = _emailController.text.trim();
    if (_isEmail(input)) {
      _signInWithEmail();
    } else if (_isPhoneNumber(input)) {
      String? formattedPhoneNumber = _formatPhoneNumber(input);
      if (formattedPhoneNumber != null) {
        _signInWithPhone(formattedPhoneNumber);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a valid phone number")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid email or phone number")),
      );
    }
  }



  void _signInWithEmail() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      final user = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (user.user == null || !(user.user!.emailVerified)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please verify your email/phone first.")),
        );
        return;
      }
      final User? currentUser = _auth.currentUser;
      _saveRememberedCredentials();
      if (currentUser != null && currentUser?.displayName == null) {
        await _promptForDisplayName(currentUser);  // Prompt for display name if not set
      }
      else{
        print("CurrentUser : $currentUser");
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("email",_emailController.text);
      await prefs.setString("userId",currentUser!.uid);
      print("Auth set Email : $prefs.getString('email')");
      print("Auth set userID : $prefs.getString('userId')");
      //var username = await currentUser.updateDisplayName("Your Display Name");



      Navigator.pushReplacement(

        context,
        MaterialPageRoute(
          builder: (context) => MyGeoHomePage(title: "Geo Fencing"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    setState(() {
      _isSigningIn = false;
    });
  }

  void _signInWithPhone(String formattedPhoneNumber) async {
    setState(() {
      _isSigningIn = true;
    });


    User? currentUser = await _auth.currentUser;

    print("Phone Current User : $currentUser");

    if (currentUser != null && currentUser.phoneNumber == formattedPhoneNumber) {
      await _handleExistingUser(currentUser);
    } else {
      await _verifyPhoneNumber(formattedPhoneNumber);
    }
  }

  Future<void> _handleExistingUser(User currentUser) async {
    if (currentUser.displayName == null || currentUser.displayName!.isEmpty) {
      await _promptForDisplayName(currentUser);
    } else {
      print("User Name Phone 1: ${currentUser.displayName}");
    }

    await _updatePreferences(currentUser);
    _navigateToHome();
  }


  void _verifySmsCode(String verificationId, String smsCode) {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    _signInWithPhoneCredential(credential);
  }

  Future<void> _verifyPhoneNumber(String formattedPhoneNumber) async {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithPhoneCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        _handleError("Failed to verify phone number: ${e.message}");
      },
      codeSent: (String verificationId, int? resendToken) {
        _showVerificationCodeDialog(verificationId, (String smsCode) {
          // Callback function that gets called with the SMS code
          _verifySmsCode(verificationId, smsCode);
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _handleError("Verification code retrieval timeout");
      },
    );
  }

  Future<void> _signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user != null) {
        await _handleExistingUser(user);
      }
    } catch (e) {
      _handleError("Auto-sign in failed: ${e.toString()}");
    }
  }

  Future<void> _updatePreferences(User currentUser) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("phone", currentUser.phoneNumber ?? '');
    prefs.setString("userId", currentUser.uid);
    if(setUserName!.isEmpty || setUserName == null){
     await _promptForDisplayName(currentUser);
    }
    print("User Name Phone 4: $setUserName");

    prefs.setString("userName", setUserName ?? 'No Name');
    print("Auth set userId : ${currentUser.uid}");
    print("Auth set userName : $setUserName");
    print("Auth set userPhone : ${currentUser.phoneNumber}");
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MyGeoHomePage(title: "Geo Fencing")),
    );
    setState(() {
      _isSigningIn = false;
    });
  }

  void _handleError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {
      _isSigningIn = false;
    });
  }




  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        scopes: [
          'email',
          'https://www.googleapis.com/auth/userinfo.email',
        ],
      ).signIn();
      print("Google User Email: ${googleUser?.email}");

      if (googleUser == null) {
        setState(() {
          _isSigningIn = false;
        });
        return; // User cancelled the Google sign-in
      }
      User? currentUser = await _auth.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      final user = userCredential.user;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to retrieve user information")),
        );
        return;
      }

      print('Email Verified: ${user.emailVerified}');
      print('User Email : ${user.email }');
      //await user?.reload(); // Refresh user data from Firebase
      print('Email Verified after reload: ${currentUser?.emailVerified}');
      print('User Email after reload: ${currentUser?.email}');


      if (user != null && user.email != null && !user.emailVerified) {
        try {
          await user.sendEmailVerification();
          print("Verification email has been sent.");
        } catch (e) {
          print("Failed to send verification email: $e");
        }
      }
      if(user ==null){
        print("Null User");
      }
      else{
        print("currentUser ; $user");
    }
      print("New_User_Bool : $isNewUser");
      if (user.emailVerified || !isNewUser) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("userId",currentUser!.uid);
        await prefs.setString("email",user.email!);
        await prefs.setString("userName",user.displayName!);
        var uid = prefs.getString('userId');
        var userName = prefs.getString('userName');
        if(userName == null){
          _promptForDisplayName(user);
        }

        //userName = prefs.getString('displayName');
        var email = prefs.getString('email');
        print("Auth set userId : $uid");
        print("Auth set userName : $userName");
        print("Auth set userEmail : $email");

        var url = Uri.parse('http://192.168.1.111:8080/dscsc_for_app/api/getScoreCardMarks');
        try {
          var response = await http.post(url, body: {
            'employee_id': currentUser.uid.toString(),
            'name': userName,
            'email': email,  // Optional: Add default values or leave blank
            'uid': currentUser.uid.toString(),
            'phone': currentUser.phoneNumber ?? ''// Optional: Set employee_id as uid if suitable
          });

          if (response.statusCode == 200) {
            print('Data sent successfully');
            print(json.decode(response.body));
          } else {
            print('Failed to send data. Status code: ${response.statusCode}');
            print((response.body));
          }
        } catch (e) {
          print('Error sending data: $e');
        }



        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MyGeoHomePage(title: "Geo Fencing"),
          ),
        );
      } else if (isNewUser) {
        // New user, prompt to set password
        _showSetPasswordDialog(user);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign in failed: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  void _forgotPassword() async {
    String input = _emailController.text.trim(); // Get the user input and trim any whitespace

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your Email or Phone.")),
      );
      return;
    }

    bool isEmail = RegExp(r'\S+@\S+\.\S+').hasMatch(input);

    try {
      if (isEmail) {
        await _auth.sendPasswordResetEmail(email: input);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password reset email sent.")),
        );
      } else {
        await _auth.verifyPhoneNumber(
            phoneNumber: input,
            verificationCompleted: (PhoneAuthCredential credential) async {
              // Automatically called when Firebase auto-verifies the SMS code
              try {
                final userCredential = await _auth.signInWithCredential(credential);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Verification automatically completed")),
                );
                final user = userCredential.user;
                if (user != null) {
                  // If you need the user to reset their password, you might call another function here
                  _showSetPasswordDialog(user); // Assuming you want to reset the password after auto-verification
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to auto-sign in with SMS code: ${e.toString()}")),
                );
              }
            },
            verificationFailed: (FirebaseAuthException e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed to verify phone number: ${e.message}")),
              );
            },
            codeSent: (String verificationId, int? resendToken) {
              _showVerificationCodeDialog(verificationId, (String smsCode) async {
                try {
                  PhoneAuthCredential credential = PhoneAuthProvider.credential(
                    verificationId: verificationId,
                    smsCode: smsCode,
                  );
                  final userCredential = await _auth.signInWithCredential(credential);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Verification successful, please set your new password.")),
                  );
                  final user = userCredential.user;
                  if (user != null) {
                    _showSetPasswordDialog(user);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to verify SMS code: ${e.toString()}")),
                  );
                }
              });
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Verification code retrieval timeout")),
              );
            }
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send reset email: ${e.toString()}")),
      );
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Firebase Auth")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email or Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Checkbox(
                  value: _rememberMe,
                  onChanged: (bool? value) {
                    setState(() {
                      _rememberMe = value!;
                    });
                  },
                ),
                const Text('Remember me'),
                const Spacer(),
                TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSigningIn ? null : _signInBasedOnInput,
              child: _isSigningIn
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 10),
                  Text('Signing In...'),
                ],
              )
                  : const Text('Sign In'),
            ),
            const SizedBox(height: 20),
            Divider(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSigningUp ? null : _signUpBasedOnInput,
              child: _isSigningUp
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 10),
                  Text('Signing Up...'),
                ],
              )
                  : Text('Sign Up'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSigningIn ? null : _signInWithGoogle,
              child: _isSigningIn
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 10),
                  Text('Signing In...'),
                ],
              )
                  : Text('Sign Up with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
