import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tamagotchuuu/pages/register_screen.dart';
import 'package:tamagotchuuu/pages/welcome_screen.dart';
import 'package:tamagotchuuu/services/auth_service.dart';
import 'package:tamagotchuuu/widgets/my_button.dart';
import 'package:tamagotchuuu/widgets/my_textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final pwdController = TextEditingController();
  final resetPwdController = TextEditingController();
  final auth = AuthService();

  bool _isLoading = false;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    emailController.dispose();
    pwdController.dispose();
    resetPwdController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void loginHandle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await auth.login(emailController.text.trim(), pwdController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.greenAccent,
          content: Text("Login Successful"),
        ),
      );

      // Navigate to the welcome screen after a successful login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.message ?? "Login Failed"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 100.0),
              Image.asset(
                'assets/images/tamagotchu_logo2.png',
                height: 140,
              ),
              SizedBox(height: 15.0),
              Text(
                "WELCOME!",
                style: TextStyle(
                  color: Color(0xFF1880f1),
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Sign In to continue your Journey",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 30.0),

              //for email input
              SizedBox(height: 20),
              MyTextfield(
                controller: emailController,
                label: "Enter Email",
                prefixIcon: Icon(Icons.email),
              ),
              //for password input
              SizedBox(height: 15),
              MyTextfield(
                controller: pwdController,
                label: "Enter Password",
                prefixIcon: Icon(Icons.lock),
                obscureText: true,
              ),
              //for forgotpassword
              SizedBox(height: 15),
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => Padding(
                        padding: MediaQuery.of(context).viewInsets.add(
                          const EdgeInsets.all(25.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Enter email to reset password",
                              style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(height: 20),
                            MyTextfield(
                              controller: resetPwdController,
                              label: "Enter Email",
                              prefixIcon: Icon(Icons.email),
                            ),
                            SizedBox(height: 20),
                            MyButton(
                              textBtn: "Reset Password",
                              onPressed: () async {
                                try {
                                  await auth.resetPwd(resetPwdController.text.trim());
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.greenAccent,
                                      content: Text(
                                          "Password Reset link has been sent!"),
                                    ),
                                  );
                                } on FirebaseAuthException catch (e) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.yellowAccent,
                                      content: Text(
                                          e.message ?? "Something went wrong!"),
                                    ),
                                  );
                                }
                              },
                            ),
                            SizedBox(height: 50),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15),
              _isLoading
                  ? Center(
                      child: RotationTransition(
                        turns: _animationController,
                        child: Image.asset(
                          'assets/images/tamagotchu_loading2.png',
                          width: 50,
                          height: 50,
                        ),
                      ),
                    )
                  : MyButton(
                      textBtn: "Login",
                      onPressed: () {
                        loginHandle();
                      },
                    ),
              SizedBox(height: 200),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("New Member? ", style: TextStyle(fontSize: 17)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Register now!",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 18,
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
    );
  }
}