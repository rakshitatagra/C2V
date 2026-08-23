import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/route_selection_screen.dart';

void main() async {
  // Must always be first — initializes Flutter engine
  WidgetsFlutterBinding.ensureInitialized();
  
  // Connect to Firebase before the app starts
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const C2VApp());
}

class C2VApp extends StatelessWidget {
  const C2VApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C2V Transit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const RouteSelectionScreen(), // First screen
    );
  }
}