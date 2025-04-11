import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes.dart';
import 'auth_provider.dart';
import '../../core/constant/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Email validation regex
  final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    caseSensitive: false,
  );

  // // Password validation regex
  // final _passwordRegex = RegExp(
  //   r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$',
  // );

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = 'Email is required*';
      } else if (!_emailRegex.hasMatch(value)) {
        _emailError = 'Please enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required*';
      } else if (value.length < 8) {
        _passwordError = 'Must be at least 8 characters';
      } else if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
        _passwordError = 'Must contain at least one letter';
      } else if (!RegExp(r'\d').hasMatch(value)) {
        _passwordError = 'Must contain at least one number';
      } else {
        _passwordError = null;
      }
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value != _passwordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: eggShellColor),
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitAuthForm(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate all fields
    _validateEmail(email);
    _validatePassword(password);
    if (!_isLogin) {
      _validateConfirmPassword(confirmPassword);
    }

    // Check if there are any validation errors
    if (_emailError != null ||
        _passwordError != null ||
        (!_isLogin && _confirmPasswordError != null)) {
      _showToast('Please fix the errors before continuing');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await authProvider.login(email, password, context);
      } else {
        await authProvider.signUp(email, password, context);
      }

 if (authProvider.errorMessage != null) {
  String message = authProvider.errorMessage!;
  
  if (message.contains('email-already-in-use')) {
    message = 'Email already in use.';
  } else if (message.contains('user-not-found')) {
    message = 'User not found.';
  } else if (message.contains('wrong-password')) {
    message = 'Wrong password.';
  } else if (message.contains('network-request-failed')) {
    message = 'No internet connection.';
  } else {
    message = 'Something went wrong.';
  }

  _showErrorDialog('Error', message);
}


    } catch (e) {
      _showErrorDialog(
        'Authentication Error',
        authProvider.errorMessage ?? 'An unexpected error occurred',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  color: Colors.white,
                ),
                Column(
                  children: [
                    SizedBox(height: 100),
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(80),
                      ),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.95,
                        width: double.infinity,
                        color: tealColor,
                        child: Column(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.09),
                            Text(
                              _isLogin ? 'Log In' : 'Sign Up',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: eggShellColor,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 30.0),
                              child: TextField(
                                controller: _emailController,
                                onChanged: _validateEmail,
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  helperText: _emailError,
                                  helperStyle: const TextStyle(
                                      color: eggShellColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight
                                          .bold), // Set your desired color here
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(height: 25),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 30.0),
                              child: TextField(
                                controller: _passwordController,
                                onChanged: _validatePassword,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  helperText: _passwordError,
                                  helperStyle: const TextStyle(
                                      color: eggShellColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: !_isPasswordVisible,
                              ),
                            ),
                            if (!_isLogin) ...[
                              const SizedBox(height: 25),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30.0),
                                child: TextField(
                                  controller: _confirmPasswordController,
                                  onChanged: _validateConfirmPassword,
                                  decoration: InputDecoration(
                                    hintText: 'Confirm Password',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    helperText: _confirmPasswordError,
                                    helperStyle: const TextStyle(
                                        color: eggShellColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  obscureText: !_isPasswordVisible,
                                ),
                              ),
                            ],
                            const SizedBox(height: 25),
                            ElevatedButton.icon(
                              onPressed: () async {
                                setState(() {
                                  _isLoading = true;
                                });

                                await authProvider.signInWithGoogle(context);

                                setState(() {
                                  _isLoading = false;
                                });
                              },
                              icon: SvgPicture.asset(
                                'assets/images/google.svg',
                                height: 24,
                                width: 24,
                              ),
                              label: const Text(
                                'Login with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                elevation: 2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_isLoading)
                              const CircularProgressIndicator(
                                color: eggShellColor,
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30.0),
                                child: ElevatedButton(
                                  onPressed: () => _submitAuthForm(context),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 6,
                                    shadowColor: Colors.black,
                                    foregroundColor: eggShellColor,
                                    backgroundColor: tealColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                        color: eggShellColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15.0),
                                    child: Text(
                                      _isLogin ? 'Log In' : 'Sign Up',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin
                                      ? "Don't have an account?"
                                      : "Already have an account?",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: eggShellColor,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLogin = !_isLogin;
                                      // Clear errors when switching modes
                                      _emailError = null;
                                      _passwordError = null;
                                      _confirmPasswordError = null;
                                    });
                                  },
                                  child: Text(
                                    _isLogin ? 'Sign up' : 'Log in',
                                    style: const TextStyle(
                                      color: eggShellColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0,
                  left: MediaQuery.of(context).size.width * 0.03,
                  child: Image.asset(
                    'assets/images/loc.png',
                    height: MediaQuery.of(context).size.height * 0.27,
                    width: MediaQuery.of(context).size.width * 0.27,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
