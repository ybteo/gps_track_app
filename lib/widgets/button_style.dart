import 'package:flutter/material.dart';
import 'package:gpsapp/constant/const.dart';
import 'package:gpsapp/constant/textstyle.dart';

class BlueButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const BlueButton({super.key,
  required this.onPressed,
  required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: MaterialStateColor.resolveWith((states) => blue.shade700),
        fixedSize: MaterialStateProperty.all<Size>(const Size.fromHeight(35)),
      ),
      child: Text(
        text, 
        style: heading6Semibold,
      ),
    );
  }
}


class LightBlueButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const LightBlueButton({super.key,
  required this.onPressed,
  required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        foregroundColor: MaterialStateColor.resolveWith((states) => blue.shade700),
        fixedSize: MaterialStateProperty.all<Size>(const Size.fromHeight(25)),
        
      ),
      child: Text(
        text, 
        style: heading6Semibold,
      ),
    );
  }
}