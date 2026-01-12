import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tamagotchuuu/pages/login_screen.dart';
import 'package:tamagotchuuu/pages/verification_screen.dart';
import 'package:tamagotchuuu/pages/welcome_screen.dart'; // Import the WelcomeScreen
import 'package:tamagotchuuu/services/auth_service.dart';

class AuthState extends StatelessWidget {
  const AuthState({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<User?>(
      stream: auth.currentUserStream,
      builder: (context, snapshot) {
        // Show a loading indicator while the connection state is waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Check if there is a logged-in user
        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (user.emailVerified) {
            // First show the welcome screen, then navigate to the home page
            return const WelcomeScreen();
          } else {
            // If the user is logged in but their email is not verified,
            // show the email verification screen
            return const EmailVerificationScreen();
          }
        }
        // If there is no user data, show the login screen
        else {
          return const LoginScreen();
        }
      },
    );
  }
}
