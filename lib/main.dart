import 'package:echo_app/screens/login_screen.dart';
import 'package:echo_app/screens/register_screen.dart';
import 'package:echo_app/screens/splash_screen.dart';
import 'package:echo_app/services/auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';

void main ()async{
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://gqwpjbqbylsywvuncukj.supabase.co',
    anonKey: 'sb_publishable_emgsgLw2HY3cnZqp09gWgg_CMxqPm1f',
  );

  runApp(const EchoApp());
}

class EchoApp extends StatelessWidget {
  const EchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Enables Material 3 design system
      // This affects colors, buttons, spacing, etc.
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      // First screen user sees
      home: const AuthGate(),
    );
  }
}
