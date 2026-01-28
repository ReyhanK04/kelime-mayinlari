import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:kelime_mayinlari/pages/game_page.dart';

class NewGamePage extends StatefulWidget {
  const NewGamePage({Key? key}) : super(key: key);

  @override
  State<NewGamePage> createState() => _NewGamePageState();
}

class _NewGamePageState extends State<NewGamePage> {
  final TextEditingController _rakipEmailController = TextEditingController();
  String? currentUserEmail;
  String? gameId;

  @override
  void initState() {
    super.initState();
    currentUserEmail = FirebaseAuth.instance.currentUser?.email;
  }

  Future<void> startGameWithDuration(Duration duration) async {
    if (_rakipEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lütfen rakibin e-posta adresini girin")),
      );
      return;
    }

    DatabaseReference gamesRef = FirebaseDatabase.instance.ref().child("games");
    DatabaseReference newGameRef = gamesRef.push(); // benzersiz ID
    gameId = newGameRef.key;

    await newGameRef.set({
      'player1': currentUserEmail,
      'player2': _rakipEmailController.text.trim(),
      'status': 'waiting',
      'duration': duration.inSeconds,
      'currentTurn': currentUserEmail,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // GamePage'e yönlendir
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GamePage(gameDuration: duration),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yeni Oyun Seçimi"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Rakibin e-posta adresini gir:",
              style: TextStyle(fontSize: 16),
            ),
            TextField(
              controller: _rakipEmailController,
              decoration: const InputDecoration(
                hintText: "örnek: rakip@gmail.com",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => startGameWithDuration(Duration(minutes: 2)),
              child: const Text("2 Dakika (Hızlı Oyun)"),
            ),
            ElevatedButton(
              onPressed: () => startGameWithDuration(Duration(minutes: 5)),
              child: const Text("5 Dakika (Hızlı Oyun)"),
            ),
            ElevatedButton(
              onPressed: () => startGameWithDuration(Duration(hours: 12)),
              child: const Text("12 Saat (Genişletilmiş Oyun)"),
            ),
            ElevatedButton(
              onPressed: () => startGameWithDuration(Duration(hours: 24)),
              child: const Text("24 Saat (Genişletilmiş Oyun)"),
            ),
          ],
        ),
      ),
    );
  }
}
