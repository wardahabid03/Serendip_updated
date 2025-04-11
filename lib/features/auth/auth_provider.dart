import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/routes.dart';
import '../../models/user_model.dart';
import '../../services/location_service.dart';
import '../profile.dart/provider/profile_provider.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  UserModel? _userModel;
  String? _errorMessage;

  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;

  // Save login status
  Future<void> _saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  // Check login status
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Sign up
  Future<void> signUp(String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        _saveLoginStatus(true);
        notifyListeners();
        Navigator.pushReplacementNamed(context, AppRoutes.create_profile);
      }
    } catch (e) {
      print('sign up failed');
      print(e);
      _errorMessage = 'Sign up failed: $e';
      notifyListeners();
    }
  }

  // Login
  Future<void> login(String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        _saveLoginStatus(true);
        await Provider.of<ProfileProvider>(context, listen: false).fetchUserProfile();
        bool isComplete = Provider.of<ProfileProvider>(context, listen: false).isProfileComplete;
        String nextRoute = isComplete ? AppRoutes.map : AppRoutes.create_profile;
        Navigator.pushReplacementNamed(context, nextRoute);
      }
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      notifyListeners();
    }
  }

  // Google Sign-In
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        _saveLoginStatus(true);
        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
        await profileProvider.fetchUserProfile();
        bool isComplete = profileProvider.isProfileComplete;

        Future.microtask(() {
          Navigator.pushReplacementNamed(context, isComplete ? AppRoutes.map : AppRoutes.create_profile);
        });
      }
    } catch (e) {
      _errorMessage = 'Google sign-in failed: $e';
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _saveLoginStatus(false);
    notifyListeners();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
