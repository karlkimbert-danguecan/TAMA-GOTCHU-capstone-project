import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tamagotchuuu/pages/home_page.dart';
import 'package:tamagotchuuu/services/home_page_preloader.dart';

class WelcomeScreen extends StatefulWidget {
  // Removed the 'message' parameter as it is not used
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  // 1. Create an instance of the preloader
  final HomePageDataPreloader _preloader = HomePageDataPreloader();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // The two futures to wait for
    // 2. Reduced the minimum duration for better user experience
    final minDurationFuture = Future.delayed(const Duration(seconds: 3));

    // 3. Call the preloadData method on the instance
    final homePageDataFuture = _preloader.preloadData();

    Future.wait([minDurationFuture, homePageDataFuture]).then((_) {
      if (mounted) {
        // Removed the unnecessary snackbar logic here as the LoginScreen
        // already handles the success message.
        
        // 4. Pass the preloader instance to the HomePage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomePage(preloader: _preloader),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/tamagotchu_brandnameandlogo.png',
                height: 200,
              ),
              SizedBox(height: 150),
              RotationTransition(
                turns: _animationController,
                child: Image.asset(
                  'assets/images/tamagotchu_loading2.png',
                  width: 50,
                  height: 50,
                ),
              ),
              Text(
                "Loading...",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}