import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String username = "Kullanıcı";
  int totalPoints = 0;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String uid = user.uid;

      try {
        // 👤 Firebase Realtime Database'den kullanıcı adını çek
        DatabaseReference userRef =
            FirebaseDatabase.instance.ref().child('users').child(uid);

        DatabaseEvent event = await userRef.once();
        Map userData = event.snapshot.value as Map;

        setState(() {
          username = userData['username'] ?? "Kullanıcı";
        });
      } catch (e) {
        print("Kullanıcı adı alınamadı: $e");
      }
    }

    // 🔄 Toplam puanı yine SharedPreferences’tan al (Firebase’e geçince güncelleriz)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      totalPoints = prefs.getInt('totalPoints') ?? 0;
    });
  }

  void navigateToNewGame() async {
    await Navigator.pushNamed(context, '/newGame');
    loadUserData(); // Yeni oyun sonrası toplam puanı güncelle
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Menü'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Hoşgeldin, $username!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Toplam Puan: $totalPoints",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: navigateToNewGame,
              child: const Text("Yeni Oyun"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Aktif oyunlar sayfası
              },
              child: const Text("Aktif Oyunlar"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Biten oyunlar sayfası
              },
              child: const Text("Biten Oyunlar"),
            ),
            ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(context, '/pendingGames');
  },
  child: const Text("Bekleyen Oyunlar"),
),

          ],
        ),
      ),
    );
  }
}
