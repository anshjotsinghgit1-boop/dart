import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const RizzGuruApp());
}

class RizzGuruApp extends StatelessWidget {
  const RizzGuruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rizz Guru',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0D071F),
        primaryColor: const Color(0xFFFF5B63),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
