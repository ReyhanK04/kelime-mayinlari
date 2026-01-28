import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'game_page.dart';

class PendingGamesPage extends StatefulWidget {
  const PendingGamesPage({super.key});

  @override
  State<PendingGamesPage> createState() => _PendingGamesPageState();
}

class _PendingGamesPageState extends State<PendingGamesPage> {
  final List<Map<String, dynamic>> pendingGames = [];

  @override
  void initState() {
    super.initState();
    fetchPendingGames();
  }

  Future<void> fetchPendingGames() async {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    final dbRef = FirebaseDatabase.instance.ref('games');

    final snapshot = await dbRef.get();

    final List<Map<String, dynamic>> foundGames = [];

    if (snapshot.exists) {
      final data = snapshot.value as Map;

      data.forEach((gameId, gameData) {
        if (gameData is Map) {
          final player2 = gameData['player2'];
          final status = gameData['status'];

          if (player2 == currentUserEmail && status == 'waiting') {
            foundGames.add({
              'gameId': gameId,
              'player1': gameData['player1'],
              'duration': gameData['duration'],
            });
          }
        }
      });
    }

    setState(() {
      pendingGames.clear();
      pendingGames.addAll(foundGames);
    });
  }

  void joinGame(String gameId, int duration) {
    // Oyuna katıl ve GamePage'e yönlendir
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GamePage(gameId: gameId, gameDuration: Duration(seconds: duration)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bekleyen Oyunlar')),
      body: pendingGames.isEmpty
          ? const Center(child: Text('Bekleyen oyun yok.'))
          : ListView.builder(
              itemCount: pendingGames.length,
              itemBuilder: (context, index) {
                final game = pendingGames[index];
                return ListTile(
                  title: Text('Rakip: ${game['player1']}'),
                  subtitle: Text('Süre: ${game['duration']} saniye'),
                  trailing: ElevatedButton(
                    onPressed: () => joinGame(game['gameId'], game['duration']),
                    child: const Text('Katıl'),
                  ),
                );
              },
            ),
    );
  }
}
