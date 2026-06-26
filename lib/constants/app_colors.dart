import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xff090712);
  static const card = Color(0xff151322);
  static const border = Color(0xff2B2738);

  static const white = Colors.white;
  static const grey = Color(0xffA8A8B3);

  static const pink = Color(0xffFF4DA6);
  static const purple = Color(0xff7B4DFF);

  static const buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      pink,
      purple,
    ],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xff090712),
      Color(0xff0E091C),
      Color(0xff090712),
    ],
  );
}
