import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Realtime Database

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('5/registered_users');  // Database reference

  // This explicitly tells Dart that the stream will emit a User object or null.
  Stream<User?> get currentUserStream => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // registration
  Future<UserCredential> register(String email, String pwd, String fname) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: pwd);
    
    final user = result.user;
    if (user != null) {
      await user.sendEmailVerification();
      await _databaseRef.child(user.uid).set({
        'user_id': user.uid,
        'email': email,
        'fname': fname, // Storing the first name
        'reg_date': DateTime.now().toIso8601String(),
      });
    }
    return result;
  }


  //login
  Future<UserCredential> login(String email, String pwd) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email, 
      password: pwd);
    return result;
  }
  
  //logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  //reset password
  Future<void> resetPwd(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}