import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class SafetySetupPage extends StatefulWidget {
  final bool isEditMode;

  const SafetySetupPage({
    super.key,
    this.isEditMode = false,
  });

  @override
  State<SafetySetupPage> createState() => _SafetySetupPageState();
}

class _SafetySetupPageState extends State<SafetySetupPage> {
  final primaryNameController = TextEditingController();
  final primaryPhoneController = TextEditingController();
  final secondaryNameController = TextEditingController();
  final secondaryPhoneController = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _loadExistingContacts();
    }
  }

  Future<void> _loadExistingContacts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null || data["emergencyContacts"] == null) return;

    final contacts = data["emergencyContacts"];

    primaryNameController.text = contacts["primary"]["name"] ?? "";
    primaryPhoneController.text = contacts["primary"]["phone"] ?? "";
    secondaryNameController.text = contacts["secondary"]["name"] ?? "";
    secondaryPhoneController.text = contacts["secondary"]["phone"] ?? "";
  }

  Future<void> saveSafetyDetails() async {
    final pName = primaryNameController.text.trim();
    final pPhone = primaryPhoneController.text.trim();
    final sName = secondaryNameController.text.trim();
    final sPhone = secondaryPhoneController.text.trim();

    if (pName.isEmpty || pPhone.isEmpty || sName.isEmpty || sPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    final phoneRegex = RegExp(r'^[0-9]{10}$');

    if (!phoneRegex.hasMatch(pPhone) || !phoneRegex.hasMatch(sPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number must be exactly 10 digits")),
      );
      return;
    }

    if (pPhone == sPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Emergency contacts must be different")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => loading = true);

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "emergencyContacts": {
          "primary": {"name": pName, "phone": pPhone},
          "secondary": {"name": sName, "phone": sPhone},
        },
        "setupCompleted": true,
        "safetySetupAt": Timestamp.now(),
      }, SetOptions(merge: true));

      if (widget.isEditMode) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save safety details")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Widget contactCard(
    String title,
    IconData icon,
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4A148C)),
              const SizedBox(width: 10),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: "Full Name",
              prefixIcon: const Icon(Icons.person_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Phone Number",
              prefixIcon: const Icon(Icons.phone_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Safety Setup"),
        automaticallyImplyLeading: widget.isEditMode,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              "Emergency Contacts",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Add trusted contacts who will be notified in case of an emergency.",
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 28),

            contactCard(
              "Primary Contact",
              Icons.star_outline,
              primaryNameController,
              primaryPhoneController,
            ),

            contactCard(
              "Secondary Contact",
              Icons.shield_outlined,
              secondaryNameController,
              secondaryPhoneController,
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: loading ? null : saveSafetyDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save & Continue",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
