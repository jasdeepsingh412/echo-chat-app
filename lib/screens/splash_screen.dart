import 'package:flutter/material.dart';
import 'chat_list_screen.dart';

// Splash screen shown when app launches
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // Delay for 2 seconds, then navigate to Chat List screen
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatListScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // Column is used to stack logo and text vertically
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chat icon (acts as logo)
            const Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: Colors.blue,
            ),

            const SizedBox(height: 16),

            // App name
            const Text(
              'Echo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Messaging',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
