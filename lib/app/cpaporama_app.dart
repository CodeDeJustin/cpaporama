import 'package:flutter/material.dart';
import 'package:cpaporama/features/home/home_screen.dart';

class CpaporamaApp extends StatelessWidget {
  const CpaporamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPAPorama',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3576E2)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
