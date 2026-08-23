import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'waiting_screen.dart';

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  _RouteSelectionScreenState createState() =>
      _RouteSelectionScreenState();
}

class _RouteSelectionScreenState
    extends State<RouteSelectionScreen> {
  final FlutterTts tts = FlutterTts();
  String selectedRoute = '';
  final List<String> routes = ['402', '510', '213', '887'];

  @override
  void initState() {
    super.initState();
    _setupTTS();
    // Delay so the screen renders before TTS speaks
    Future.delayed(const Duration(milliseconds: 600), () {
      tts.speak(
        'Route selection screen. '
        'Tap a bus number to select your route. '
        'Then tap the Confirm button at the bottom.');
    });
  }

  Future<void> _setupTTS() async {
    await tts.setLanguage('en-IN');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
  }

  void _selectRoute(String route) async {
    setState(() => selectedRoute = route);
    await tts.stop();
    await tts.speak('Bus $route selected. Tap Confirm to proceed.');
  }

  void _confirm() async {
    if (selectedRoute.isEmpty) {
      await tts.speak('Please select a bus route first.');
      return;
    }
    await tts.speak(
        'Confirmed. Searching for bus $selectedRoute. '
        'Please wait at the stop.');
    // Let TTS finish before navigating
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingScreen(route: selectedRoute),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Select Your Bus',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap a route to select it',
                style: TextStyle(fontSize: 16, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Route buttons list
              Expanded(
                child: ListView.separated(
                  itemCount: routes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    final isSelected = selectedRoute == route;
                    return Semantics(
                      label:
                          'Bus $route${isSelected ? ", currently selected" : ""}',
                      button: true,
                      child: GestureDetector(
                        onTap: () => _selectRoute(route),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 90,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFD600)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFD600)
                                  : Colors.grey[800]!,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_bus,
                                color: isSelected
                                    ? Colors.black
                                    : Colors.white54,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Bus $route',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 16),
                                const Icon(Icons.check_circle,
                                    color: Colors.black, size: 28),
                              ]
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Confirm button
              Semantics(
                label: selectedRoute.isEmpty
                    ? 'Confirm button, disabled, please select a route first'
                    : 'Confirm bus $selectedRoute',
                button: true,
                child: GestureDetector(
                  onTap: _confirm,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: selectedRoute.isEmpty
                          ? Colors.grey[900]
                          : Colors.green[700],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        selectedRoute.isEmpty
                            ? 'Select a Route First'
                            : 'CONFIRM  BUS $selectedRoute',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: selectedRoute.isEmpty
                              ? Colors.white38
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}