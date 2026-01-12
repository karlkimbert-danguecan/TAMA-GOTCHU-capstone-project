import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tamagotchuuu/services/auth_service.dart';
import 'package:tamagotchuuu/pages/login_screen.dart'; // Import the login screen
import 'package:tamagotchuuu/widgets/my_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final authService = AuthService();
  Timer? timer;
  bool isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    isEmailVerified = authService.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Send the verification email when the screen is first loaded
      sendVerificationEmail();

      // Set up a timer to check for verification every 3 seconds
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = authService.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Verification email sent!"),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.message ?? "Failed to send verification email."),
        ),
      );
    }
  }

  Future<void> checkEmailVerified() async {
    // Reload the user to get the latest verification status
    await authService.currentUser?.reload();
    setState(() {
      isEmailVerified = authService.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();
      // Navigate to the login screen if verification is successful
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread,
                size: 100,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 24),
              const Text(
                'Please Verify Your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'A verification link has been sent to your email address. Please click the link to verify your account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              MyButton(
                textBtn: "Resend Email",
                onPressed: sendVerificationEmail,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Allow the user to return to the login screen
                  authService.logout();
                },
                child: const Text(
                  'Go Back to Login',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
