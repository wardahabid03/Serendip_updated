import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/routes.dart';
import '../providers/auth_provider.dart';
import '../colors.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController(); // New username field
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submitAuthForm(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text;
    final password = _passwordController.text;
    final username = _emailController.text; // Currently same username and email, needed to be corrected later
    if (kDebugMode) {
      print('Submitting form...');
      print('Email: $email');
      print('Password: $password');
      print('Username (if signing up): $username');
    }

    if (!_isLogin && (username.isEmpty || username.length < 3)) {
      if (kDebugMode) {
        print("Username condition failed: $username");
      }
      _showErrorSnackbar('Username must be at least 3 characters long.');
      return;
    }

    if (email.isEmpty || !RegExp(r'^[\w-]+@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(email)) {
      _showErrorSnackbar('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      _showErrorSnackbar('Password must be at least 6 characters long.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        print('Logging in...');
        await authProvider.login(email, password);
      } else {
        print('Signing up...');
        await authProvider.signUp(email, password, username); // Pass username for sign up
      }

      if (authProvider.userModel != null) {
        print('Authentication successful, navigating to map...');
        Navigator.of(context).pushReplacementNamed(AppRoutes.map);
      } else {
        print('User model is null after authentication.');
      }
    } catch (e) {
      print('Authentication failed: ${e.toString()}');
      _showErrorSnackbar(authProvider.errorMessage ?? 'Authentication failed.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('Loading state reset.');
    }
  }

  Future<void> _googleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      print('Attempting Google Sign-In...');
      await authProvider.signInWithGoogle();
      if (authProvider.userModel != null) {
        print('Google Sign-In successful, navigating to map...');
        Navigator.of(context).pushReplacementNamed(AppRoutes.map);
      }
    } catch (e) {
      print('Google Sign-In failed: ${e.toString()}');
      _showErrorSnackbar('Google Sign-In failed: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    print('Showing snackbar with message: $message');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    print('Disposing controllers...');
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose(); // Dispose username controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building AuthScreen...');
    return Scaffold(
      backgroundColor: Colors.teal,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100.0, // Height of the white space
              color: Colors.white,
            ),
            SizedBox(height: 10), // Adjust the height for proper positioning
            Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Image.asset('assets/images/loc.jpg', height: 100.0, width: 100.0), // Placeholder for the top logo
            ),
            SizedBox(height: 20),
            // Login Heading
            if (_isLogin)
              const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              )
            else
              Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),
            SizedBox(height: 30),
            // Email Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Email',
                  contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            SizedBox(height: 20),
            // Password Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Password',
                  contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: true,
              ),
            ),
            SizedBox(height: 10),
            // Forgot Password Button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 30.0),
                child: TextButton(
                  onPressed: () {
                    // Handle Forgot Password
                    print('Forgot Password pressed');
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: tealColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            // Login Button
            if (_isLoading)
              CircularProgressIndicator()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: ElevatedButton(
                  onPressed: () => _submitAuthForm(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    child: Text(
                      _isLogin ? 'Log In' : 'Sign Up',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: eggShellColor, 
                    backgroundColor: tealColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(color: eggShellColor, width: 2),
                    ),
                  ),
                ),
              ),
            SizedBox(height: 20),
            // Google Sign-In Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: ElevatedButton(
                onPressed: _googleSignIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  child: Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black, // Change the text color
                  backgroundColor: Colors.white, // Google sign-in button color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.grey, width: 2),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            // Sign-up option
            Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                      print('Toggle login/signup state: $_isLogin');
                    },
                    child: Text(
                      'Sign up',
                      style: TextStyle(
                        color: tealColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
