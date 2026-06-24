import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const DatagoApp());
}

class DatagoApp extends StatelessWidget {
  const DatagoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DATAGO Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F003C), // The dark purple from Figma/Web
          primary: const Color(0xFF1F003C),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme,
        ),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}
