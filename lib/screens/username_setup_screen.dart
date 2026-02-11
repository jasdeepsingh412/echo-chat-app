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


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // THIS is mandatory
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          "Username Setup",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Choose your\nUsername",
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),

            Text(
              "This is how your colleagues and friends will \nfind you on the platform.",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 20),

            //textfield input
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
                border: OutlineInputBorder(),
              ),
            ),


            const SizedBox(height: 10,),


            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(onPressed: isLoading ? null : checkAndSaveUsername,
                  child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                "Continue",
              ),

            )
            ),
          ],
        ),
      ),
    );
  }

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

    // If no document exists → username is free
    if (query.docs.isEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .set({
        'uid': currentUid,
        'username': username,
        'usernameLowercase': username,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );

      return;
    }

    // If document exists BUT it's my own document → allow update
    if (query.docs.first.id == currentUid) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
        'username': username,
        'usernameLowercase': username,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );

      return;
    }

    // Otherwise, it's taken by someone else
    showErrorDialog("Username already taken.");

    setState(() => isLoading = false);
  }


  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "Username Error",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }


}
