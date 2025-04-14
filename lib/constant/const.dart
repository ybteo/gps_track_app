import 'package:flutter/material.dart';

int _greyScale = 0xff212121;

int _blueScale = 0xFF006064;

MaterialColor grey = MaterialColor(
  _greyScale,
  <int, Color>{
    50:  const Color(0xfffafafa),
    100: const Color(0xfffafafa),
    200: const Color(0xffeeeeee),
    300: const Color(0xffe0e0e0),
    400: const Color(0xffbdbdbd),
    500: const Color(0xff9e9e9e),
    600: const Color(0xff757575),
    700: const Color(0xff616161),
    800: const Color(0xff424242),
    900: Color(_greyScale),
  }
);

MaterialColor blue = MaterialColor(
  _blueScale, 
  <int, Color>{
    50: const Color(0xFFE0F7FA),
    100: const Color(0xFFB2EBF2),
    200: const Color(0xFF80DEEA),
    300:const Color(0xFF4DD0E1),
    400: const Color(0xFF26C6DA),
    500: const Color(0xFF00BCD4),
    600: const Color(0xFF00ACC1),
    700: const Color(0xFF0097A7),
    800: const Color(0xFF00838F),
    900: Color(_blueScale),
  }
);

