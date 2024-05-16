import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'geo_fence.dart'; // Import other pages if needed

class FingerprintLoginPage extends StatefulWidget {
  @override
  _FingerprintLoginPageState createState() => _FingerprintLoginPageState();
}

class _FingerprintLoginPageState extends State<FingerprintLoginPage> {
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  bool _isFingerprintAvailable = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MyGeoHomePage(title: 'Easy Geofencing'),
        ),
      );
    }
  }

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
            ElevatedButton(
              onPressed: _authenticate,
              child: Text('Authenticate with Fingerprint'),
            ),
            SizedBox(height: 20),
            _isAuthenticated
                ? Text('Logged in successfully with fingerprint')
                : SizedBox(),
          ],
        )
            : Text('Fingerprint not available on this device'),
      ),
    );
  }
}
