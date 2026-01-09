import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_page.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAISetting();
  }

  @override
  void dispose() {
    _aiService.stopListening();
    super.dispose();
  }
  Future<void> _loadAISetting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    aiEnabled = doc.data()?["aiPanicEnabled"] == true;

    if (aiEnabled) {
      _aiService.startListening(
        onPanicDetected: () {
          triggerSOS();
        },
      );
    }
  }
  Future<Position> _getLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
  Future<void> triggerSOS() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data = userDoc.data() as Map<String, dynamic>?;

      if (data == null || data["emergencyContacts"] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Emergency contacts not found"),
          ),
        );
        return;
      }

      final Map<String, dynamic> contacts =
          Map<String, dynamic>.from(data["emergencyContacts"]);

      final Map<String, dynamic> contact =
          Map<String, dynamic>.from(
            contactIndex == 0 ? contacts["primary"] : contacts["secondary"],
          );

      final position = await _getLocation();

      final message =
          "🚨 EMERGENCY ALERT 🚨\n"
          "I need help immediately.\n"
          "Location: https://maps.google.com/?q=${position.latitude},${position.longitude}";

      
      await FirebaseFirestore.instance.collection("emergencies").add({
        "userId": user.uid,
        "contactUsed": contactIndex == 0 ? "primary" : "secondary",
        "location": {
          "lat": position.latitude,
          "lng": position.longitude,
        },
        "timestamp": Timestamp.now(),
        "triggeredBy": aiEnabled ? "AI_VOICE" : "SOS_BUTTON",
      });

      
      final smsUri = Uri.parse(
        "sms:${contact["phone"]}?body=${Uri.encodeComponent(message)}",
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }

      
      final callUri = Uri.parse("tel:${contact["phone"]}");
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      }

      setState(() {
        contactIndex = (contactIndex + 1) % 2;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "SOS sent to ${contactIndex == 1 ? "Primary" : "Secondary"} contact",
          ),
        ),
      );
    } catch (e) {
      debugPrint("SOS ERROR: $e");
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
      body: Center(
        child: GestureDetector(
          onTap: () => triggerSOS(),
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
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
