import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_page.dart';
import 'profile_page.dart';
import 'ai_panic_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int contactIndex = 0;

  final AIPanicService _aiService = AIPanicService();
  bool aiEnabled = false;

  Timer? _countdownTimer;
  int remainingSeconds = 0;
  bool timerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadAISetting();
    _restoreSafetyTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _aiService.stopListening();
    super.dispose();
  }

  Future<void> _loadAISetting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

    aiEnabled = doc.data()?["aiPanicEnabled"] == true;

    if (aiEnabled) {
      _aiService.startListening(onPanicDetected: triggerSOS);
    }
  }

  Future<void> startSafetyTimer(int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
      "safeTimer": {
        "enabled": true,
        "startTime": Timestamp.now(),
        "durationSeconds": seconds,
      }
    });

    remainingSeconds = seconds;
    timerRunning = true;
    _startLocalCountdown();
    setState(() {});
  }

  Future<void> stopSafetyTimer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .update({"safeTimer.enabled": false});

    _countdownTimer?.cancel();
    remainingSeconds = 0;
    timerRunning = false;
    setState(() {});
  }

  Future<void> _restoreSafetyTimer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

    final data = doc.data();
    if (data == null || data["safeTimer"] == null) return;

    final timerData = data["safeTimer"];
    if (timerData["enabled"] != true) return;

    final startTime = timerData["startTime"].toDate();
    final duration = timerData["durationSeconds"];

    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final remaining = duration - elapsed;

    if (remaining <= 0) {
      triggerSOS();
    } else {
      remainingSeconds = remaining;
      timerRunning = true;
      _startLocalCountdown();
      setState(() {});
    }
  }

  void _startLocalCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        timer.cancel();
        triggerSOS();
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  Future<Position> _getLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> triggerSOS() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      final contacts = doc["emergencyContacts"];
      final contact =
          contactIndex == 0 ? contacts["primary"] : contacts["secondary"];

      final pos = await _getLocation();

      final message =
          "🚨 EMERGENCY ALERT 🚨\nLocation:\nhttps://maps.google.com/?q=${pos.latitude},${pos.longitude}";

      await FirebaseFirestore.instance.collection("emergencies").add({
        "userId": user.uid,
        "timestamp": Timestamp.now(),
      });

      await launchUrl(Uri.parse(
          "sms:${contact["phone"]}?body=${Uri.encodeComponent(message)}"));
      await launchUrl(Uri.parse("tel:${contact["phone"]}"));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to trigger SOS")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
  title: const Text("Emergency"),
  automaticallyImplyLeading: false,

  actions: [
    Row(
      children: [
        IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
        ),
      ],
    ),
  ],
),

      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (timerRunning)
              Text(
                "Remaining Time: ${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: triggerSOS,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "SOS",
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (!timerRunning)
              ElevatedButton.icon(
                onPressed: () => startSafetyTimer(600),
                icon: const Icon(Icons.timer),
                label: const Text("Start 10-Minute Safety Timer"),
              )
            else
              ElevatedButton.icon(
                onPressed: stopSafetyTimer,
                icon: const Icon(Icons.verified),
                label: const Text("I’m Safe (Stop Timer)"),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}
