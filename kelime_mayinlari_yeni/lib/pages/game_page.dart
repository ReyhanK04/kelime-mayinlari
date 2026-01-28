// Flutter game_page.dart with per-player timer and turn-based logic
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamePage extends StatefulWidget {
  final Duration gameDuration;
  final String? gameId;
  const GamePage({Key? key, required this.gameDuration, this.gameId}) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const int gridSize = 15;
  late List<List<String>> board;
  late List<List<String>> bonusBoard;
  List<String> letters = [];
  List<String> harfHavuzu = [];
  List<String> kazanilanJokerler =
      []; // Sadece kazanılan jokerler burada tutulur

  final Random random = Random();

  List<Point<int>> selectedCells = [];
  String currentWord = "";
  String? selectedLetter;
  Set<Point<int>> lockedCells = {};

  int oyuncuPuani = 0;
  int rakipPuani = 0;
  String kullaniciAdi = "Ben";
  String rakipAdi = "Rakip";
  Set<String> validWords = {};
  String? rakipEmail;


  Timer? countdownTimer;
  Timer? oyuncuTimer;
  late Duration remainingTime;
  Duration oyuncuSuresi = const Duration(seconds: 25);
  Duration kalanOyuncuSuresi = const Duration(seconds: 25);

  bool oyuncuSirasi = true;
  bool ekstraHamleAktif = false;
  bool bolgeYasagiAktif = false;
  bool harfYasagiAktif = false;
  List<String> dondurulenHarfler = [];
  bool tasimaModu = false;
  Point<int>? secilenTasimaNoktasi;

  final Map<String, int> harfPuanlari = {
    'A': 1,
    'B': 3,
    'C': 4,
    'Ç': 4,
    'D': 3,
    'E': 1,
    'F': 7,
    'G': 5,
    'Ğ': 8,
    'H': 5,
    'I': 2,
    'İ': 1,
    'J': 10,
    'K': 1,
    'L': 1,
    'M': 2,
    'N': 1,
    'O': 2,
    'Ö': 7,
    'P': 5,
    'R': 1,
    'S': 2,
    'Ş': 4,
    'T': 1,
    'U': 2,
    'Ü': 3,
    'V': 7,
    'Y': 3,
    'Z': 4,
    'JOKER': 0
  };

  final Map<String, int> harfAdetleri = {
    'A': 12,
    'B': 2,
    'C': 2,
    'Ç': 2,
    'D': 2,
    'E': 8,
    'F': 1,
    'G': 1,
    'Ğ': 1,
    'H': 1,
    'I': 4,
    'İ': 7,
    'J': 1,
    'K': 7,
    'L': 7,
    'M': 4,
    'N': 5,
    'O': 3,
    'Ö': 1,
    'P': 1,
    'R': 6,
    'S': 3,
    'Ş': 2,
    'T': 5,
    'U': 3,
    'Ü': 2,
    'V': 1,
    'Y': 2,
    'Z': 2,
    'JOKER': 2
  };

  @override
void initState() {
  super.initState();
  _initializeBoard();
  _loadValidWords();
  startTimer();
  startOyuncuTimer();

  // Tuzakları terminale yazdır
  for (int i = 0; i < gridSize; i++) {
    for (int j = 0; j < gridSize; j++) {
      if (trapBoard[i][j].isNotEmpty) {
        print("💣 Tuzak (${trapBoard[i][j]}) -> Satır: $i, Sütun: $j");
      }
      if (rewardBoard[i][j].isNotEmpty) {
        print("🎁 Joker (${rewardBoard[i][j]}) -> Satır: $i, Sütun: $j");
      }
    }
  }

  if (widget.gameId != null) {
      _listenToGameData(widget.gameId!); // ✅ Veritabanından oyun verisini dinle
      _listenToMoves(widget.gameId!);
    _loadOpponentEmail(widget.gameId!);
    }

}




void _listenToMoves(String gameId) {
  final gameRef = FirebaseDatabase.instance.ref('deneme/games/$gameId');

  gameRef.onValue.listen((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;

    if (data == null) return;

    final turn = data['currentTurn'] as String?;
    final moves = data['moves'] as List<dynamic>?;

    if (turn != null && mounted) {
      setState(() {
        oyuncuSirasi = (turn == FirebaseAuth.instance.currentUser?.email);
      });
    }

    if (moves != null && mounted) {
      // En son hamleyi oku (henüz yapılmadıysa zaten etkisi olmaz)
      final lastMove = moves.last as Map<dynamic, dynamic>;
      final word = lastMove['word'] ?? '';
      final player = lastMove['player'] ?? '';
      final time = lastMove['time'] ?? '';

      print("🔁 $player kelimesi: $word  ($time)");
      // İsteğe bağlı olarak tahtada gösterilebilir
    }
  });
}


void _listenToGameData(String gameId) {
    DatabaseReference gameRef = FirebaseDatabase.instance.ref().child('deneme/games/$gameId');
    gameRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          // Örnek olarak sadece currentTurn okunuyor
          final turn = data['currentTurn'] as String?;
final currentUser = FirebaseAuth.instance.currentUser;
final myEmail = currentUser?.email;

if (turn != null && myEmail != null) {
  setState(() {
    oyuncuSirasi = (turn == myEmail);

    print("Gelen currentTurn: $turn");
    print("Benim email: $myEmail");
    print("Sıra bende mi? $oyuncuSirasi");
  });
}

          // Burada başka verileri de setState ile içeri alabiliriz
        });
      }
    });
  }


  bool komsulukKontrolEt(List<Point<int>> yeniHarfler) {
    for (var cell in yeniHarfler) {
      int x = cell.x;
      int y = cell.y;

      final komsular = [
        Point(x - 1, y),
        Point(x + 1, y),
        Point(x, y - 1),
        Point(x, y + 1),
        Point(x - 1, y - 1),
        Point(x - 1, y + 1),
        Point(x + 1, y - 1),
        Point(x + 1, y + 1),
      ];

      for (var komsu in komsular) {
        if (komsu.x >= 0 &&
            komsu.x < gridSize &&
            komsu.y >= 0 &&
            komsu.y < gridSize &&
            lockedCells.contains(komsu)) {
          return true; // en az bir komşuda kilitli harf var
        }
      }
    }
    return false;
  }

  void startOyuncuTimer() {
    kalanOyuncuSuresi = oyuncuSuresi;
    oyuncuTimer?.cancel();
    oyuncuTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (kalanOyuncuSuresi.inSeconds > 0) {
        setState(() {
          kalanOyuncuSuresi -= const Duration(seconds: 1);
        });
      } else {
        timer.cancel();
        _clearUnsubmittedLetters();

        if (!oyuncuSirasi) {
          _rakipOyna();
        }

        setState(() {
          if (oyuncuSirasi) {
            // Oyuncunun süresi bitti, sıra rakibe geçecek
            oyuncuSirasi = false;
          } else {
            // Rakibin süresi bitti, hamlesini yap
            _rakipOyna();
            oyuncuSirasi = true;

            // Joker etkilerini sıfırla
            harfYasagiAktif = false;
            dondurulenHarfler.clear();
            bolgeYasagiAktif = false;
          }

          ekstraHamleAktif = false; // Her durumda sıfırlanır
        });

        startOyuncuTimer();
      }
    });
  }

  void _rakipOyna() {
    List<String> olasiKelimeler =
        validWords.where((kelime) => kelime.length <= 5).toList();
    if (olasiKelimeler.isNotEmpty) {
      String kelime = olasiKelimeler[random.nextInt(olasiKelimeler.length)];
      int puan = kelime.length * 2; // basit puan hesabı
      setState(() {
        rakipPuani += puan;
      });
    }
  }

  void _clearUnsubmittedLetters() {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        Point<int> point = Point(row, col);
        if (!lockedCells.contains(point) && board[row][col].isNotEmpty) {
          letters.add(board[row][col]);
          board[row][col] = '';
        }
      }
    }
    selectedCells.clear();
    currentWord = "";
    selectedLetter = null;
  }

  void startTimer() {
    remainingTime = widget.gameDuration;
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime.inSeconds > 0) {
        setState(() {
          remainingTime -= const Duration(seconds: 1);
        });
      } else {
        timer.cancel();
        _showGameOverDialog();
      }
    });
  }

  Future<void> _showGameOverDialog() async {
    countdownTimer?.cancel();
    oyuncuTimer?.cancel();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    int totalGames = prefs.getInt('totalGames') ?? 0;
    int totalPoints = prefs.getInt('totalPoints') ?? 0;

    totalGames += 1;
    await prefs.setInt('totalGames', totalGames);

    String mesaj = "";
    String puanBilgi = "";

    if (oyuncuPuani > rakipPuani) {
      mesaj = "KAZANDINIZ 🎉";
      puanBilgi = "Puanınız: $oyuncuPuani";
      totalPoints += oyuncuPuani;
      await prefs.setInt('totalPoints', totalPoints);
    } else if (rakipPuani > oyuncuPuani) {
      mesaj = "Karşı Oyuncu Kazandı";
      puanBilgi = "Rakip Puanı: $rakipPuani";
      // Puan eklenmez
    } else {
      mesaj = "Berabere";
      puanBilgi = "Puanlar: $oyuncuPuani - $rakipPuani";
      // Puan eklenmez
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Süre Doldu!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mesaj, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(puanBilgi),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  late List<List<String>> trapBoard;
  late List<List<String>> rewardBoard;

  void _initializeBoard() {
    board = List.generate(gridSize, (_) => List.generate(gridSize, (_) => ''));
    bonusBoard =
        List.generate(gridSize, (_) => List.generate(gridSize, (_) => ''));
    trapBoard =
        List.generate(gridSize, (_) => List.generate(gridSize, (_) => ''));
    rewardBoard =
        List.generate(gridSize, (_) => List.generate(gridSize, (_) => ''));
    _placeBonuses();
    _placeTraps();
    _placeRewards();
  }

  void kullanJoker(String tur) {
    if (!oyuncuSirasi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sıra sende değil!")),
      );
      return;
    }

    switch (tur) {
      case 'HARFYASAK':
        if (letters.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Yeterli harf yok!")),
          );
          return;
        }
        harfYasagiAktif = true;
        dondurulenHarfler = letters.sublist(0, 2); // İlk 2 harfi dondur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Rakibin harflerinden ${dondurulenHarfler.join(", ")} bu tur donduruldu!")),
        );
        break;

      case 'BOLGE':
        bolgeYasagiAktif = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Rakip artık sadece matrisin yarısına harf koyabilir!")),
        );
        break;

      case 'EKSTRA':
        ekstraHamleAktif = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ekstra hamle hakkı kazandınız!")),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bilinmeyen joker türü!")),
        );
    }

    setState(() {});
  }

  void _placeRewards() {
    Map<String, int> rewards = {
      'BOLGE': 2, // Bölge yasağı
      'HARFYASAK': 3, // Harf yasağı
      'EKSTRA': 2, // Ekstra hamle
    };
    rewards.forEach((reward, count) {
      int added = 0;
      while (added < count) {
        int row = random.nextInt(gridSize);
        int col = random.nextInt(gridSize);
        if (rewardBoard[row][col] == '' && trapBoard[row][col] == '') {
          rewardBoard[row][col] = reward;
          added++;
        }
      }
    });
  }

  Widget _buildRewardMarker(String reward) {
    IconData icon;
    Color color;
    switch (reward) {
      case 'BOLGE':
        icon = Icons.block;
        color = Colors.orange;
        break;
      case 'HARFYASAK':
        icon = Icons.cancel;
        color = Colors.purple;
        break;
      case 'EKSTRA':
        icon = Icons.star;
        color = Colors.amber;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Positioned(
      bottom: 2,
      right: 2,
      child: Icon(icon, size: 10, color: color),
    );
  }

  void _placeTraps() {
    Map<String, int> traps = {
      'IPTAL': 2,
      'TRANSFER': 4,
      'BOL': 5,
      'HARFKAYBI': 3,
      'BONUSIPTAL': 2,
    };
    traps.forEach((trap, count) {
      int added = 0;
      while (added < count) {
        int row = random.nextInt(gridSize);
        int col = random.nextInt(gridSize);
        if (trapBoard[row][col] == '') {
          trapBoard[row][col] = trap;
          added++;
        }
      }
    });
  }

  Widget _buildTrapMarker(String trap) {
    Color color;
    switch (trap) {
      case 'BONUSIPTAL':
        color = Colors.red;
        break;
      case 'TRANSFER':
        color = Colors.black;
        break;
      case 'BOL':
        color = Colors.yellow;
        break;
      case 'HARFKAYBI':
        color = Colors.blue;
        break;
      case 'IPTAL':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Positioned(
      top: 2,
      right: 2,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  void _placeBonuses() {
    List<String> bonuses = ['H2', 'H3', 'K2', 'K3'];
    int bonusCount = 20;
    for (int i = 0; i < bonusCount; i++) {
      int row = random.nextInt(gridSize);
      int col = random.nextInt(gridSize);
      if (bonusBoard[row][col] == '') {
        bonusBoard[row][col] = bonuses[random.nextInt(bonuses.length)];
      }
    }
  }

  Future<void> _loadValidWords() async {
    final String wordData =
        await rootBundle.loadString('assets/turkce_kelime_listesi.txt');
    validWords = wordData
        .split('\n')
        .map((word) => _toTurkishUpper(word.trim()))
        .toSet();
    _initializeHarfHavuzu();
    _generateInitialLetters();
  }

  void _initializeHarfHavuzu() {
    harfHavuzu.clear();
    harfAdetleri.forEach((harf, adet) {
      for (int i = 0; i < adet; i++) {
        harfHavuzu.add(harf);
      }
    });
  }

  void _generateInitialLetters() {
    letters.clear();
    for (int i = 0; i < 7; i++) {
      _addLetterToLetters();
    }
    setState(() {});
  }

  void _addLetterToLetters() {
    if (harfHavuzu.isNotEmpty) {
      String harf = harfHavuzu[random.nextInt(harfHavuzu.length)];
      letters.add(harf);
      harfHavuzu.remove(harf);
    }
  }

  void _selectCell(int row, int col) {
    setState(() {
      if (board[row][col].isNotEmpty &&
          !selectedCells.contains(Point(row, col)) &&
          !lockedCells.contains(Point(row, col))) {
        selectedCells.add(Point(row, col));
        currentWord += board[row][col];
      }
    });
  }

  void _placeSelectedLetter(int row, int col) {
    if (selectedLetter != null &&
        board[row][col].isEmpty &&
        !lockedCells.contains(Point(row, col))) {
      setState(() {
        board[row][col] = selectedLetter!;
        letters.remove(selectedLetter);
        selectedLetter = null;
      });
    }
  }
bool tekYondeMi(List<Point<int>> secimler) {
  if (secimler.length <= 1) return true;

  secimler.sort((a, b) {
    int cmpX = a.x.compareTo(b.x);
    return cmpX != 0 ? cmpX : a.y.compareTo(b.y);
  });

  bool ayniSatir = secimler.every((p) => p.x == secimler.first.x);
  bool ayniSutun = secimler.every((p) => p.y == secimler.first.y);
  bool capraz = true;

  for (int i = 1; i < secimler.length; i++) {
    int dx = (secimler[i].x - secimler[i - 1].x).abs();
    int dy = (secimler[i].y - secimler[i - 1].y).abs();
    if (dx != 1 || dy != 1) {
      capraz = false;
      break;
    }
  }

  return ayniSatir || ayniSutun || capraz;
}
List<String> caprazKelimeleriBul() {
  Set<String> bulunan = {};
  for (var cell in selectedCells) {
    // Yatay tara
    int row = cell.x;
    int startCol = cell.y;
    while (startCol > 0 && board[row][startCol - 1].isNotEmpty) startCol--;

    String kelime = '';
    int col = startCol;
    while (col < gridSize && board[row][col].isNotEmpty) {
      kelime += board[row][col];
      col++;
    }
    if (kelime.length > 1) bulunan.add(_toTurkishUpper(kelime));

    // Dikey tara
    int colY = cell.y;
    int startRow = cell.x;
    while (startRow > 0 && board[startRow - 1][colY].isNotEmpty) startRow--;

    kelime = '';
    int rowY = startRow;
    while (rowY < gridSize && board[rowY][colY].isNotEmpty) {
      kelime += board[rowY][colY];
      rowY++;
    }
    if (kelime.length > 1) bulunan.add(_toTurkishUpper(kelime));
  }

  return bulunan.toList();
}

Future<void> _loadOpponentEmail(String gameId) async {
  final ref = FirebaseDatabase.instance.ref('deneme/games/$gameId');
  final snapshot = await ref.get();

  final data = snapshot.value as Map?;
  final currentEmail = FirebaseAuth.instance.currentUser?.email;

  if (data != null && currentEmail != null) {
    final player1 = data['player1'] as String?;
    final player2 = data['player2'] as String?;

    if (player1 != null && player2 != null) {
      setState(() {
        rakipEmail = (player1 == currentEmail) ? player2 : player1;
      });
    }
  }
}
  Future<void> _submitWord() async {
    if (!oyuncuSirasi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sıra sende değil!")),
      );
      return;
    }
    if (!tekYondeMi(selectedCells)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Kelime tek bir yönde (yatay, dikey, çapraz) olmalı.")),
  );
  return;
}
List<String> caprazKelimeler = caprazKelimeleriBul();
for (String k in caprazKelimeler) {
  if (!validWords.contains(k)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Oluşan çapraz kelime geçersiz: $k")),
    );
    return;
  }

  
}


if (lockedCells.isNotEmpty && !komsulukKontrolEt(selectedCells)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Yeni kelime en az bir harfe temas etmeli.")),
  );
  return;
}

    String kelime = _toTurkishUpper(currentWord);
    if (kelime.isNotEmpty && validWords.contains(kelime)) {
      int puan = kelimePuaniHesapla(kelime);
      oyuncuPuani += puan;
      for (var cell in selectedCells) {
        String trap = trapBoard[cell.x][cell.y];
        if (trap.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("⚠ Mayına bastın: $trap")),
            );
          });
        }
      }

      // 🎁 Sadece kullanılan reward'lardan kazan
      for (var cell in selectedCells) {
        String reward = rewardBoard[cell.x][cell.y];
        if (reward.isNotEmpty && !kazanilanJokerler.contains(reward)) {
          kazanilanJokerler.add(reward);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🎁 $reward jokerini kazandınız!")),
          );
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Tebrikler! '$currentWord' doğru. +$puan puan kazandın!")),
        );
      });

      lockedCells.addAll(selectedCells);

      if (widget.gameId != null) {
  final moveRef = FirebaseDatabase.instance
      .ref('deneme/games/${widget.gameId}/moves')
      .push();

  await moveRef.set({
    'player': FirebaseAuth.instance.currentUser?.email,
    'word': kelime,
    'time': DateTime.now().toIso8601String(),
  });

  // Sırayı değiştir
  await FirebaseDatabase.instance
      .ref('deneme/games/${widget.gameId}/currentTurn')
      .set(rakipEmail); // Diğer oyuncunun e-postasını yaz
}


      int harfSayisi = selectedCells.length;
      for (int i = 0; i < harfSayisi; i++) {
        if (harfHavuzu.isNotEmpty && letters.length < 7) {
          String harf = harfHavuzu[random.nextInt(harfHavuzu.length)];
          letters.add(harf);
          harfHavuzu.remove(harf);
        }
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Üzgünüm, '${currentWord}' yanlış.")),
        );
      });

      for (var cell in selectedCells) {
        String usedLetter = board[cell.x][cell.y];
        board[cell.x][cell.y] = '';
        if (harfHavuzu.contains(usedLetter)) {
          letters.add(usedLetter);
          harfHavuzu.remove(usedLetter);
        } else if (harfHavuzu.isNotEmpty) {
          String newLetter = harfHavuzu[random.nextInt(harfHavuzu.length)];
          letters.add(newLetter);
          harfHavuzu.remove(newLetter);
        }
      }
    }

    setState(() {
      selectedCells.clear();
      currentWord = "";
    });
  }

  int kelimePuaniHesapla(String kelime) {
    int toplamPuan = 0;
    int kelimeCarpani = 1;
    bool bonusIptal = false;

    // Önce bonusları uygula (eğer ekstra hamle engeli yoksa)
    for (var cell in selectedCells) {
      String harf = board[cell.x][cell.y].toUpperCase();
      int harfPuani = harfPuanlari[harf] ?? 0;
      String bonus = bonusBoard[cell.x][cell.y];

      if (!bonusIptal) {
        if (bonus == 'H2')
          harfPuani *= 2;
        else if (bonus == 'H3')
          harfPuani *= 3;
        else if (bonus == 'K2')
          kelimeCarpani *= 2;
        else if (bonus == 'K3') kelimeCarpani *= 3;
      }

      toplamPuan += harfPuani;
    }

    int puanSonucu = toplamPuan * kelimeCarpani;

    // Tüm mayın etkilerini uygula
    for (var cell in selectedCells) {
      String trap = trapBoard[cell.x][cell.y];

      switch (trap) {
        case 'IPTAL':
          return 0; // Puan yok, oyuncu da almıyor
        case 'TRANSFER':
          rakipPuani += puanSonucu; // Tüm puan rakibe
          return 0;
        case 'BOL':
          return (puanSonucu * 0.3).toInt(); // %30'unu alır
        case 'HARFKAYBI':
          letters.clear(); // Tüm harfleri kaybeder
          for (int i = 0; i < 7; i++) {
            _addLetterToLetters(); // Yeniden 7 harf verilir
          }
          break;
        case 'BONUSIPTAL':
          bonusIptal = true;
          // bonuslar yukarıda zaten uygulanmış, bu yüzden sadece harf puanlarını döndür
          int sadeToplam = 0;
          for (var cell in selectedCells) {
            String harf = board[cell.x][cell.y].toUpperCase();
            sadeToplam += harfPuanlari[harf] ?? 0;
          }
          return sadeToplam;
      }
    }

    return puanSonucu;
  }

  String _toTurkishUpper(String input) {
    final Map<String, String> replacements = {
      'i': 'İ',
      'ş': 'Ş',
      'ğ': 'Ğ',
      'ü': 'Ü',
      'ö': 'Ö',
      'ç': 'Ç',
      'ı': 'I'
    };
    return input
        .split('')
        .map((char) => replacements[char] ?? char.toUpperCase())
        .join();
  }

  Color _getBonusColor(
      String bonus, bool isLocked, bool isSelected, int row, int col) {
    final point = Point(row, col);
    if (isLocked) return Colors.grey.shade300;
    if (selectedCells.contains(point)) {
      if (validWords.contains(_toTurkishUpper(currentWord))) {
        return Colors.green.shade200;
      } else {
        return Colors.red.shade200;
      }
    }
    switch (bonus) {
      case 'H2':
        return Colors.blue.shade100;
      case 'H3':
        return Colors.purple.shade100;
      case 'K2':
        return Colors.green.shade100;
      case 'K3':
        return Colors.brown.shade200;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(remainingTime.inHours);
    final minutes = twoDigits(remainingTime.inMinutes.remainder(60));
    final seconds = twoDigits(remainingTime.inSeconds.remainder(60));
    return Scaffold(
      appBar: AppBar(title: const Text('Kelime Mayınları Oyunu')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$kullaniciAdi: $oyuncuPuani',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Kalan Harf: ${harfHavuzu.length + letters.length}',
                          style: const TextStyle(fontSize: 16)),
                      Text('$rakipAdi: $rakipPuani',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Sıra: ${oyuncuSirasi ? kullaniciAdi : rakipAdi}',
                      style: const TextStyle(fontSize: 16)),
                  Text('Süre: ${kalanOyuncuSuresi.inSeconds} saniye',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Kalan Süre: $hours:$minutes:$seconds',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: gridSize * gridSize,
                itemBuilder: (context, index) {
                  int row = index ~/ gridSize;
                  int col = index % gridSize;
                  bool isSelected = selectedCells.contains(Point(row, col));
                  bool isLocked = lockedCells.contains(Point(row, col));
                  return GestureDetector(
                    onTap: () {
                      if (!tasimaModu && (!oyuncuSirasi || isLocked)) return;

                      final current = Point(row, col);

                      if (tasimaModu) {
                        final current = Point(row, col);

                        if (secilenTasimaNoktasi == null) {
                          if (lockedCells.contains(current) &&
                              board[row][col].isNotEmpty) {
                            setState(() {
                              secilenTasimaNoktasi = current;
                            });
                          }
                        } else {
                          final dx = (secilenTasimaNoktasi!.x - row).abs();
                          final dy = (secilenTasimaNoktasi!.y - col).abs();

                          if ((dx + dy == 1) && board[row][col].isEmpty) {
                            setState(() {
                              board[row][col] = board[secilenTasimaNoktasi!.x]
                                  [secilenTasimaNoktasi!.y];
                              board[secilenTasimaNoktasi!.x]
                                  [secilenTasimaNoktasi!.y] = '';
                              lockedCells.remove(secilenTasimaNoktasi);
                              lockedCells.add(current);
                              tasimaModu = false;
                              secilenTasimaNoktasi = null;
                            });
                          }
                        }
                        return;
                      }

                      if (bolgeYasagiAktif &&
                          !oyuncuSirasi &&
                          col < gridSize ~/ 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Bu bölgeye harf yerleştiremezsin (Bölge Yasağı aktif).")),
                        );
                        return;
                      }
                      if (selectedLetter != null && board[row][col].isEmpty) {
                        _placeSelectedLetter(row, col);
                      } else if (board[row][col].isNotEmpty) {
                        _selectCell(row, col);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        color: secilenTasimaNoktasi == Point(row, col)
                            ? Colors.orange.shade200
                            : _getBonusColor(bonusBoard[row][col], isLocked,
                                isSelected, row, col),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              board[row][col],
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          //if (trapBoard[row][col] != '')
                            //_buildTrapMarker(trapBoard[row][col]),
                          //if (rewardBoard[row][col] != '')
                            //_buildRewardMarker(rewardBoard[row][col]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // GÜNCELLENEN SIZEDBOX BLOĞU BURADA
            SizedBox(
              height: 170,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (currentWord.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        validWords.contains(_toTurkishUpper(currentWord))
                            ? "Tahmini Puan: ${kelimePuaniHesapla(currentWord)}"
                            : "Geçersiz kelime",
                        style: TextStyle(
                          color:
                              validWords.contains(_toTurkishUpper(currentWord))
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  const Text('Senin Harflerin:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 10,
                    children: letters.map((letter) {
                      return ChoiceChip(
                        label:
                            Text(letter, style: const TextStyle(fontSize: 20)),
                        selected: selectedLetter == letter,
                        selectedColor: Colors.purple.shade200,
                        onSelected: oyuncuSirasi
                            ? (selected) async {
                                if (harfYasagiAktif &&
                                    dondurulenHarfler.contains(letter)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            "$letter harfi bu tur kullanılamaz.")),
                                  );
                                  return;
                                }

                                if (letter == "JOKER") {
                                  final chosen = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      final List<String> allLetters =
                                          harfPuanlari.keys
                                              .where((h) => h != 'JOKER')
                                              .toList();
                                      return AlertDialog(
                                        title:
                                            const Text('JOKER için harf seçin'),
                                        content: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: allLetters.map((char) {
                                            return ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(char),
                                              child: Text(char),
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    },
                                  );
                                  if (chosen != null) {
                                    setState(() {
                                      selectedLetter = chosen;
                                      letters.remove("JOKER");
                                    });
                                  }
                                } else {
                                  setState(() {
                                    selectedLetter = selected ? letter : null;
                                  });
                                }
                              }
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: oyuncuSirasi ? _submitWord : null,
                    child: const Text("Tahmin Et"),
                  ),
                ],
              ),
            ),
            if (tasimaModu)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: secilenTasimaNoktasi != null
                      ? () {
                          setState(() {
                            tasimaModu = false;
                            secilenTasimaNoktasi = null;
                          });
                          // Oyuncu sırası aynen devam eder. Sadece süre dolunca sıra geçer.
                        }
                      : null,
                  child: const Text("Taşımayı Onayla"),
                ),
              ),

            Wrap(
              spacing: 8,
              children: [
                if (kazanilanJokerler.contains('HARFYASAK'))
                  ElevatedButton(
                    onPressed:
                        oyuncuSirasi ? () => kullanJoker('HARFYASAK') : null,
                    child: const Text("Harf Yasağı"),
                  ),
                if (kazanilanJokerler.contains('BOLGE'))
                  ElevatedButton(
                    onPressed: oyuncuSirasi ? () => kullanJoker('BOLGE') : null,
                    child: const Text("Bölge Yasağı"),
                  ),
                if (kazanilanJokerler.contains('EKSTRA'))
                  ElevatedButton(
                    onPressed:
                        oyuncuSirasi ? () => kullanJoker('EKSTRA') : null,
                    child: const Text("Ekstra Hamle"),
                  ),
                ElevatedButton(
                  onPressed: oyuncuSirasi
                      ? () {
                          oyuncuTimer?.cancel();
                          setState(() {
                            harfYasagiAktif = false;
                            bolgeYasagiAktif = false;
                            ekstraHamleAktif = false;
                            dondurulenHarfler.clear();
                            oyuncuSirasi = false;
                          });
                          startOyuncuTimer();
                        }
                      : null,
                  child: const Text("Pas Geç"),
                ),
                ElevatedButton(
                  onPressed: oyuncuSirasi
                      ? () async {
                          countdownTimer?.cancel();
                          oyuncuTimer?.cancel();
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          int totalGames = prefs.getInt('totalGames') ?? 0;
                          await prefs.setInt('totalGames', totalGames + 1);

                          if (!mounted) return;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => AlertDialog(
                              title: const Text("Teslim Oldunuz"),
                              content: const Text("Rakip oyunu kazandı."),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/home', (_) => false);
                                  },
                                  child: const Text("Tamam"),
                                )
                              ],
                            ),
                          );
                        }
                      : null,
                  child: const Text("Teslim Ol"),
                ),
                ElevatedButton(
                  onPressed: oyuncuSirasi
                      ? () {
                          setState(() {
                            tasimaModu = !tasimaModu;
                            secilenTasimaNoktasi = null;
                          });
                        }
                      : null,
                  child: Text(tasimaModu ? "Taşıma Modu: Açık" : "Taşıma Modu"),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}