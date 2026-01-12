import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final String textBtn;
  final void Function()? onPressed;
  const MyButton({super.key, required this.textBtn, required this.onPressed});

  @override
  Widget build(BuildContext context){
    return SizedBox(
              width: 150.0,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Color(0xFFff9500),
            padding: EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed, 
        child: Text(textBtn, 
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 18),
        ),
      ),
    );
  }
}