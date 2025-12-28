import 'package:flutter/material.dart';

import '../features/imports/import_screen.dart';

class CpapOramaApp extends StatelessWidget {
  const CpapOramaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPAPorama',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3576E2)),
        useMaterial3: true,
      ),
      home: const ImportScreen(),
    );
  }
}