import 'package:flutter/material.dart';

class MyTextfield extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget prefixIcon;
  final bool obscureText;
  const MyTextfield({
    super.key, 
    required this.controller, 
    required this.label, 
    required this.prefixIcon,
    this.obscureText = false,
    });

  @override
  Widget build(BuildContext context){
    return TextField(
      obscureText: obscureText,
      controller: controller,
      decoration: InputDecoration(
        label: Text(label),
        prefixIcon: prefixIcon,
        prefixIconColor: Color(0xFFff9500),
        border: OutlineInputBorder(),
      ),
    );
  }
}