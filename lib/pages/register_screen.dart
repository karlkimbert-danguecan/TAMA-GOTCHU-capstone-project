import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tamagotchuuu/pages/login_screen.dart';
import 'package:tamagotchuuu/services/auth_service.dart';
import 'package:tamagotchuuu/services/auth_state.dart';
import 'package:tamagotchuuu/widgets/my_button.dart';
import 'package:tamagotchuuu/widgets/my_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final fnameController = TextEditingController();
  final emailController = TextEditingController();
  final pwdController = TextEditingController();
  final confirmPwdController = TextEditingController();

  final auth = AuthService();

  void handleRegister() async {
    if (pwdController.text.trim() != confirmPwdController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("Password did not match!"),
        ),
      );
      return;
    }

    try {
      await auth.register(
        emailController.text.trim(),
        pwdController.text.trim(),
        fnameController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
              "Registration Successful. Please check your email to verify your account."),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthState()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.message ?? "Registration Failed"),
        ),
      );
    }
  }

  @override
  void dispose() {
    fnameController.dispose();
    emailController.dispose();
    pwdController.dispose();
    confirmPwdController.dispose();
    super.dispose();
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
              const SizedBox(height: 50.0),
              Image.asset(
                'assets/images/tamagotchu_logo2.png',
                height: 140,
              ),
              const SizedBox(height: 15.0),
              const Text(
                "JOIN US!",
                style: TextStyle(
                  color: Color(0xFF1880f1),
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Be a part of the Tama-Gotchu Family!",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 35.0),
              // for full name
              MyTextfield(
                controller: fnameController,
                label: "Enter Full Name (FN, MI, LN)",
                prefixIcon: const Icon(Icons.person),
              ),
              // for email input
              const SizedBox(height: 20),
              MyTextfield(
                controller: emailController,
                label: "Enter Email",
                prefixIcon: const Icon(Icons.email),
              ),
              // for password input
              const SizedBox(height: 20),
              MyTextfield(
                controller: pwdController,
                label: "Enter Password",
                prefixIcon: const Icon(Icons.lock),
                obscureText: true,
              ),
              // for confirm password
              const SizedBox(height: 20),
              MyTextfield(
                controller: confirmPwdController,
                label: "Confirm Password",
                prefixIcon: const Icon(Icons.lock),
                obscureText: true,
              ),
              // for button press
              const SizedBox(height: 30),
              Center(
                child: MyButton(
                  textBtn: "Register",
                  onPressed: handleRegister,
                ),
              ),
              const SizedBox(height: 135),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already Signed Up?", style: TextStyle(fontSize: 17)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Login",
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