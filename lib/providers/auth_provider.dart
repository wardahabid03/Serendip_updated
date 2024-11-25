import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // Initialize GoogleSignIn

  UserModel? _userModel;
  String? _errorMessage;

  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;

  // Sign up with Firestore user creation
  Future<void> signUp(String email, String password, String username) async {
    print("Attempting to sign up user: $username with email: $email");
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        print("User signed up successfully: ${firebaseUser.uid}");

        // Create a new user in Firestore with additional fields
        UserModel newUser = UserModel(
          userId: firebaseUser.uid,
          username: username,
          email: email,
          friends: [],  // Empty friends list
          privacySettings: PrivacySettings(
            defaultTripPrivacy: 'public',
            defaultImagePrivacy: 'friends',
          ),
        );

        await _firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
        print("User data saved to Firestore for user: ${firebaseUser.uid}");


        _userModel = newUser;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      print("Sign up failed: ${e.toString()}");
      _errorMessage = 'Sign up failed: ${e.toString()}';
      notifyListeners();
    }
  }

  // Log in and fetch user data
  Future<void> login(String email, String password) async {
    print("Attempting to log in user with email: $email");
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        print("User logged in successfully: ${firebaseUser.uid}");

        // Fetch the user data from Firestore
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (userDoc.exists) {
          print("User data fetched from Firestore for user: ${firebaseUser.uid}");
          _userModel = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, firebaseUser.uid);
          _errorMessage = null;
          notifyListeners();
        } else {
          print("No user data found in Firestore for user: ${firebaseUser.uid}");
        }
      }
    } catch (e) {
      print("Login failed: ${e.toString()}");
      _errorMessage = 'Login failed: ${e.toString()}';
      notifyListeners();
    }
  }

  // Google Sign-In
  Future<void> signInWithGoogle() async {
    print("Attempting to sign in with Google");
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // This token will be used to authenticate the user in Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        print("User signed in with Google successfully: ${firebaseUser.uid}");

        // Check if the user already exists in Firestore
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();

        if (!userDoc.exists) {
          // Create a new user in Firestore if they don't exist
          UserModel newUser = UserModel(
            userId: firebaseUser.uid,
            username: firebaseUser.displayName ?? 'User', // Use display name or fallback to 'User'
            email: firebaseUser.email ?? 'No Email',
            friends: [], // Empty friends list
            privacySettings: PrivacySettings(
              defaultTripPrivacy: 'public',
              defaultImagePrivacy: 'friends',
            ),
          );

          await _firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
          print("New user data saved to Firestore for user: ${firebaseUser.uid}");
        }

        // Fetch the user data
        _userModel = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, firebaseUser.uid);
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      print("Google sign-in failed: ${e.toString()}");
      _errorMessage = 'Google sign-in failed: ${e.toString()}';
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    print("Logging out user");
    await _auth.signOut();
    await _googleSignIn.signOut(); // Sign out from Google as well
    _userModel = null;
    _errorMessage = null;
    notifyListeners();
    print("User logged out successfully");
  }

  Stream<User?> get authStateChanges {
    print("Auth state changed");
    return _auth.authStateChanges();
  }
}
