import 'package:flutter/material.dart';

import 'connect_screen.dart';
import 'pad_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KeyDeckMobileApp(controller: PadController()));
}

class KeyDeckMobileApp extends StatelessWidget {
  final PadController controller;
  const KeyDeckMobileApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeyDeck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3F51B5),
        useMaterial3: true,
      ),
      home: ConnectScreen(controller: controller),
    );
  }
}
