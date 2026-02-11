import 'package:echo_app/screens/chat_list_screen.dart';
import 'package:echo_app/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in → go to chat list
        if (snapshot.hasData) {
          return const ChatListScreen();
        }

        // If not logged in → show login
        return const LoginScreen();
      },
    );
  }
}
