import 'package:flutter/material.dart';
import 'package:kelime_mayinlari/pages/new_game_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/pending_games_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 🔥 Firebase'e veri gönderme testi
  final dbRef = FirebaseDatabase.instance.ref();
  dbRef.child("deneme").set({"test": "çalışıyor"});

  runApp(MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelime Mayınları',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/newGame': (context) => const NewGamePage(),
        '/pendingGames': (context) => const PendingGamesPage(),
        // '/game': (context) => const GamePage(gameDuration: Duration(minutes: 2)), // ❌ Kaldırıldı
      },
    );
  }
}
