import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(
    home: SimulatorScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});
  _SimulatorScreenState createState() =>
      _SimulatorScreenState();
}

class _SimulatorScreenState
    extends State<SimulatorScreen> {
  final db = FirebaseDatabase.instance.ref('bus_402');

  bool isRunning = false;
  int currentStep = -1;
  String statusLabel = 'Ready to simulate';
  Timer? realGpsTimer;

  // Fixed waypoints for closed room demo
  // Starting 1.6km away, moving toward stop at 28.6139
  // Each step runs every 5 seconds
  final List<Map<String, dynamic>> waypoints = [
    {
      'lat': 28.6280,
      'lng': 77.2090,
      'label': '1.6km away',
      'note': 'ESP32 idle, no alert yet'
    },
    {
      'lat': 28.6220,
      'lng': 77.2090,
      'label': '900m away',
      'note': 'App detects bus in range'
    },
    {
      'lat': 28.6175,
      'lng': 77.2090,
      'label': '400m away',
      'note': 'TTS: get ready'
    },
    {
      'lat': 28.6155,
      'lng': 77.2090,
      'label': '180m away',
      'note': 'TTS: move to stop'
    },
    {
      'lat': 28.6145,
      'lng': 77.2090,
      'label': '70m away',
      'note': 'bus_arrived fires, BLE starts'
    },
    {
      'lat': 28.6139,
      'lng': 77.2090,
      'label': 'At stop',
      'note': 'BLE detected, arrived screen'
    },
  ];

  Future<void> _runSimulation() async {
    if (isRunning) return;
    setState(() {
      isRunning = true;
      currentStep = 0;
      statusLabel = 'Simulation running...';
    });

    // Reset all flags before starting
    await db.update({
      'passenger_waiting': false,
      'bus_arrived': false,
      'acknowledged': false,
    });

    for (int i = 0; i < waypoints.length; i++) {
      if (!mounted) break;

      // Push current GPS position to Firebase
      await db.child('location').set({
        'lat': waypoints[i]['lat'],
        'lng': waypoints[i]['lng'],
      });

      setState(() => currentStep = i);

      // Wait 5 seconds before next position
      await Future.delayed(const Duration(seconds: 5));
    }

    setState(() {
      isRunning = false;
      statusLabel = 'Simulation complete';
    });
  }

  Future<void> _startRealGPS() async {
    LocationPermission perm =
        await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) {
      setState(
          () => statusLabel = 'Location permission denied');
      return;
    }

    setState(() {
      isRunning = true;
      statusLabel = 'Using real GPS...';
    });

    // Push real GPS every 3 seconds
    realGpsTimer =
        Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await db.child('location').set({
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
        if (mounted) {
          setState(() => statusLabel =
            '${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}');
        }
      } catch (e) {
        if (mounted) {
          setState(
              () => statusLabel = 'GPS error: $e');
        }
      }
    });
  }

  void _stopRealGPS() {
    realGpsTimer?.cancel();
    setState(() {
      isRunning = false;
      statusLabel = 'GPS stopped';
    });
  }

  Future<void> _resetAll() async {
    realGpsTimer?.cancel();
    await db.update({
      'passenger_waiting': false,
      'bus_arrived': false,
      'acknowledged': false,
      'location': {
        'lat': 28.6280,
        'lng': 77.2090,
      },
    });
    setState(() {
      isRunning = false;
      currentStep = -1;
      statusLabel = 'Reset complete';
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bus Simulator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                statusLabel,
                style: const TextStyle(
                    color: Colors.amber, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Waypoint progress
              ...List.generate(waypoints.length, (i) {
                bool done = i < currentStep;
                bool current = i == currentStep;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle
                            : current
                                ? Icons
                                    .radio_button_checked
                                : Icons.circle_outlined,
                        color: done
                            ? Colors.green
                            : current
                                ? Colors.amber
                                : Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              waypoints[i]['label'],
                              style: TextStyle(
                                color: current
                                    ? Colors.white
                                    : done
                                        ? Colors.white60
                                        : Colors.grey[600],
                                fontSize: 15,
                                fontWeight: current
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              waypoints[i]['note'],
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const Spacer(),

              // Start simulation button
              _SimButton(
                label: isRunning
                    ? 'Running...'
                    : 'START FIXED SIMULATION',
                color: Colors.green[800]!,
                onTap: isRunning ? null : _runSimulation,
                height: 70,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _SimButton(
                      label: 'USE REAL GPS',
                      color: Colors.blue[900]!,
                      onTap: isRunning
                          ? null
                          : _startRealGPS,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SimButton(
                      label: 'STOP GPS',
                      color: Colors.orange[900]!,
                      onTap: _stopRealGPS,
                      height: 60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _SimButton(
                label: 'RESET ALL',
                color: Colors.red[900]!,
                onTap: _resetAll,
                height: 55,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double height;

  const _SimButton({
    required this.label,
    required this.color,
    this.onTap,
    this.height = 60,
  });

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey[900]
              : color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: height > 65 ? 18 : 15,
              fontWeight: FontWeight.bold,
              color: onTap == null
                  ? Colors.white30
                  : Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}