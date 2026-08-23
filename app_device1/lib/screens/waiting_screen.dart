import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:math';
import 'dart:async';
import 'arrived_screen.dart';

class WaitingScreen extends StatefulWidget {
  final String route;
  const WaitingScreen({super.key, required this.route});
  @override
  _WaitingScreenState createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  final tts = FlutterTts();
  final db = FirebaseDatabase.instance.ref('bus_402');

  // UI state variables
  String statusText = 'Waiting for Bus...';
  String distanceText = 'Locating bus...';
  Color statusColor = Colors.white;
  bool driverAlerted = false;
  bool driverAcknowledged = false;
  bool bleConfirmed = false;

  // Track which announcements already made
  // so TTS doesn't repeat at every GPS update
  final Set<String> _announced = {};

  // Stream subscriptions
  StreamSubscription? _locationSub;
  StreamSubscription? _ackSub;

  @override
  void initState() {
    super.initState();
    _setupTTS();
    _resetFirebase();
    _listenToLocation();
    _listenToAcknowledgement();
    _startBLEScan();
    tts.speak(
      'Waiting for bus ${widget.route}. '
      'You will hear updates as the bus approaches.'
    );
  }

  Future<void> _setupTTS() async {
    await tts.setLanguage('en-IN');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
  }

  // Reset Firebase state so demo starts clean
  Future<void> _resetFirebase() async {
    await db.update({
      'passenger_waiting': false,
      'bus_arrived': false,
      'acknowledged': false,
    });
  }

  // Watch bus GPS location coming from simulator phone
  void _listenToLocation() async {
    // Request location permission
    LocationPermission permission =
        await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Listen to bus location changes in Firebase
    _locationSub = db.child('location').onValue.listen(
      (event) async {
        if (!mounted || event.snapshot.value == null) return;

        final data = Map<String, dynamic>.from(
            event.snapshot.value as Map);
        double busLat = (data['lat'] as num).toDouble();
        double busLng = (data['lng'] as num).toDouble();

        // Get user's real GPS position
        Position userPos;
        try {
          userPos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          // GPS unavailable in closed room
          // Still show distance based on simulator coords
          // Use a fixed reference point for demo
          userPos = Position(
            latitude: 28.6139,
            longitude: 77.2090,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }

        double dist = _haversine(
          userPos.latitude,
          userPos.longitude,
          busLat,
          busLng,
        );

        if (!mounted) return;
        setState(() =>
            distanceText = '${dist.toInt()} meters');

        // === KEY THRESHOLDS ===

        // 1500m — alert driver for first time
        if (dist < 1500 && !_announced.contains('1500')) {
          _announced.add('1500');
          await db.child('passenger_waiting').set(true);
          setState(() {
            driverAlerted = true;
            statusText = 'Driver has been notified';
          });
          await tts.speak(
            'Bus ${widget.route} is entering your area. '
            'Driver has been notified.'
          );
          Vibration.vibrate(duration: 300);
        }

        // 500m — get ready
        if (dist < 500 && !_announced.contains('500')) {
          _announced.add('500');
          await tts.speak(
            'Bus is 500 meters away. Please get ready to board.'
          );
          Vibration.vibrate(duration: 300);
        }

        // 150m — move to stop edge
        if (dist < 150 && !_announced.contains('150')) {
          _announced.add('150');
          await tts.speak(
            'Bus is very close, about 150 meters. '
            'Please move to the boarding area.'
          );
          Vibration.vibrate(
              pattern: [0, 400, 200, 400]);
        }

        // 80m — write bus_arrived to Firebase
        // This triggers ESP32 fast blink + BLE broadcast
        if (dist < 80 && !_announced.contains('arrived')) {
          _announced.add('arrived');
          await db.child('bus_arrived').set(true);
          setState(() {
            statusText = 'Bus is arriving!';
            statusColor = Colors.amber;
          });
          await tts.speak(
            'Bus is arriving now! Stay at the stop.'
          );
          Vibration.vibrate(
              pattern: [0, 500, 200, 500, 200, 500]);
        }
      },
    );
  }

  // Scan for BLE signal from ESP32
  // ESP32 broadcasts "BUS_402" when bus_arrived is true
  void _startBLEScan() async {
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint('BLE not available on this device');
      return;
    }

    // Start continuous BLE scan
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 60),
    );

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        String deviceName = r.device.name;
        String targetName = 'BUS_${widget.route}';

        if (deviceName == targetName &&
            !_announced.contains('ble')) {
          _announced.add('ble');

          // Stop scanning — found our bus
          await FlutterBluePlus.stopScan();

          setState(() {
            bleConfirmed = true;
            statusText = 'YOUR BUS IS HERE!';
            statusColor = Colors.green;
          });

          await tts.speak(
            'Bus ${widget.route} confirmed via Bluetooth! '
            'Your bus is right here. Board safely.'
          );
          Vibration.vibrate(
              pattern: [0, 600, 200, 600, 200, 600]);

          // Go to arrived screen
          if (mounted) {
            await Future.delayed(
                const Duration(seconds: 2));
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ArrivedScreen(route: widget.route),
              ),
            );
          }
        }
      }
    });
  }

  // Listen for driver pressing physical button on ESP32
  void _listenToAcknowledgement() {
    _ackSub =
        db.child('acknowledged').onValue.listen((event) async {
      if (!mounted || event.snapshot.value == null) return;
      if (event.snapshot.value == true &&
          !driverAcknowledged) {
        setState(() {
          driverAcknowledged = true;
          statusText = 'Driver confirmed your stop!';
          statusColor = Colors.green;
        });
        await tts.speak(
          'The driver has confirmed your stop request. '
          'The bus will stop for you.'
        );
        Vibration.vibrate(duration: 700);
      }
    });
  }

  // Haversine formula
  // Calculates real distance in meters between two GPS points
  double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371000.0;
    double dLat = (lat2 - lat1) * pi / 180.0;
    double dLng = (lng2 - lng1) * pi / 180.0;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _ackSub?.cancel();
    FlutterBluePlus.stopScan();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.directions_bus,
                size: 90,
                color: statusColor,
              ),
              const SizedBox(height: 24),

              Text(
                'Bus ${widget.route}',
                style: const TextStyle(
                    fontSize: 20, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Main status — liveRegion means TalkBack
              // announces changes automatically
              Semantics(
                liveRegion: true,
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Distance box
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Bus Distance',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        distanceText,
                        style: const TextStyle(
                          color: Color(0xFFFFD600),
                          fontSize: 46,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Status indicators
              _StatusRow(
                icon: Icons.notifications_active,
                label: 'Driver alerted',
                active: driverAlerted,
              ),
              const SizedBox(height: 12),
              _StatusRow(
                icon: Icons.touch_app,
                label: 'Driver confirmed stop',
                active: driverAcknowledged,
              ),
              const SizedBox(height: 12),
              _StatusRow(
                icon: Icons.bluetooth,
                label: 'Bus BLE confirmed',
                active: bleConfirmed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: active ? Colors.green : Colors.grey[700],
          size: 22,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: active ? Colors.white : Colors.white38,
          ),
        ),
      ],
    );
  }
}