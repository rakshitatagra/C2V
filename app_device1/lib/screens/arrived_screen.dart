import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'route_selection_screen.dart';

class ArrivedScreen extends StatefulWidget {
  final String route;
  const ArrivedScreen({super.key, required this.route});
  @override
  _ArrivedScreenState createState() => _ArrivedScreenState();
}

class _ArrivedScreenState extends State<ArrivedScreen> {
  final tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _announce();
  }

  Future<void> _announce() async {
    await tts.setLanguage('en-IN');
    await tts.setSpeechRate(0.45);
    Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 1000]);
    await tts.speak(
      'Your bus ${widget.route} has arrived and confirmed your stop. '
      'Please board safely. '
      'Tap anywhere on the screen to start a new journey.'
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RouteSelectionScreen(),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A3D0A),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 140,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Bus ${widget.route}\nHas Arrived',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Board safely',
                    style: TextStyle(
                        fontSize: 24, color: Colors.white70),
                  ),
                  const SizedBox(height: 80),
                  const Text(
                    'Tap anywhere to start a new journey',
                    style: TextStyle(
                        fontSize: 18, color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}