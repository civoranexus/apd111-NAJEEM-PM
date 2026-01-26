import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'safety_setup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool aiEnabled = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAISetting();
  }

  Future<void> loadAISetting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    setState(() {
      aiEnabled = doc.data()?["aiPanicEnabled"] == true;
      loading = false;
    });
  }

  Future<void> toggleAI(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => aiEnabled = value);

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .update({
      "aiPanicEnabled": value,
    });
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Enable AI Voice Panic Detection"),
              subtitle: const Text(
                "Automatically trigger SOS when panic words are detected",
              ),
              value: aiEnabled,
              onChanged: toggleAI,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text("Change Emergency Contacts"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SafetySetupPage(isEditMode: true),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
