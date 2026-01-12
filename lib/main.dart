import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tamagotchuuu/firebase_options.dart';
import 'package:tamagotchuuu/services/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // A consistent primary color derived from your recent colors
  static const Color primaryColor = Color(0xff607D8B); 
  static const Color accentColor = Color(0xff8d9b9b); // A slightly lighter accent
  static const Color orangeAccent = Color(0xFFf4b143);

  @override
  Widget build(BuildContext context) {
    // Apply system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      
    ));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Set the default font family for the entire app
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          
          // Base colors
          primary: primaryColor,
          onPrimary: Colors.white,
          secondary: accentColor,
          onSecondary: Colors.white,
          
          // Background and surface for cards, sheets, etc.
          surface: Colors.white,
          onSurface: Color(0xFF222222),
          
          // Error colors
          error: Color(0xFFFF5252),
          onError: Colors.white,
        ),
        // Configure other theme properties if needed
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        // Define a custom accent color for this theme
        buttonTheme: ButtonThemeData(
          colorScheme: const ColorScheme.light(
            secondary: orangeAccent,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: orangeAccent,
          ),
        ),
      ),
      home: const AuthState(),
    );
  }
}