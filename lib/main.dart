import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ZeroWastePantryApp());
}

class ZeroWastePantryApp extends StatelessWidget {
  const ZeroWastePantryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroWaste Pantry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFFA500),
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: 'Poppins',
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA500),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
