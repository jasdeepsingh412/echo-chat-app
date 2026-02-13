import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat_list_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final usernameController = TextEditingController();
  bool isLoading = false;

  // --- Logic remains completely untouched ---

  Future<void> checkAndSaveUsername() async {
    final username = usernameController.text.trim().toLowerCase();
    if (username.isEmpty) {
      showErrorDialog("Username cannot be empty.");
      return;
    }

    setState(() => isLoading = true);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('usernameLowercase', isEqualTo: username)
        .get();

    if (query.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
        'uid': currentUid,
        'username': username,
        'usernameLowercase': username,
      });
      if (mounted) _navigateToHome();
      return;
    }

    if (query.docs.first.id == currentUid) {
      await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
        'username': username,
        'usernameLowercase': username,
      });
      if (mounted) _navigateToHome();
      return;
    }

    showErrorDialog("Username already taken.");
    setState(() => isLoading = false);
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChatListScreen()),
    );
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Identity Conflict", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TRY AGAIN", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- UI REDESIGN ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Cohesive Mesh Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF6366F1), // Indigo
                  Color(0xFFA855F7), // Purple
                  Color(0xFFEC4899), // Pink
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Minimal Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "Identity Setup",
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // 2. Playful Identity Icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Icon(
                            Icons.alternate_email_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),

                        const SizedBox(height: 40),

                        Text(
                          "Claim your\nhandle",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          "This is how the AI and your peers will\nrecognize your presence.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 50),

                        // 3. Glassmorphic Input Area
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: TextField(
                                  controller: usernameController,
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: "username",
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // 4. High-Contrast Action Button
                              GestureDetector(
                                onTap: isLoading ? null : checkAndSaveUsername,
                                child: Container(
                                  width: double.infinity,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      )
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: isLoading
                                      ? const CircularProgressIndicator(color: Color(0xFF6366F1))
                                      : Text(
                                    "Finalize Profile",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}