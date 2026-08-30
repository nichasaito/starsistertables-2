import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';

// ตัวแปร Global สำหรับเก็บข้อมูลผู้ใช้งานปัจจุบัน
String globalUserId = '';
String globalUserName = '';
String globalUserAvatar = '🐱';
String globalUserTitle = '';
String globalUserFrame = '';
List<String> globalUnlockedTitles = [];
List<String> globalUnlockedFrames = [];
Timestamp? globalBuffX2Until;
int globalUserLevel = 1;
int globalUserUpdateCount = 0;
int globalUserScore = 0;
int globalUserHearts = 0;
int globalUserShields = 0;
Map<String, dynamic> globalLastHeartSent = {};
Map<String, dynamic> globalUserPet = {};
List<dynamic> globalPetInventory = [];
List<dynamic> globalCardInventory = []; // คลังการ์ดสะสม

// รายชื่อสัตว์เลี้ยง 18 ชนิด (รวมแรคคูน 🦝)
const List<Map<String, String>> petTypesList = [
  {'type': '🐱', 'name': 'แมว'},
  {'type': '🐶', 'name': 'หมา'},
  {'type': '🐔', 'name': 'ไก่'},
  {'type': '🐦', 'name': 'นก'},
  {'type': '🦒', 'name': 'ยีราฟ'},
  {'type': '🐷', 'name': 'หมู'},
  {'type': '🐹', 'name': 'หนู'},
  {'type': '🦆', 'name': 'เป็ด'},
  {'type': '🦛', 'name': 'ฮิปโป'},
  {'type': '🐵', 'name': 'ลิง'},
  {'type': '🐹', 'name': 'แฮมสเตอร์'},
  {'type': '🦇', 'name': 'ค้างคาว'},
  {'type': '🦄', 'name': 'ยูนิคอร์น'},
  {'type': '🦊', 'name': 'จิ้งจอก'},
  {'type': '🦖', 'name': 'ไดโนเสาร์'},
  {'type': '🐬', 'name': 'ปลาโลมา'},
  {'type': '🐢', 'name': 'เต่า'},
  {'type': '🦝', 'name': 'แรคคูน'},
];

// รายการไอเทมในตู้กาชาสัตว์เลี้ยง (16 ชนิด)
const List<Map<String, dynamic>> petGachaDatabase = [
  {'name': '⚡ ดาบสายฟ้า Challenger (+50 ATK)', 'type': 'weapon', 'atk': 50, 'hp': 0},
  {'name': '🔱 ตรีศูลเจ้าสมุทร (+45 ATK)', 'type': 'weapon', 'atk': 45, 'hp': 0},
  {'name': '⚔️ ดาบคาตานะเพลิง (+40 ATK)', 'type': 'weapon', 'atk': 40, 'hp': 0},
  {'name': '🪄 คทาเวทมนตร์ดวงดาว (+35 ATK)', 'type': 'weapon', 'atk': 35, 'hp': 0},
  {'name': '🥊 นวมมังกรทอง (+30 ATK)', 'type': 'weapon', 'atk': 30, 'hp': 0},
  {'name': '🏹 ธนูเอลฟ์สายลม (+28 ATK)', 'type': 'weapon', 'atk': 28, 'hp': 0},
  {'name': '🪓 ขวานไวกิ้งโบราณ (+25 ATK)', 'type': 'weapon', 'atk': 25, 'hp': 0},
  {'name': '🐟 ปลากรอบในตำนาน (+15 ATK)', 'type': 'weapon', 'atk': 15, 'hp': 0},
  {'name': '👑 มงกุฎทองคำจักรพรรดิ (+100 HP)', 'type': 'hat', 'atk': 0, 'hp': 100},
  {'name': '🪖 หมวกเกราะอัศวิน (+80 HP)', 'type': 'hat', 'atk': 0, 'hp': 80},
  {'name': '🥽 แว่นส่องมิติ (+70 HP)', 'type': 'hat', 'atk': 0, 'hp': 70},
  {'name': '🕶️ แว่นกันแดดนีออน (+60 HP)', 'type': 'hat', 'atk': 0, 'hp': 60},
  {'name': '🌸 มงกุฎดอกไม้ภูติ (+55 HP)', 'type': 'hat', 'atk': 0, 'hp': 55},
  {'name': '🎀 โบว์รุ้งประกาย (+50 HP)', 'type': 'hat', 'atk': 0, 'hp': 50},
  {'name': '🎧 หูฟังเกมมิ่งเรืองแสง (+45 HP)', 'type': 'hat', 'atk': 0, 'hp': 45},
  {'name': '🎀 โบชมพู (+20 HP)', 'type': 'hat', 'atk': 0, 'hp': 20},
];

// โมเดลการ์ดอวกาศ 12 แบบ
class CardReward {
  final String name;
  final String rarity;
  final String emoji;
  final Color color;
  final int power;

  const CardReward(this.name, this.rarity, this.emoji, this.color, this.power);
}

const List<CardReward> galaxyMeowCards = [
  CardReward('สก็อตติชโฟลด์หินอุกกาบาต', 'Common 🥉', '🐱🪐', Colors.blueGrey, 50),
  CardReward('เปอร์เซียเนบิวลาพาสเทล', 'Common 🥉', '🐱🌌', Colors.purpleAccent, 55),
  CardReward('วิเชียรมาศจันทร์เสี้ยว', 'Common 🥉', '🐱🌙', Colors.indigo, 60),
  CardReward('ส้มจอมซนแห่งทางช้างเผือก', 'Common 🥉', '🐱⭐', Colors.orange, 65),
  CardReward('สฟิงซ์นักท่องกาแล็กซี', 'Rare 🥈', '🛸🐈', Colors.teal, 80),
  CardReward('บริติชชอร์ตฮายร์ดาวตก', 'Rare 🥈', '🌠🐱', Colors.cyan, 85),
  CardReward('แรคคูนอวกาศเพื่อนซี้เหมียว', 'Rare 🥈', '🦝🚀', Colors.blue, 90),
  CardReward('สก็อตติชโฟลด์สูญญากาศ', 'Rare 🥈', '🪐🐾', Colors.deepPurple, 95),
  CardReward('เมนคูนราชันย์ทางช้างเผือก', 'Super Rare 🥇', '👑🦁', Colors.amber, 120),
  CardReward('เบงกอลซูเปอร์โนวาประกายเพชร', 'Super Rare 🥇', '✨🐆', Colors.pink, 135),
  CardReward('ไซบีเรียนพายุสุริยะ', 'Super Rare 🥇', '☀️🐈', Colors.deepOrange, 150),
  CardReward('แบล็คโฮลคิตตี้ (ตำนานแห่งความมืด)', 'Secret Rare 💎🔥', '🕳️🐈‍⬛', Color(0xFF111111), 250),
];

// ฟังก์ชันแกะค่าโบนัส ATK และ HP
int getItemBonusAtk(String itemName) {
  if (itemName.isEmpty || itemName == 'ไม่มี') return 0;
  final match = RegExp(r'\+(\d+)\s*ATK').firstMatch(itemName);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '0') ?? 0;
  }
  return 0;
}

int getItemBonusHp(String itemName) {
  if (itemName.isEmpty || itemName == 'ไม่มี') return 0;
  final match = RegExp(r'\+(\d+)\s*HP').firstMatch(itemName);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '0') ?? 0;
  }
  return 0;
}

// คลังอิโมจิโปรไฟล์ 60+ แบบ
const List<String> avatarList = [
  '🐱', '🐶', '🦊', '🐼', '🐰', '🐻', '🦁', '🐯', '🐸', '🐵', 
  '🦄', '🐧', '🦉', '🐨', '🐹', '🐥', '🐙', '🐬', '🦖', '🐝', 
  '🦋', '🦥', '🦦', '🦔', '🐺', '🐮', '🐷', '🐲', '🦈',
  '☕', '🧋', '🍰', '🍩', '🍕', '🍔', '🍟', '🍣', '🍦', '🍓', 
  '🥑', '🍜', '🥐', '🥞', '🍪', '🍫', '🍿', '🍹', '🍧', '🍉',
  '👑', '⭐', '✨', '🔥', '💎', '🎮', '🎱', '🎯', '🎨', '🎧', 
  '🚀', '🛸', '⚡', '🌈', '🍀', '🌸', '🌻', '🌙', '🪄', '💖'
];

String getTodayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StarSister Tables',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue[900]!),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            globalUserId = snapshot.data!.uid;
            return const MainScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

// Widget แสดงผลรูปโปรไฟล์
Widget buildUserAvatarWidget(String avatar, {double radius = 24, double fontSize = 24, String frame = ''}) {
  bool isUrl = avatar.startsWith('http://') || avatar.startsWith('https://');
  bool isBase64 = avatar.startsWith('data:image');

  ImageProvider? bgImage;
  if (isUrl) {
    bgImage = NetworkImage(avatar);
  } else if (isBase64) {
    try {
      final base64String = avatar.split(',').last;
      final bytes = base64Decode(base64String);
      bgImage = MemoryImage(bytes);
    } catch (_) {
      bgImage = null;
    }
  }
  
  BoxDecoration? frameDecoration;
  if (frame == 'gold') {
    frameDecoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.amber[600]!, width: 3),
      boxShadow: const [BoxShadow(color: Colors.amberAccent, blurRadius: 8, spreadRadius: 1)],
    );
  } else if (frame == 'neon') {
    frameDecoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.cyanAccent, width: 3),
      boxShadow: const [BoxShadow(color: Colors.cyanAccent, blurRadius: 8, spreadRadius: 1)],
    );
  } else if (frame == 'rainbow') {
    frameDecoration = const BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(
        colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
      ),
      boxShadow: [
        BoxShadow(color: Colors.purpleAccent, blurRadius: 6, spreadRadius: 1),
        BoxShadow(color: Colors.cyanAccent, blurRadius: 8, spreadRadius: 1),
      ],
    );
  } else if (frame == 'fire') {
    frameDecoration = const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [Colors.deepOrange, Colors.orangeAccent, Colors.redAccent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      boxShadow: [
        BoxShadow(color: Colors.deepOrangeAccent, blurRadius: 8, spreadRadius: 2),
      ],
    );
  } else if (frame == 'ice') {
    frameDecoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.lightBlueAccent, width: 3),
      boxShadow: const [
        BoxShadow(color: Colors.lightBlueAccent, blurRadius: 8, spreadRadius: 1.5),
        BoxShadow(color: Colors.white, blurRadius: 4, spreadRadius: 0.5),
      ],
    );
  } else if (frame == 'challenger') {
    frameDecoration = const BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(
        colors: [Colors.amber, Colors.purpleAccent, Colors.cyanAccent, Colors.amber],
      ),
      boxShadow: [
        BoxShadow(color: Colors.purpleAccent, blurRadius: 10, spreadRadius: 2),
        BoxShadow(color: Colors.amberAccent, blurRadius: 6, spreadRadius: 1),
      ],
    );
  } else if (frame == 'wing') {
    frameDecoration = const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [Colors.amber, Colors.white, Colors.amberAccent]),
      boxShadow: [
        BoxShadow(color: Colors.amberAccent, blurRadius: 12, spreadRadius: 3),
        BoxShadow(color: Colors.white, blurRadius: 6, spreadRadius: 1),
      ],
    );
  } else if (frame == 'aura') {
    frameDecoration = const BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(colors: [Colors.deepPurple, Colors.indigoAccent, Colors.purpleAccent, Colors.deepPurple]),
      boxShadow: [
        BoxShadow(color: Colors.purpleAccent, blurRadius: 12, spreadRadius: 2.5),
      ],
    );
  } else if (frame == 'sparkle') {
    frameDecoration = const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [Colors.pinkAccent, Colors.amberAccent, Colors.purpleAccent]),
      boxShadow: [
        BoxShadow(color: Colors.pinkAccent, blurRadius: 10, spreadRadius: 2),
        BoxShadow(color: Colors.yellowAccent, blurRadius: 4, spreadRadius: 1),
      ],
    );
  } else if (frame == 'silver') {
    frameDecoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.blueGrey[200]!, width: 3),
      boxShadow: [
        BoxShadow(color: Colors.blueGrey[300]!, blurRadius: 8, spreadRadius: 1.5),
        const BoxShadow(color: Colors.white70, blurRadius: 4, spreadRadius: 0.5),
      ],
    );
  } else if (frame == 'wind') {
    frameDecoration = const BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(colors: [Colors.tealAccent, Colors.greenAccent, Colors.teal, Colors.tealAccent]),
      boxShadow: [
        BoxShadow(color: Colors.tealAccent, blurRadius: 8, spreadRadius: 2),
      ],
    );
  } else if (frame == 'dark') {
    frameDecoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.purple[900]!, width: 3),
      boxShadow: const [
        BoxShadow(color: Colors.black87, blurRadius: 10, spreadRadius: 3),
        BoxShadow(color: Colors.deepPurple, blurRadius: 6, spreadRadius: 1),
      ],
    );
  }

  Widget circle = CircleAvatar(
    radius: radius,
    backgroundColor: Colors.blue[50],
    backgroundImage: bgImage,
    child: (bgImage == null && !isUrl && !isBase64) ? Text(avatar, style: TextStyle(fontSize: fontSize)) : null,
  );

  if (frameDecoration != null) {
    return Container(
      decoration: frameDecoration,
      padding: const EdgeInsets.all(3),
      child: circle,
    );
  }

  return circle;
}

// ==========================================
// 3D Animated Pet Character Widget
// ==========================================
class PetCharacter3DWidget extends StatefulWidget {
  final String petType;
  final String equippedWeapon;
  final String equippedHat;
  final double size;
  final bool showHeartEffect;

  const PetCharacter3DWidget({
    super.key,
    required this.petType,
    required this.equippedWeapon,
    required this.equippedHat,
    this.size = 180,
    this.showHeartEffect = false,
  });

  @override
  State<PetCharacter3DWidget> createState() => _PetCharacter3DWidgetState();
}

class _PetCharacter3DWidgetState extends State<PetCharacter3DWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _extractEmoji(String text) {
    if (text.isEmpty || text == 'ไม่มี') return '';
    final runes = text.runes.toList();
    if (runes.isNotEmpty) {
      return String.fromCharCode(runes.first);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final hatEmoji = _extractEmoji(widget.equippedHat);
    final weaponEmoji = _extractEmoji(widget.equippedWeapon);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Text(
                      widget.petType,
                      style: TextStyle(
                        fontSize: widget.size * 0.44,
                        shadows: const [
                          Shadow(color: Colors.black26, offset: Offset(2, 4), blurRadius: 4),
                        ],
                      ),
                    ),
                    if (hatEmoji.isNotEmpty && hatEmoji != '🐟')
                      Positioned(
                        top: -widget.size * 0.12,
                        child: Transform.rotate(
                          angle: -0.1,
                          child: Text(
                            hatEmoji,
                            style: TextStyle(
                              fontSize: widget.size * 0.22,
                              shadows: const [
                                Shadow(color: Colors.black26, offset: Offset(2, 3), blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (weaponEmoji.isNotEmpty)
                      Positioned(
                        right: -widget.size * 0.14,
                        bottom: widget.size * 0.08,
                        child: Transform.rotate(
                          angle: 0.25,
                          child: Text(
                            weaponEmoji,
                            style: TextStyle(
                              fontSize: widget.size * 0.24,
                              shadows: const [
                                Shadow(color: Colors.black38, offset: Offset(2, 4), blurRadius: 5),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (widget.showHeartEffect)
            Positioned(
              top: -10,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, val, child) {
                  return Opacity(
                    opacity: 1.0 - val,
                    child: Transform.translate(
                      offset: Offset(0, -30 * val),
                      child: const Text('💖', style: TextStyle(fontSize: 32)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// 🌟 Widget ดีไซน์การ์ดพรีเมียม (ป้องกันการล้นจอ 100% ด้วย Expanded + FittedBox)
class PremiumMeowCardWidget extends StatelessWidget {
  final String emoji;
  final String name;
  final String rarity;
  final String power;

  const PremiumMeowCardWidget({
    super.key,
    required this.emoji,
    required this.name,
    required this.rarity,
    required this.power,
  });

  @override
  Widget build(BuildContext context) {
    List<Color> bgGradient = [const Color(0xFF1e293b), const Color(0xFF0f172a)];
    Color borderColor = Colors.blueGrey;
    Color glowColor = Colors.transparent;

    if (rarity.contains('Rare') && !rarity.contains('Super') && !rarity.contains('Secret')) {
      bgGradient = [const Color(0xFF3b82f6), const Color(0xFF1e1b4b)];
      borderColor = Colors.cyanAccent;
      glowColor = Colors.cyan.withOpacity(0.3);
    } else if (rarity.contains('Super')) {
      bgGradient = [const Color(0xFFd97706), const Color(0xFF78350f)];
      borderColor = Colors.amberAccent;
      glowColor = Colors.amber.withOpacity(0.4);
    } else if (rarity.contains('Secret')) {
      bgGradient = [const Color(0xFF7f1d1d), const Color(0xFF18181b)];
      borderColor = Colors.redAccent;
      glowColor = Colors.redAccent.withOpacity(0.5);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 6, spreadRadius: 1),
          const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
              ),
              child: Text(
                rarity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: borderColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '⚡ Power: $power',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// บันทึกคลิก: เลเวลอัป + สัตว์เลี้ยงได้ EXP + นับภารกิจ
Future<void> registerUserUpdateAction(BuildContext? context, {String? collectionName}) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentUid = user?.uid ?? globalUserId;
  if (currentUid.isEmpty) return;
  globalUserId = currentUid;

  final userDocRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
  final today = getTodayKey();

  try {
    final userSnap = await userDocRef.get();
    final userData = userSnap.data() ?? {};

    bool isBuffActive = globalBuffX2Until != null && globalBuffX2Until!.toDate().isAfter(DateTime.now());

    int curUpdateCount = (userData['updateCount'] is num) ? (userData['updateCount'] as num).toInt() : 0;
    int curLevel = (userData['level'] is num) ? (userData['level'] as num).toInt() : 1;
    int curScore = (userData['score'] is num) ? (userData['score'] as num).toInt() : 0;

    curUpdateCount += 1;
    int gainedLevels = 0;
    int bonusScore = 0;

    if (curUpdateCount >= 100) {
      gainedLevels = curUpdateCount ~/ 100;
      curUpdateCount = curUpdateCount % 100;
      curLevel += gainedLevels;

      int baseBonus = 50;
      bonusScore = isBuffActive ? (baseBonus * 2 * gainedLevels) : (baseBonus * gainedLevels);
      curScore += bonusScore;
    }

    Map<String, dynamic> petData = {};
    if (userData['pet'] is Map) {
      petData = Map<String, dynamic>.from(userData['pet']);
    } else {
      petData = {
        'name': 'น้องนำโชค',
        'type': '🐱',
        'level': 1,
        'exp': 0,
        'hp': 100,
        'equippedWeapon': '🐟 ปลากรอบในตำนาน (+15 ATK)',
        'equippedHat': '🎀 โบชมพู (+20 HP)',
      };
    }

    int pExp = (petData['exp'] is num) ? (petData['exp'] as num).toInt() + 5 : 5;
    int pLevel = (petData['level'] is num) ? (petData['level'] as num).toInt() : 1;
    bool petLeveledUp = false;

    while (pExp >= 100) {
      pExp -= 100;
      pLevel += 1;
      petLeveledUp = true;
    }
    petData['exp'] = pExp;
    petData['level'] = pLevel;

    // ถ้าเลเวลอัป ให้คำนวณ Max HP ใหม่แล้วรีเซ็ต HP ให้เต็มทันที
    if (petLeveledUp) {
      final String hat = petData['equippedHat'] ?? '';
      int maxHp = 80 + (pLevel * 20) + getItemBonusHp(hat);
      petData['hp'] = maxHp;
    }

    Map<String, dynamic> allDailyQuests = {};
    if (userData['dailyQuests'] is Map) {
      allDailyQuests = Map<String, dynamic>.from(userData['dailyQuests']);
    }

    Map<String, dynamic> todayQuest = {};
    if (allDailyQuests[today] is Map) {
      todayQuest = Map<String, dynamic>.from(allDailyQuests[today]);
    }

    int currentTableUpdates = (todayQuest['tableUpdates'] is num) ? (todayQuest['tableUpdates'] as num).toInt() : 0;
    todayQuest['tableUpdates'] = currentTableUpdates + 1;

    if (collectionName != null) {
      List<dynamic> updatedFloors = (todayQuest['updatedFloors'] is List) ? List.from(todayQuest['updatedFloors']) : [];
      if (!updatedFloors.contains(collectionName)) {
        updatedFloors.add(collectionName);
      }
      todayQuest['updatedFloors'] = updatedFloors;
    }

    allDailyQuests[today] = todayQuest;

    Map<String, dynamic> finalUpdate = {
      'updateCount': curUpdateCount,
      'level': curLevel,
      'score': curScore,
      'pet': petData,
      'dailyQuests': allDailyQuests,
    };

    await userDocRef.set(finalUpdate, SetOptions(merge: true));

    globalUserUpdateCount = curUpdateCount;
    globalUserLevel = curLevel;
    globalUserScore = curScore;
    globalUserPet = petData;

    if (gainedLevels > 0 && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber[800],
          content: Row(
            children: [
              const Icon(Icons.stars, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBuffActive 
                      ? '🎉 ยินดีด้วย! เลเวลอัปเป็น Lv.$globalUserLevel! (+โบนัสบัฟ x2 = $bonusScore แต้ม)'
                      : '🎉 ยินดีด้วย! เลเวลอัปเป็น Lv.$globalUserLevel! (+$bonusScore แต้มโบนัส)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    debugPrint('เกิดข้อผิดพลาดในการบันทึกเลเวล/ภารกิจ: $e');
  }
}

// บันทึกภารกิจ
Future<void> recordCustomDailyQuest(String questKey, dynamic value) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? globalUserId;
  if (currentUid.isEmpty) return;
  final today = getTodayKey();
  final userRef = FirebaseFirestore.instance.collection('users').doc(currentUid);

  try {
    final snap = await userRef.get();
    final data = snap.data() ?? {};

    Map<String, dynamic> allDailyQuests = {};
    if (data['dailyQuests'] is Map) {
      allDailyQuests = Map<String, dynamic>.from(data['dailyQuests']);
    }

    Map<String, dynamic> todayQuest = {};
    if (allDailyQuests[today] is Map) {
      todayQuest = Map<String, dynamic>.from(allDailyQuests[today]);
    }

    if (value is int && todayQuest[questKey] is num) {
      todayQuest[questKey] = (todayQuest[questKey] as num).toInt() + value;
    } else {
      todayQuest[questKey] = value;
    }

    allDailyQuests[today] = todayQuest;

    await userRef.set({'dailyQuests': allDailyQuests}, SetOptions(merge: true));
  } catch (e) {
    debugPrint('Error recording custom quest ($questKey): $e');
  }
}

// ==========================================
// AuthScreen
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedAvatar = '🐱';
  File? _pickedImageFile;
  String? _pickedImageBase64;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, maxHeight: 300, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBase64 = base64Encode(bytes);
        _pickedImageFile = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        UserCredential res = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = res.user!.uid;
        String finalAvatar = _selectedAvatar;

        if (_pickedImageBase64 != null) {
          finalAvatar = 'data:image/jpeg;base64,$_pickedImageBase64';
        }

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'id': uid,
          'name': name,
          'avatar': finalAvatar,
          'score': 0,
          'hearts': 0,
          'shields': 0,
          'lastHeartSent': {},
          'updateCount': 0,
          'level': 1,
          'title': '',
          'frame': '',
          'unlockedTitles': [],
          'unlockedFrames': [],
          'cardInventory': [],
          'buffX2Until': null,
          'email': email,
          'streakCount': 0,
          'lastCheckInDate': '',
          'dailyQuests': {},
          'pet': {
            'name': 'น้องนำโชค',
            'type': '🐱',
            'level': 1,
            'exp': 0,
            'hp': 100,
            'equippedWeapon': '🐟 ปลากรอบในตำนาน (+15 ATK)',
            'equippedHat': '🎀 โบชมพู (+20 HP)',
          },
          'petInventory': ['🐟 ปลากรอบในตำนาน (+15 ATK)', '🎀 โบชมพู (+20 HP)'],
        });
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'เกิดข้อผิดพลาด (${e.code})';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      } else if (e.code == 'email-already-in-use') {
        msg = 'อีเมลนี้ถูกใช้งานแล้ว';
      } else if (e.code == 'weak-password') {
        msg = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
      } else if (e.code == 'invalid-email') {
        msg = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else if (e.code == 'network-request-failed') {
        msg = 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'StarSister Tables',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLogin ? 'เข้าสู่ระบบเพื่อใช้งาน' : 'สร้างโปรไฟล์ใหม่',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  if (!isLogin) ...[
                    const Text('เลือกรูปโปรไฟล์', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue[50],
                          backgroundImage: _pickedImageBase64 != null 
                              ? MemoryImage(base64Decode(_pickedImageBase64!)) 
                              : (_pickedImageFile != null ? FileImage(_pickedImageFile!) : null),
                          child: (_pickedImageBase64 == null && _pickedImageFile == null)
                              ? Text(_selectedAvatar, style: const TextStyle(fontSize: 32))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text('เลือกจากโทรศัพท์'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 140,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: avatarList.map((avatar) {
                              final isSelected = avatar == _selectedAvatar && _pickedImageFile == null && _pickedImageBase64 == null;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedAvatar = avatar;
                                  _pickedImageFile = null;
                                  _pickedImageBase64 = null;
                                }),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue[100] : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.blue[900]! : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Center(child: Text(avatar, style: const TextStyle(fontSize: 20))),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อผู้ใช้งาน (เช่น Nicha)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'อีเมล (Email)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text(
                          isLogin ? 'เข้าสู่ระบบ' : 'ลงทะเบียนใช้งาน',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin ? 'ยังไม่มีบัญชี? สมัครสมาชิกที่นี่' : 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
                      style: TextStyle(color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MainScreen
// ==========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _listenCurrentUserData();
  }

  void _listenCurrentUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      globalUserId = user.uid;
      _userSubscription = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            globalUserName = data['name'] ?? 'Staff';
            globalUserAvatar = data['avatar'] ?? '🐱';
            globalUserTitle = data['title'] ?? '';
            globalUserFrame = data['frame'] ?? '';
            globalUnlockedTitles = List<String>.from(data['unlockedTitles'] ?? []);
            globalUnlockedFrames = List<String>.from(data['unlockedFrames'] ?? []);
            globalCardInventory = List<dynamic>.from(data['cardInventory'] ?? []);

            if (globalUserTitle.isNotEmpty && !globalUnlockedTitles.contains(globalUserTitle)) {
              globalUnlockedTitles.add(globalUserTitle);
            }
            if (globalUserFrame.isNotEmpty && !globalUnlockedFrames.contains(globalUserFrame)) {
              globalUnlockedFrames.add(globalUserFrame);
            }

            globalBuffX2Until = data['buffX2Until'];
            globalUserLevel = (data['level'] is num) ? (data['level'] as num).toInt() : 1;
            globalUserUpdateCount = (data['updateCount'] is num) ? (data['updateCount'] as num).toInt() : 0;
            globalUserScore = (data['score'] is num) ? (data['score'] as num).toInt() : 0;
            globalUserHearts = (data['hearts'] is num) ? (data['hearts'] as num).toInt() : 0;
            globalUserShields = (data['shields'] is num) ? (data['shields'] as num).toInt() : 0;
            globalLastHeartSent = data['lastHeartSent'] != null ? Map<String, dynamic>.from(data['lastHeartSent']) : {};
            globalUserPet = data['pet'] != null ? Map<String, dynamic>.from(data['pet']) : {};
            globalPetInventory = List<dynamic>.from(data['petInventory'] ?? []);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(text: globalUserName);
    String selectedAvatar = globalUserAvatar;
    String selectedTitle = globalUserTitle;
    String selectedFrame = globalUserFrame;
    File? newPickedFile;
    String? newPickedFileBase64;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('แก้ไขโปรไฟล์ & คลังตกแต่ง', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เลือกรูปโปรไฟล์', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          newPickedFileBase64 != null
                              ? Container(
                                  padding: const EdgeInsets.all(3),
                                  child: CircleAvatar(
                                    radius: 28, 
                                    backgroundImage: MemoryImage(base64Decode(newPickedFileBase64!)),
                                  ),
                                )
                              : buildUserAvatarWidget(selectedAvatar, radius: 28, fontSize: 28, frame: selectedFrame),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final picker = ImagePicker();
                                    final picked = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 300,
                                      maxHeight: 300,
                                      imageQuality: 70,
                                    );
                                    if (picked != null) {
                                      final bytes = await picked.readAsBytes();
                                      setDialogState(() {
                                        newPickedFileBase64 = base64Encode(bytes);
                                        newPickedFile = File(picked.path);
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.image, size: 16),
                            label: const Text('เลือกจากเครื่อง'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 120,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: avatarList.map((avatar) {
                                final isSelected = avatar == selectedAvatar && newPickedFile == null && newPickedFileBase64 == null;
                                return GestureDetector(
                                  onTap: isSaving
                                      ? null
                                      : () => setDialogState(() {
                                            selectedAvatar = avatar;
                                            newPickedFile = null;
                                            newPickedFileBase64 = null;
                                          }),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue[100] : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.blue[900]! : Colors.grey[300]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Center(child: Text(avatar, style: const TextStyle(fontSize: 18))),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อผู้ใช้งาน',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('🖼️ กรอบโปรไฟล์ในคลัง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('ไม่ใส่กรอบ'),
                            selected: selectedFrame.isEmpty,
                            onSelected: (selected) {
                              if (selected) setDialogState(() => selectedFrame = '');
                            },
                          ),
                          if (globalUnlockedFrames.contains('neon'))
                            ChoiceChip(
                              label: const Text('💎 นีออน'),
                              selected: selectedFrame == 'neon',
                              selectedColor: Colors.cyan[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'neon' : ''),
                            ),
                          if (globalUnlockedFrames.contains('gold'))
                            ChoiceChip(
                              label: const Text('👑 ทองคำ'),
                              selected: selectedFrame == 'gold',
                              selectedColor: Colors.amber[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'gold' : ''),
                            ),
                          if (globalUnlockedFrames.contains('rainbow'))
                            ChoiceChip(
                              label: const Text('🌈 สีรุ้ง'),
                              selected: selectedFrame == 'rainbow',
                              selectedColor: Colors.purple[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'rainbow' : ''),
                            ),
                          if (globalUnlockedFrames.contains('fire'))
                            ChoiceChip(
                              label: const Text('🔥 เปลวไฟ'),
                              selected: selectedFrame == 'fire',
                              selectedColor: Colors.deepOrange[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'fire' : ''),
                            ),
                          if (globalUnlockedFrames.contains('ice'))
                            ChoiceChip(
                              label: const Text('❄️ น้ำแข็ง'),
                              selected: selectedFrame == 'ice',
                              selectedColor: Colors.lightBlue[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'ice' : ''),
                            ),
                          if (globalUnlockedFrames.contains('challenger'))
                            ChoiceChip(
                              label: const Text('🏆 Challenger Aura ⚡'),
                              selected: selectedFrame == 'challenger',
                              selectedColor: Colors.purple[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'challenger' : ''),
                            ),
                          if (globalUnlockedFrames.contains('silver'))
                            ChoiceChip(
                              label: const Text('🥈 สีเงิน'),
                              selected: selectedFrame == 'silver',
                              selectedColor: Colors.blueGrey[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'silver' : ''),
                            ),
                          if (globalUnlockedFrames.contains('wind'))
                            ChoiceChip(
                              label: const Text('🍃 สายลม'),
                              selected: selectedFrame == 'wind',
                              selectedColor: Colors.teal[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'wind' : ''),
                            ),
                          if (globalUnlockedFrames.contains('dark'))
                            ChoiceChip(
                              label: const Text('🌑 ธาตุมืด'),
                              selected: selectedFrame == 'dark',
                              selectedColor: Colors.grey[400],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'dark' : ''),
                            ),
                          if (globalUnlockedFrames.contains('wing'))
                            ChoiceChip(
                              label: const Text('🪽 มีปีก'),
                              selected: selectedFrame == 'wing',
                              selectedColor: Colors.amber[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'wing' : ''),
                            ),
                          if (globalUnlockedFrames.contains('aura'))
                            ChoiceChip(
                              label: const Text('🔮 ออร่า'),
                              selected: selectedFrame == 'aura',
                              selectedColor: Colors.purple[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'aura' : ''),
                            ),
                          if (globalUnlockedFrames.contains('sparkle'))
                            ChoiceChip(
                              label: const Text('✨ วิ้งๆ'),
                              selected: selectedFrame == 'sparkle',
                              selectedColor: Colors.pink[100],
                              onSelected: (selected) => setDialogState(() => selectedFrame = selected ? 'sparkle' : ''),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('🎖️ ฉายาในคลัง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      globalUnlockedTitles.isEmpty
                          ? const Text('ยังไม่มีฉายา (ปลดล็อกได้จากร้านค้าหรือวงล้อ)', style: TextStyle(color: Colors.grey, fontSize: 13))
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ChoiceChip(
                                  label: const Text('ไม่ใช้ฉายา'),
                                  selected: selectedTitle.isEmpty,
                                  onSelected: (selected) {
                                    if (selected) setDialogState(() => selectedTitle = '');
                                  },
                                ),
                                ...globalUnlockedTitles.map((t) => ChoiceChip(
                                      label: Text(t),
                                      selected: selectedTitle == t,
                                      selectedColor: Colors.amber[200],
                                      onSelected: (selected) => setDialogState(() => selectedTitle = selected ? t : ''),
                                    )),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          if (newName.isEmpty) return;

                          setDialogState(() => isSaving = true);

                          try {
                            String finalAvatar = selectedAvatar;

                            if (newPickedFileBase64 != null) {
                              finalAvatar = 'data:image/jpeg;base64,$newPickedFileBase64';
                            }

                            await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
                              'name': newName,
                              'avatar': finalAvatar,
                              'title': selectedTitle,
                              'frame': selectedFrame,
                            });

                            setState(() {
                              globalUserName = newName;
                              globalUserAvatar = finalAvatar;
                              globalUserTitle = selectedTitle;
                              globalUserFrame = selectedFrame;
                            });

                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('บันทึก', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: [
          TableStatusScreen(onEditProfile: _showEditProfileDialog),
          const LeaderboardScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue[900],
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.table_restaurant), label: 'ผังโต๊ะ'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Rank, Pet & Shop'),
        ],
      ),
    );
  }
}

// ==========================================
// DailyQuestsScreen
// ==========================================
class DailyQuestsScreen extends StatefulWidget {
  const DailyQuestsScreen({super.key});

  @override
  State<DailyQuestsScreen> createState() => _DailyQuestsScreenState();
}

class _DailyQuestsScreenState extends State<DailyQuestsScreen> {
  final todayKey = getTodayKey();

  Future<void> _handleDailyMysteryBoxOpen(Map<String, dynamic> userData) async {
    final lastCheckInDate = userData['lastCheckInDate'] ?? '';
    int streakCount = (userData['streakCount'] is num) ? (userData['streakCount'] as num).toInt() : 0;

    if (lastCheckInDate == todayKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณเปิดกล่องสุ่มประจำวันไปแล้ว')),
      );
      return;
    }

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    if (lastCheckInDate == yesterdayKey) {
      streakCount = (streakCount % 7) + 1;
    } else {
      streakCount = 1;
    }

    final random = Random();
    final int mysteryPoints = 10 + random.nextInt(51); 
    int totalGainedPoints = mysteryPoints;

    if (streakCount == 7) {
      totalGainedPoints += 100;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(globalUserId);
    final userSnap = await userRef.get();
    final myData = userSnap.data() ?? {};

    Map<String, dynamic> allDailyQuests = {};
    if (myData['dailyQuests'] is Map) {
      allDailyQuests = Map<String, dynamic>.from(myData['dailyQuests']);
    }

    Map<String, dynamic> todayQuest = {};
    if (allDailyQuests[todayKey] is Map) {
      todayQuest = Map<String, dynamic>.from(allDailyQuests[todayKey]);
    }

    final firstCheckInDoc = await FirebaseFirestore.instance.collection('app_settings').doc('first_checkin_$todayKey').get();
    bool isFirstCheckInToday = false;
    if (!firstCheckInDoc.exists) {
      isFirstCheckInToday = true;
      await FirebaseFirestore.instance.collection('app_settings').doc('first_checkin_$todayKey').set({
        'userId': globalUserId,
        'userName': globalUserName,
        'time': Timestamp.now(),
      });
      todayQuest['isFirstCheckIn'] = true;
    }

    allDailyQuests[todayKey] = todayQuest;

    await userRef.set({
      'streakCount': streakCount,
      'lastCheckInDate': todayKey,
      'score': FieldValue.increment(totalGainedPoints),
      'dailyQuests': allDailyQuests,
    }, SetOptions(merge: true));

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Text('🎁', style: TextStyle(fontSize: 28)),
              SizedBox(width: 8),
              Text('เปิดกล่องของขวัญ!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ยินดีด้วย! คุณได้รับแต้มสุ่มประจำวัน:', style: TextStyle(fontSize: 15)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(16)),
                child: Text('+$mysteryPoints แต้ม ✨', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber[900])),
              ),
              if (streakCount == 7) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.deepOrange[100], borderRadius: BorderRadius.circular(12)),
                  child: const Text('🎉 โบนัสล็อกอินครบ 7 วันติด: +100 แต้ม!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                ),
              ],
              if (isFirstCheckInToday) ...[
                const SizedBox(height: 8),
                const Text('🏆 คุณเป็นคนแรกของวัน! (สำเร็จภารกิจราชาเปิดร้านแล้ว)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Text('สะสม Streak ต่อเนื่อง: $streakCount วันติด 🔥', style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ตกลง', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _claimQuestReward(String questKey, int rewardScore) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(globalUserId);
    final userSnap = await userRef.get();
    final myData = userSnap.data() ?? {};

    Map<String, dynamic> allDailyQuests = {};
    if (myData['dailyQuests'] is Map) {
      allDailyQuests = Map<String, dynamic>.from(myData['dailyQuests']);
    }

    Map<String, dynamic> todayQuest = {};
    if (allDailyQuests[todayKey] is Map) {
      todayQuest = Map<String, dynamic>.from(allDailyQuests[todayKey]);
    }

    todayQuest['claimed_$questKey'] = true;
    allDailyQuests[todayKey] = todayQuest;

    await userRef.set({
      'score': FieldValue.increment(rewardScore),
      'dailyQuests': allDailyQuests,
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber[800],
          content: Text('🎉 รับรางวัลสำเร็จ! (+$rewardScore แต้ม)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? globalUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ภารกิจ & กล่องสุ่มประจำวัน 🎯', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final lastCheckInDate = userData['lastCheckInDate'] ?? '';
          final int streakCount = (userData['streakCount'] is num) ? (userData['streakCount'] as num).toInt() : 0;
          final isCheckedInToday = lastCheckInDate == todayKey;

          final rawDaily = userData['dailyQuests'];
          Map<String, dynamic> dailyQuestsMap = {};
          if (rawDaily is Map && rawDaily[todayKey] is Map) {
            dailyQuestsMap = Map<String, dynamic>.from(rawDaily[todayKey]);
          }

          final int tableUpdates = (dailyQuestsMap['tableUpdates'] is num) ? (dailyQuestsMap['tableUpdates'] as num).toInt() : 0;
          final List<dynamic> heartSentUsers = (dailyQuestsMap['heartSentUsers'] is List) ? List.from(dailyQuestsMap['heartSentUsers']) : [];
          final int heartSentTotal = (dailyQuestsMap['heartSentTotal'] is num) ? (dailyQuestsMap['heartSentTotal'] as num).toInt() : 0;
          final bool isFirstCheckIn = dailyQuestsMap['isFirstCheckIn'] == true;
          final bool hasUpdatedDailyNote = dailyQuestsMap['hasUpdatedDailyNote'] == true;
          final int wheelSpinCount = (dailyQuestsMap['wheelSpinCount'] is num) ? (dailyQuestsMap['wheelSpinCount'] as num).toInt() : 0;
          final bool hasChattedToday = dailyQuestsMap['hasChattedToday'] == true;
          final List<dynamic> updatedFloors = (dailyQuestsMap['updatedFloors'] is List) ? List.from(dailyQuestsMap['updatedFloors']) : [];

          final bool q1Claimed = dailyQuestsMap['claimed_q1'] == true;
          final bool q2Claimed = dailyQuestsMap['claimed_q2'] == true;
          final bool q3Claimed = dailyQuestsMap['claimed_q3'] == true;
          final bool q4Claimed = dailyQuestsMap['claimed_q4'] == true;
          final bool qNewsClaimed = dailyQuestsMap['claimed_q_news'] == true;
          final bool qSpinClaimed = dailyQuestsMap['claimed_q_spin'] == true;
          final bool qChatClaimed = dailyQuestsMap['claimed_q_chat'] == true;
          final bool qFloorsClaimed = dailyQuestsMap['claimed_q_floors'] == true;
          final bool qMasterClaimed = dailyQuestsMap['claimed_q_master'] == true;

          final bool q1Completed = tableUpdates >= 30;
          final bool q2Completed = heartSentUsers.length >= 5;
          final bool q3Completed = heartSentTotal >= 20;
          final bool q4Completed = isFirstCheckIn;
          final bool qNewsCompleted = hasUpdatedDailyNote;
          final bool qSpinCompleted = wheelSpinCount >= 1;
          final bool qChatCompleted = hasChattedToday;
          final bool qFloorsCompleted = updatedFloors.contains('tables_f1') && updatedFloors.contains('tables_f2') && updatedFloors.contains('tables_f3');

          final otherCompletedQuests = [
            q1Completed,
            q2Completed,
            q3Completed,
            q4Completed,
            qNewsCompleted,
            qSpinCompleted,
            qChatCompleted,
            qFloorsCompleted,
          ].where((c) => c).length;
          final bool qMasterCompleted = otherCompletedQuests >= 4;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.card_giftcard, color: Colors.deepOrange, size: 28),
                              const SizedBox(width: 8),
                              Text('Daily Mystery Box 🎁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[900])),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(12)),
                            child: Text('$streakCount วันติด 🔥', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('เปิดกล่องสุ่มแต้มฟรีวันละ 1 ครั้ง (ลุ้นรับ 10 - 60 แต้ม) และล็อกอินครบ 7 วันรับโบนัส +100 แต้ม!', style: TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final dayNum = index + 1;
                          final bool isPastOrToday = streakCount >= dayNum && (isCheckedInToday || streakCount > dayNum);
                          final bool isCurrentTarget = !isCheckedInToday && streakCount + 1 == dayNum;

                          return Column(
                            children: [
                              Text('D$dayNum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Container(
                                width: 38,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isPastOrToday 
                                      ? Colors.green 
                                      : (isCurrentTarget ? Colors.amber[100] : Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPastOrToday 
                                        ? Colors.green 
                                        : (isCurrentTarget ? Colors.amber[800]! : Colors.grey[300]!),
                                    width: isCurrentTarget ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isPastOrToday ? Icons.check : (dayNum == 7 ? Icons.stars : Icons.card_giftcard),
                                      color: isPastOrToday ? Colors.white : (dayNum == 7 ? Colors.deepOrange : Colors.amber[700]),
                                      size: 16,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dayNum == 7 ? '+100' : 'สุ่ม',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isPastOrToday ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCheckedInToday ? Colors.grey : Colors.amber[800],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isCheckedInToday ? null : () => _handleDailyMysteryBoxOpen(userData),
                          icon: Icon(isCheckedInToday ? Icons.done_all : Icons.card_giftcard, color: Colors.white),
                          label: Text(
                            isCheckedInToday ? 'เปิดกล่องสุ่มวันนี้แล้ว ✅' : 'เปิดกล่องสุ่มแต้มประจำวัน (10-60 แต้ม)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: const [
                  Icon(Icons.assignment, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('ภารกิจประจำวัน (รีเซ็ตทุกวัน)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),

              _buildQuestCard(
                title: '⭐ All-Clear Master (ภารกิจใหญ่)',
                subtitle: 'ทำภารกิจรายวันอื่นๆ สำเร็จอย่างน้อย 4 ภารกิจ ($otherCompletedQuests/4)',
                progress: min(1.0, otherCompletedQuests / 4.0),
                rewardText: '+20 แต้ม',
                rewardScore: 20,
                isCompleted: qMasterCompleted,
                isClaimed: qMasterClaimed,
                onClaim: () => _claimQuestReward('q_master', 20),
                isHighlight: true,
              ),
              _buildQuestCard(
                title: '🏃 สายตรวจครบทุกชั้น',
                subtitle: 'อัปเดตสถานะโต๊ะในชั้น 1, ชั้น 2 และชั้น 3 (${updatedFloors.length}/3 ชั้น)',
                progress: min(1.0, updatedFloors.length / 3.0),
                rewardText: '+10 แต้ม',
                rewardScore: 10,
                isCompleted: qFloorsCompleted,
                isClaimed: qFloorsClaimed,
                onClaim: () => _claimQuestReward('q_floors', 10),
              ),
              _buildQuestCard(
                title: '📌 ผู้ช่วยกระจายข่าว',
                subtitle: hasUpdatedDailyNote ? 'อัปเดตประกาศสำคัญประจำวันแล้ว' : 'กดแก้ไขหรืออัปเดตประกาศสำคัญประจำวัน 1 ครั้ง',
                progress: hasUpdatedDailyNote ? 1.0 : 0.0,
                rewardText: '+5 แต้ม',
                rewardScore: 5,
                isCompleted: qNewsCompleted,
                isClaimed: qNewsClaimed,
                onClaim: () => _claimQuestReward('q_news', 5),
              ),
              _buildQuestCard(
                title: '🎰 นักเสี่ยงดวงประจำวัน',
                subtitle: 'หมุนวงล้อ Lucky Wheel อย่างน้อย 1 ครั้ง ($wheelSpinCount/1)',
                progress: min(1.0, wheelSpinCount / 1.0),
                rewardText: '+5 แต้ม',
                rewardScore: 5,
                isCompleted: qSpinCompleted,
                isClaimed: qSpinClaimed,
                onClaim: () => _claimQuestReward('q_spin', 5),
              ),
              _buildQuestCard(
                title: '💬 ทักทายเพื่อนร่วมงาน',
                subtitle: hasChattedToday ? 'ส่งข้อความทักทายในแชททีมแล้ว' : 'พิมพ์ข้อความในห้องแชททีม 1 ครั้งในวันนั้น',
                progress: hasChattedToday ? 1.0 : 0.0,
                rewardText: '+5 แต้ม',
                rewardScore: 5,
                isCompleted: qChatCompleted,
                isClaimed: qChatClaimed,
                onClaim: () => _claimQuestReward('q_chat', 5),
              ),
              _buildQuestCard(
                title: '⚡ พนักงานขยันขันแข็ง',
                subtitle: 'อัปเดตสถานะโต๊ะในร้าน ($tableUpdates/30)',
                progress: min(1.0, tableUpdates / 30.0),
                rewardText: '+10 แต้ม',
                rewardScore: 10,
                isCompleted: q1Completed,
                isClaimed: q1Claimed,
                onClaim: () => _claimQuestReward('q1', 10),
              ),
              _buildQuestCard(
                title: '💖 มิตรภาพกว้างไกล',
                subtitle: 'ส่งหัวใจให้เพื่อนไม่ซ้ำคน (${heartSentUsers.length}/5)',
                progress: min(1.0, heartSentUsers.length / 5.0),
                rewardText: '+5 แต้ม',
                rewardScore: 5,
                isCompleted: q2Completed,
                isClaimed: q2Claimed,
                onClaim: () => _claimQuestReward('q2', 5),
              ),
              _buildQuestCard(
                title: '💌 ส่งรักรัวๆ',
                subtitle: 'ส่งหัวใจรวมทั้งหมดในวันนี้ ($heartSentTotal/20)',
                progress: min(1.0, heartSentTotal / 20.0),
                rewardText: '+5 แต้ม',
                rewardScore: 5,
                isCompleted: q3Completed,
                isClaimed: q3Claimed,
                onClaim: () => _claimQuestReward('q3', 5),
              ),
              _buildQuestCard(
                title: '🏆 ราชาเปิดร้าน',
                subtitle: isFirstCheckIn ? 'คุณคือคนแรกที่เช็กชื่อวันนี้!' : 'มีเพื่อนเช็กชื่อคนแรกไปแล้วหรือยังไม่ได้เปิดกล่องสุ่ม',
                progress: isFirstCheckIn ? 1.0 : 0.0,
                rewardText: '+10 แต้ม',
                rewardScore: 10,
                isCompleted: q4Completed,
                isClaimed: q4Claimed,
                onClaim: () => _claimQuestReward('q4', 10),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestCard({
    required String title,
    required String subtitle,
    required double progress,
    required String rewardText,
    required int rewardScore,
    required bool isCompleted,
    required bool isClaimed,
    required VoidCallback onClaim,
    bool isHighlight = false,
  }) {
    return Card(
      elevation: isHighlight ? 4 : 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isHighlight ? Colors.amber[50] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHighlight ? Colors.amber[600]! : Colors.transparent,
          width: isHighlight ? 1.5 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(8)),
                  child: Text(rewardText, style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : Colors.blue[900]!),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: isClaimed
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      child: const Text('รับแล้ว ✅', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted ? Colors.amber[800] : Colors.grey[300],
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: const Size(80, 32),
                      ),
                      onPressed: isCompleted ? onClaim : null,
                      child: Text(
                        'รับรางวัล',
                        style: TextStyle(color: isCompleted ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TableStatusScreen
// ==========================================
class TableStatusScreen extends StatefulWidget {
  final VoidCallback onEditProfile;

  const TableStatusScreen({super.key, required this.onEditProfile});

  @override
  State<TableStatusScreen> createState() => _TableStatusScreenState();
}

class _TableStatusScreenState extends State<TableStatusScreen> {
  final List<String> _collections = const ['tables_f1', 'tables_f2', 'tables_f3'];
  final List<String> _menuTitles = const ['ชั้น 1', 'ชั้น 2', 'ชั้น 3'];

  bool _onlyAvailable = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _showEditDailyNoteDialog(BuildContext context, String currentNote) {
    final noteCtrl = TextEditingController(text: currentNote);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.push_pin, color: Colors.amber),
              SizedBox(width: 8),
              Text('แก้ไขประกาศประจำวัน 📌', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: TextField(
            controller: noteCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'พิมพ์ข้อความประกาศ เช่น วันนี้มีจองห้อง VIP 20:00 น. หรือเบียร์โปรโมชั่น...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
              onPressed: () async {
                final text = noteCtrl.text.trim();
                final String userDisplayName = globalUserTitle.isNotEmpty 
                    ? '$globalUserName [$globalUserTitle]' 
                    : globalUserName;

                await FirebaseFirestore.instance.collection('app_settings').doc('daily_note').set({
                  'message': text,
                  'updatedBy': userDisplayName,
                  'updatedAt': Timestamp.now(),
                });

                await recordCustomDailyQuest('hasUpdatedDailyNote', true);

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('บันทึกประกาศ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showBatchStatusDialog(int activeIndex) {
    final collectionName = _collections[activeIndex];
    final floorName = _menuTitles[activeIndex];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cleaning_services, color: Colors.blue),
              SizedBox(width: 8),
              Text('เปลี่ยนสถานะทุกโต๊ะ ($floorName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'กรุณาเลือกสถานะที่ต้องการปรับใช้กับทุกโต๊ะในชั้นนี้พร้อมกัน:',
            style: TextStyle(fontSize: 15),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
              label: const Text('ว่างทั้งหมด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _executeBatchStatusUpdate(collectionName, floorName, true);
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
              label: const Text('ไม่ว่างทั้งหมด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _executeBatchStatusUpdate(collectionName, floorName, false);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeBatchStatusUpdate(String collectionName, String floorName, bool targetStatus) async {
    final collectionRef = FirebaseFirestore.instance.collection(collectionName);

    try {
      final snapshot = await collectionRef.get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      final String userDisplayName = globalUserTitle.isNotEmpty 
          ? '$globalUserName [$globalUserTitle]' 
          : globalUserName;

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isAvailable': targetStatus,
          'lastUpdated': now,
          'updatedBy': userDisplayName,
        });
      }

      await batch.commit();
      if (mounted) {
        await registerUserUpdateAction(context, collectionName: collectionName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: targetStatus ? Colors.green[800] : Colors.red[800],
            content: Text('เปลี่ยนทุกโต๊ะใน $floorName เป็น "${targetStatus ? 'ว่างทั้งหมด' : 'ไม่ว่างทั้งหมด'}" เรียบร้อยแล้ว'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการปรับสถานะโต๊ะ')),
        );
      }
    }
  }

  void _showAvailableTablesBottomSheet(int activeIndex) {
    final collectionName = _collections[activeIndex];
    final collectionRef = FirebaseFirestore.instance.collection(collectionName);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: collectionRef.where('isAvailable', isEqualTo: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาด'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_available, color: Colors.green, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'โต๊ะที่ว่าง (${_menuTitles[activeIndex]})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          'ว่าง ${docs.length} โต๊ะ',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('ไม่มีโต๊ะว่างในขณะนี้ (เต็มทุกโต๊ะ)', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final name = data['name'] ?? 'Unknown';
                          final updatedBy = data['updatedBy'] ?? 'ไม่ทราบชื่อ';

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.green[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.green[300]!),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.green,
                                child: Icon(Icons.check, color: Colors.white, size: 16),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Text('อัปเดตโดย: $updatedBy', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateAllTablesCurrentTime(int activeIndex) async {
    final collectionName = _collections[activeIndex];
    final collectionRef = FirebaseFirestore.instance.collection(collectionName);

    try {
      final snapshot = await collectionRef.get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      final String userDisplayName = globalUserTitle.isNotEmpty 
          ? '$globalUserName [$globalUserTitle]' 
          : globalUserName;

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'lastUpdated': now,
          'updatedBy': userDisplayName,
        });
      }

      await batch.commit();
      if (mounted) {
        await registerUserUpdateAction(context, collectionName: collectionName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blue[900],
            content: Text('⚡ อัปเดตเวลาเช็คสถานะทุกโต๊ะใน ${_menuTitles[activeIndex]} แล้ว'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปเดตข้อมูล')),
        );
      }
    }
  }

  void _showAddTableDialog(BuildContext context, int activeIndex) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('เพิ่มโต๊ะใหม่ (${_menuTitles[activeIndex]})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'พิมพ์ชื่อโต๊ะ', border: OutlineInputBorder()),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
              onPressed: () async {
                final String tableName = nameController.text.trim();
                if (tableName.isNotEmpty) {
                  final String userDisplayName = globalUserTitle.isNotEmpty 
                      ? '$globalUserName [$globalUserTitle]' 
                      : globalUserName;

                  await FirebaseFirestore.instance.collection(_collections[activeIndex]).add({
                    'name': tableName,
                    'isAvailable': true,
                    'lastUpdated': Timestamp.now(),
                    'updatedBy': userDisplayName,
                    'waitingQueue': [],
                  });
                  if (context.mounted) {
                    await registerUserUpdateAction(context, collectionName: _collections[activeIndex]);
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('บันทึก', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? globalUserId;

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (tabContext) {
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
                    builder: (context, snapshot) {
                      int curLevel = globalUserLevel;
                      int curClicks = globalUserUpdateCount;
                      int curScore = globalUserScore;
                      int curHearts = globalUserHearts;
                      bool isBuff = globalBuffX2Until != null && globalBuffX2Until!.toDate().isAfter(DateTime.now());

                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                        final d = snapshot.data!.data() as Map<String, dynamic>;
                        curLevel = (d['level'] is num) ? (d['level'] as num).toInt() : curLevel;
                        curClicks = (d['updateCount'] is num) ? (d['updateCount'] as num).toInt() : curClicks;
                        curScore = (d['score'] is num) ? (d['score'] as num).toInt() : curScore;
                        curHearts = (d['hearts'] is num) ? (d['hearts'] as num).toInt() : curHearts;
                        final Timestamp? buffTs = d['buffX2Until'];
                        isBuff = buffTs != null && buffTs.toDate().isAfter(DateTime.now());
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text('StarSister Tables', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              if (isBuff) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('🔥 x2', style: TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Lv.$curLevel ($curClicks/100) • $curScore แต้ม • ❤️ $curHearts',
                            style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('app_settings').doc('daily_note').snapshots(),
                      builder: (context, snapshot) {
                        String message = 'ไม่มีประกาศ';
                        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          message = data['message'] ?? message;
                          if (message.isEmpty) message = 'ไม่มีประกาศ';
                        }

                        return GestureDetector(
                          onTap: () => _showEditDailyNoteDialog(context, message == 'ไม่มีประกาศ' ? '' : message),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withOpacity(0.5), width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Text('📌', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    message,
                                    style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.event_available, size: 24),
                  tooltip: 'ดูรายการโต๊ะว่าง',
                  onPressed: () {
                    final currentTab = DefaultTabController.of(tabContext).index;
                    _showAvailableTablesBottomSheet(currentTab);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services, size: 24),
                  tooltip: 'เปลี่ยนสถานะทุกโต๊ะพร้อมกัน',
                  onPressed: () {
                    final currentTab = DefaultTabController.of(tabContext).index;
                    _showBatchStatusDialog(currentTab);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.sync, size: 24),
                  tooltip: 'อัปเดตเวลาทุกโต๊ะตอนนี้ (สถานะเดิม)',
                  onPressed: () {
                    final currentTab = DefaultTabController.of(tabContext).index;
                    _updateAllTablesCurrentTime(currentTab);
                  },
                ),
              ],
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'ชั้น 1'),
                  Tab(text: 'ชั้น 2'),
                  Tab(text: 'ชั้น 3'),
                ],
              ),
            ),
            drawer: Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
                    builder: (context, snapshot) {
                      String avatar = globalUserAvatar;
                      String title = globalUserTitle;
                      String frame = globalUserFrame;
                      String name = globalUserName;
                      int curLevel = globalUserLevel;
                      int curClicks = globalUserUpdateCount;
                      int curScore = globalUserScore;
                      int curHearts = globalUserHearts;

                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                        final d = snapshot.data!.data() as Map<String, dynamic>;
                        avatar = d['avatar'] ?? '🐱';
                        title = d['title'] ?? '';
                        frame = d['frame'] ?? '';
                        name = d['name'] ?? 'Staff';
                        curLevel = (d['level'] is num) ? (d['level'] as num).toInt() : curLevel;
                        curClicks = (d['updateCount'] is num) ? (d['updateCount'] as num).toInt() : curClicks;
                        curScore = (d['score'] is num) ? (d['score'] as num).toInt() : curScore;
                        curHearts = (d['hearts'] is num) ? (d['hearts'] as num).toInt() : curHearts;
                      }

                      final String displayName = title.isNotEmpty ? '$name\n[$title]' : name;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
                        color: Colors.blue[900],
                        child: Column(
                          children: [
                            buildUserAvatarWidget(avatar, radius: 36, fontSize: 36, frame: frame),
                            const SizedBox(height: 8),
                            Text(
                              'สวัสดี, $displayName', 
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('เลเวล $curLevel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('$curScore แต้ม (❤️ $curHearts)', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: curClicks / 100.0,
                                      minHeight: 6,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'อัปเดตอีก ${100 - curClicks} ครั้งเพื่อ Lv. Up (+50 แต้ม)',
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white70),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onEditProfile();
                                  },
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text('แก้ไขโปรไฟล์', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red[200],
                                    side: BorderSide(color: Colors.red[200]!),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await FirebaseAuth.instance.signOut();
                                  },
                                  icon: const Icon(Icons.logout, size: 14),
                                  label: const Text('ออก', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
                    title: const Text('ภารกิจ & กล่องสุ่มประจำวัน 🎁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('เปิดกล่องสุ่ม 10-60 แต้ม & สะสม Streak'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DailyQuestsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('app_settings').doc('daily_note').snapshots(),
                    builder: (context, snapshot) {
                      String message = 'ยังไม่มีประกาศสำคัญประจำวันนี้';
                      String updatedBy = '';
                      String timeStr = '';

                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        message = data['message'] ?? message;
                        if (message.isEmpty) message = 'ยังไม่มีประกาศสำคัญประจำวันนี้';
                        updatedBy = data['updatedBy'] ?? '';
                        final Timestamp? ts = data['updatedAt'];
                        if (ts != null) {
                          final dt = ts.toDate();
                          final h = dt.hour.toString().padLeft(2, '0');
                          final m = dt.minute.toString().padLeft(2, '0');
                          timeStr = '$h:$m น.';
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Card(
                          elevation: 2,
                          color: Colors.amber[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.amber[400]!, width: 1.2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.push_pin, color: Colors.amber[900], size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          'ประกาศสำคัญประจำวัน',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber[900]),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 22),
                                      color: Colors.blue[900],
                                      tooltip: 'แก้ไขประกาศ',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditDailyNoteDialog(context, message == 'ยังไม่มีประกาศสำคัญประจำวันนี้' ? '' : message),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                                ),
                                if (updatedBy.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'โดย: $updatedBy ($timeStr)',
                                    style: TextStyle(fontSize: 10, color: Colors.grey[700], fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'ค้นหาชื่อโต๊ะ...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('แสดงเฉพาะโต๊ะว่าง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          value: _onlyAvailable,
                          activeColor: Colors.blue[900],
                          onChanged: (val) {
                            setState(() {
                              _onlyAvailable = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  const Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('ระบบจัดการผังโต๊ะ StarSister Tables', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                TableGrid(
                  collectionName: 'tables_f1',
                  onlyAvailable: _onlyAvailable,
                  searchQuery: _searchQuery,
                ),
                TableGrid(
                  collectionName: 'tables_f2',
                  onlyAvailable: _onlyAvailable,
                  searchQuery: _searchQuery,
                ),
                TableGrid(
                  collectionName: 'tables_f3',
                  onlyAvailable: _onlyAvailable,
                  searchQuery: _searchQuery,
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                final int currentTabIndex = DefaultTabController.of(tabContext).index;
                _showAddTableDialog(context, currentTabIndex);
              },
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
              child: const Icon(Icons.add, size: 28),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// TableGrid
// ==========================================
class TableGrid extends StatelessWidget {
  final String collectionName;
  final bool onlyAvailable;
  final String searchQuery;

  const TableGrid({
    super.key,
    required this.collectionName,
    this.onlyAvailable = false,
    this.searchQuery = '',
  });

  void _showDeleteDialog(BuildContext context, String docId, String tableName, CollectionReference ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('ลบ "$tableName" ?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: const Text('คุณต้องการลบโต๊ะนี้ออกจากระบบใช่หรือไม่?', style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await ref.doc(docId).delete();
                  if (context.mounted) {
                    await registerUserUpdateAction(context, collectionName: collectionName);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint('Delete error: $e');
                }
              },
              child: const Text('ลบโต๊ะ', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CollectionReference tablesRef = FirebaseFirestore.instance.collection(collectionName);

    return StreamBuilder<QuerySnapshot>(
      stream: tablesRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        DateTime? latestTime;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['lastUpdated'] != null) {
            final Timestamp ts = data['lastUpdated'];
            final DateTime docTime = ts.toDate();
            if (latestTime == null || docTime.isAfter(latestTime)) {
              latestTime = docTime;
            }
          }
        }
        final DateTime lastUpdateTime = latestTime ?? DateTime.now();

        Widget content;
        if (collectionName == 'tables_f1') {
          content = CustomFloorPlanF1(
            docs: docs,
            collectionName: collectionName,
            onlyAvailable: onlyAvailable,
            searchQuery: searchQuery,
            onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef),
          );
        } else if (collectionName == 'tables_f2') {
          content = CustomFloorPlanF2(
            docs: docs,
            collectionName: collectionName,
            onlyAvailable: onlyAvailable,
            searchQuery: searchQuery,
            onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef),
          );
        } else if (collectionName == 'tables_f3') {
          content = CustomFloorPlanF3(
            docs: docs,
            collectionName: collectionName,
            onlyAvailable: onlyAvailable,
            searchQuery: searchQuery,
            onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef),
          );
        } else {
          content = const Center(child: Text('ไม่มีข้อมูลแผนผัง'));
        }

        return Stack(
          children: [
            content,
            Positioned(bottom: 12, left: 12, child: LastUpdateWidget(updateTime: lastUpdateTime)),
          ],
        );
      },
    );
  }
}
// ==========================================
// FloorPlanCard
// ==========================================
class FloorPlanCard extends StatefulWidget {
  final String expectedName;
  final bool isCircle;
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final bool onlyAvailable;
  final String searchQuery;
  final Function(String docId, String name) onDelete;

  const FloorPlanCard({
    super.key,
    required this.expectedName,
    this.isCircle = false,
    required this.docs,
    required this.collectionName,
    this.onlyAvailable = false,
    this.searchQuery = '',
    required this.onDelete,
  });

  @override
  State<FloorPlanCard> createState() => _FloorPlanCardState();
}

class _FloorPlanCardState extends State<FloorPlanCard> {
  bool _isToggling = false;

  bool get _isMergeableTable {
    return widget.collectionName == 'tables_f1' &&
        (widget.expectedName == 'โต๊ะ 1' ||
            widget.expectedName == 'โต๊ะ 2' ||
            widget.expectedName == 'โต๊ะ 3' ||
            widget.expectedName == 'โต๊ะ 4' ||
            widget.expectedName == 'โต๊ะ 5');
  }

  bool get _hasQueueSystem {
    return widget.expectedName.contains('พูล') || widget.expectedName == 'ห้องกระจก';
  }

  void _showMergeDialog(BuildContext context, String currentDocId, String currentName) {
    const mergeableNames = ['โต๊ะ 1', 'โต๊ะ 2', 'โต๊ะ 3', 'โต๊ะ 4', 'โต๊ะ 5'];
    
    final otherAvailableTables = <Map<String, dynamic>>[];
    for (var doc in widget.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String? ?? '';
      if (mergeableNames.contains(name) && name != currentName && data['mergedGroupId'] == null) {
        otherAvailableTables.add({'docId': doc.id, 'name': name});
      }
    }

    final selectedDocIds = <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.link, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('รวมโต๊ะกับ $currentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เลือกโต๊ะที่ต้องการนำมารวมกัน:', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    if (otherAvailableTables.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('ไม่มีโต๊ะ 1-5 อื่นที่พร้อมรวมในขณะนี้', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...otherAvailableTables.map((tbl) {
                        final docId = tbl['docId'] as String;
                        final name = tbl['name'] as String;
                        final isChecked = selectedDocIds.contains(docId);

                        return CheckboxListTile(
                          dense: true,
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          value: isChecked,
                          activeColor: Colors.blue[900],
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedDocIds.add(docId);
                              } else {
                                selectedDocIds.remove(docId);
                              }
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  onPressed: selectedDocIds.isEmpty
                      ? null
                      : () async {
                          final batch = FirebaseFirestore.instance.batch();
                          final newGroupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
                          final allNamesInGroup = [currentName];

                          for (var tbl in otherAvailableTables) {
                            if (selectedDocIds.contains(tbl['docId'])) {
                              allNamesInGroup.add(tbl['name'] as String);
                            }
                          }

                          allNamesInGroup.sort();
                          final now = Timestamp.now();
                          final String userDisplayName = globalUserTitle.isNotEmpty 
                              ? '$globalUserName [$globalUserTitle]' 
                              : globalUserName;

                          batch.update(
                            FirebaseFirestore.instance.collection(widget.collectionName).doc(currentDocId),
                            {
                              'mergedGroupId': newGroupId,
                              'mergedWith': allNamesInGroup,
                              'isAvailable': false,
                              'lastUpdated': now,
                              'updatedBy': userDisplayName,
                            },
                          );

                          for (var docId in selectedDocIds) {
                            batch.update(
                              FirebaseFirestore.instance.collection(widget.collectionName).doc(docId),
                              {
                                'mergedGroupId': newGroupId,
                                'mergedWith': allNamesInGroup,
                                'isAvailable': false,
                                'lastUpdated': now,
                                'updatedBy': userDisplayName,
                              },
                            );
                          }

                          await batch.commit();
                          if (context.mounted) {
                            await registerUserUpdateAction(context, collectionName: widget.collectionName);
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: const Text('ยืนยันการรวมโต๊ะ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _unmergeTables(BuildContext context, String mergedGroupId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .where('mergedGroupId', isEqualTo: mergedGroupId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      final String userDisplayName = globalUserTitle.isNotEmpty 
          ? '$globalUserName [$globalUserTitle]' 
          : globalUserName;

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'mergedGroupId': FieldValue.delete(),
          'mergedWith': FieldValue.delete(),
          'isAvailable': true,
          'lastUpdated': now,
          'updatedBy': userDisplayName,
        });
      }

      await batch.commit();
      if (context.mounted) {
        await registerUserUpdateAction(context, collectionName: widget.collectionName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✂️ แยกโต๊ะเรียบร้อยแล้ว'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      debugPrint('Unmerge error: $e');
    }
  }

  Future<void> _toggleMergedGroupAvailability(BuildContext context, String mergedGroupId, bool currentStatus) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .where('mergedGroupId', isEqualTo: mergedGroupId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      final String userDisplayName = globalUserTitle.isNotEmpty 
          ? '$globalUserName [$globalUserTitle]' 
          : globalUserName;

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isAvailable': !currentStatus,
          'lastUpdated': now,
          'updatedBy': userDisplayName,
        });
      }

      await batch.commit();
      if (context.mounted) await registerUserUpdateAction(context, collectionName: widget.collectionName);
    } catch (e) {
      debugPrint('Toggle error: $e');
    }
  }

  void _showTableOptionsBottomSheet(BuildContext context, String docId, String tableName, String? mergedGroupId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('จัดการ "$tableName"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              if (mergedGroupId != null)
                ListTile(
                  leading: const Icon(Icons.link_off, color: Colors.orange, size: 26),
                  title: const Text('แยกโต๊ะออกจากกลุ่ม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: const Text('ยกเลิกการรวมกลุ่มและเปลี่ยนเป็นโต๊ะเดี่ยว'),
                  onTap: () {
                    Navigator.pop(context);
                    _unmergeTables(context, mergedGroupId);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue, size: 26),
                  title: const Text('รวมโต๊ะกับโต๊ะอื่น', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: const Text('เชื่อมต่อกับโต๊ะ 1-5 อื่นๆ ในชั้น 1'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMergeDialog(context, docId, tableName);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red, size: 26),
                title: const Text('ลบโต๊ะออกจากระบบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete(docId, tableName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQueueDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final List<dynamic> queueList = (data['waitingQueue'] is List) ? List.from(data['waitingQueue']) : [];
    final nameCtrl = TextEditingController();
    final countCtrl = TextEditingController();
    final bool isGlassRoom = widget.expectedName == 'ห้องกระจก';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isGlassRoom ? Icons.meeting_room : Icons.sports_esports,
                    color: Colors.amber[800],
                  ),
                  const SizedBox(width: 8),
                  Text('คิวรอใช้งาน: ${widget.expectedName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('➕ เพิ่มชื่อคนรอต่อคิว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อผู้รอ / โน้ต',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: countCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'จำนวนคน',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                                onPressed: () async {
                                  final name = nameCtrl.text.trim();
                                  final count = int.tryParse(countCtrl.text.trim()) ?? 0;
                                  if (name.isNotEmpty) {
                                    final newItem = {'name': name, 'count': count};
                                    setDialogState(() {
                                      queueList.add(newItem);
                                      nameCtrl.clear();
                                      countCtrl.clear();
                                    });

                                    await FirebaseFirestore.instance.collection(widget.collectionName).doc(docId).update({
                                      'waitingQueue': queueList,
                                      'lastUpdated': Timestamp.now(),
                                    });
                                    if (context.mounted) await registerUserUpdateAction(context, collectionName: widget.collectionName);
                                  }
                                },
                                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                                label: const Text('ลงชื่อต่อคิว', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('📋 รายชื่อคิวรอขณะนี้', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('${queueList.length} คิว', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (queueList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: Text('ไม่มีคิวรอ สามารถเข้าใช้งานได้เลย', style: TextStyle(color: Colors.grey, fontSize: 14))),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: queueList.length,
                          itemBuilder: (context, index) {
                            final item = queueList[index] as Map<String, dynamic>;
                            final qName = item['name'] ?? '-';
                            final qCount = item['count'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 1,
                              color: index == 0 ? Colors.amber[50] : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: index == 0 ? Colors.amber : Colors.grey[300]!),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: index == 0 ? Colors.amber[800] : Colors.blue[900],
                                  child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(qName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('$qCount คน', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                                  tooltip: 'เสร็จสิ้น / ลบคิวนี้',
                                  onPressed: () async {
                                    setDialogState(() {
                                      queueList.removeAt(index);
                                    });

                                    await FirebaseFirestore.instance.collection(widget.collectionName).doc(docId).update({
                                      'waitingQueue': queueList,
                                      'lastUpdated': Timestamp.now(),
                                    });
                                    if (context.mounted) await registerUserUpdateAction(context, collectionName: widget.collectionName);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    QueryDocumentSnapshot? targetDoc;
    for (var doc in widget.docs) {
      if ((doc.data() as Map<String, dynamic>)['name'] == widget.expectedName) {
        targetDoc = doc;
        break;
      }
    }

    final String userDisplayName = globalUserTitle.isNotEmpty 
        ? '$globalUserName [$globalUserTitle]' 
        : globalUserName;

    if (targetDoc == null) {
      return Card(
        color: Colors.grey[100],
        elevation: 0,
        shape: widget.isCircle
            ? const CircleBorder(side: BorderSide(color: Colors.grey, width: 2, style: BorderStyle.solid))
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.grey, width: 2)),
        child: InkWell(
          customBorder: widget.isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: _isToggling
              ? null
              : () async {
                  setState(() => _isToggling = true);
                  try {
                    await registerUserUpdateAction(context, collectionName: widget.collectionName);
                    await FirebaseFirestore.instance.collection(widget.collectionName).add({
                      'name': widget.expectedName,
                      'isAvailable': true,
                      'lastUpdated': Timestamp.now(),
                      'updatedBy': userDisplayName,
                      'waitingQueue': [],
                    });
                  } finally {
                    if (mounted) setState(() => _isToggling = false);
                  }
                },
          child: Center(
            child: Text('${widget.expectedName}\n(แตะเพื่อสร้าง)', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
        ),
      );
    }

    final data = targetDoc.data() as Map<String, dynamic>;
    final String docId = targetDoc.id;
    final bool isAvailable = data['isAvailable'] ?? true;
    final String updatedBy = data['updatedBy'] ?? 'ไม่ทราบชื่อ';
    final String? mergedGroupId = data['mergedGroupId'];
    final List<dynamic>? mergedWith = data['mergedWith'];
    final List<dynamic> queueList = (data['waitingQueue'] is List) ? List.from(data['waitingQueue']) : [];
    final Timestamp? ts = data['lastUpdated'];

    if (widget.onlyAvailable && !isAvailable) {
      return Opacity(
        opacity: 0.25,
        child: Card(
          color: Colors.grey[200],
          shape: widget.isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(widget.expectedName, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        ),
      );
    }

    if (widget.searchQuery.isNotEmpty && !widget.expectedName.toLowerCase().contains(widget.searchQuery.toLowerCase())) {
      return Opacity(
        opacity: 0.2,
        child: Card(
          color: Colors.grey[200],
          shape: widget.isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(widget.expectedName, style: const TextStyle(color: Colors.grey))),
        ),
      );
    }

    String timeStr = '';
    if (ts != null) {
      final dt = ts.toDate();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      timeStr = ' ($h:$m น.)';
    }

    return Card(
      elevation: mergedGroupId != null ? 6 : 4,
      color: isAvailable ? Colors.green[50] : Colors.red[50],
      shape: widget.isCircle
          ? CircleBorder(side: BorderSide(color: isAvailable ? Colors.green : Colors.red, width: 2))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: mergedGroupId != null ? Colors.blue[900]! : (isAvailable ? Colors.green : Colors.red),
                width: mergedGroupId != null ? 2.5 : 2,
              ),
            ),
      child: InkWell(
        customBorder: widget.isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: _isToggling
            ? null
            : () async {
                setState(() => _isToggling = true);
                try {
                  if (mergedGroupId != null) {
                    await _toggleMergedGroupAvailability(context, mergedGroupId, isAvailable);
                  } else {
                    await FirebaseFirestore.instance.collection(widget.collectionName).doc(docId).update({
                      'isAvailable': !isAvailable,
                      'lastUpdated': Timestamp.now(),
                      'updatedBy': userDisplayName,
                    });
                    if (context.mounted) await registerUserUpdateAction(context, collectionName: widget.collectionName);
                  }
                } finally {
                  if (mounted) setState(() => _isToggling = false);
                }
              },
        onLongPress: () {
          if (_isMergeableTable) {
            _showTableOptionsBottomSheet(context, docId, widget.expectedName, mergedGroupId);
          } else {
            widget.onDelete(docId, widget.expectedName);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.isCircle ? 16.0 : 8.0, vertical: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.expectedName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isAvailable ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          isAvailable ? 'ว่าง' : 'ไม่ว่าง',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (mergedGroupId != null && mergedWith != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.blue[900],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🔗 ${mergedWith.join("+")}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    'โดย: $updatedBy$timeStr',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[800], fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            if (_hasQueueSystem)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showQueueDialog(context, docId, data),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: queueList.isNotEmpty ? Colors.amber[800] : Colors.blue[900],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            queueList.isNotEmpty ? Icons.people : Icons.person_add_alt_1,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            queueList.isNotEmpty ? '${queueList.length} คิว' : '+คิว',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildDoor(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.blue[900]!, width: 3))),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
  );
}

class CustomFloorPlanF1 extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final bool onlyAvailable;
  final String searchQuery;
  final Function(String, String) onDelete;

  const CustomFloorPlanF1({
    super.key,
    required this.docs,
    required this.collectionName,
    this.onlyAvailable = false,
    this.searchQuery = '',
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 80, left: 16, right: 16), 
      children: [
        Align(alignment: Alignment.center, child: _buildDoor('ประตูร้าน')),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 120, child: FloorPlanCard(expectedName: 'Nintendo 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 120, child: FloorPlanCard(expectedName: 'Nintendo 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240, 
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue[900]!, width: 2),
                      ),
                      child: const Center(
                        child: Text('บาร์น้ำ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(height: 120, child: FloorPlanCard(expectedName: 'เหลี่ยมขาว', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 140, child: FloorPlanCard(expectedName: 'ห้องกระจก', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                ],
              ),
            ),
            const Expanded(flex: 1, child: SizedBox()), 
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'โต๊ะ 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'โต๊ะ 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'โต๊ะ 3', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'โต๊ะ 4', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'โต๊ะ 5', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CustomFloorPlanF2 extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final bool onlyAvailable;
  final String searchQuery;
  final Function(String, String) onDelete;

  const CustomFloorPlanF2({
    super.key,
    required this.docs,
    required this.collectionName,
    this.onlyAvailable = false,
    this.searchQuery = '',
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 80, left: 40, right: 40),
      children: [
        SizedBox(height: 160, child: FloorPlanCard(expectedName: 'ห้อง VIP', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 150, child: FloorPlanCard(expectedName: 'กลมขาว 1', isCircle: true, docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 150, child: FloorPlanCard(expectedName: 'กลมขาว 2', isCircle: true, docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'เหลี่ยมดำ', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'ข้างห้องกระจก', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 160, child: FloorPlanCard(expectedName: 'ห้องกระจก', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 16),
        Align(alignment: Alignment.bottomRight, child: _buildDoor('ประตู')),
      ],
    );
  }
}

class CustomFloorPlanF3 extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final bool onlyAvailable;
  final String searchQuery;
  final Function(String, String) onDelete;

  const CustomFloorPlanF3({
    super.key,
    required this.docs,
    required this.collectionName,
    this.onlyAvailable = false,
    this.searchQuery = '',
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 80, left: 24, right: 24),
      children: [
        const Text('โซนพูล', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)), 
        const SizedBox(height: 16),
        SizedBox(height: 140, child: FloorPlanCard(expectedName: 'พูล 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 16),
        SizedBox(height: 140, child: FloorPlanCard(expectedName: 'พูล 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 24),
        Align(alignment: Alignment.center, child: _buildDoor('ทีวี')),
        const SizedBox(height: 32),
        const Divider(thickness: 2), 
        const SizedBox(height: 24),
        const Text('โซนในห้อง', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)), 
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.15,
          children: [
            FloorPlanCard(expectedName: 'ในห้อง 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 3', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 4', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
          ],
        ),
        const SizedBox(height: 24),
        Align(alignment: Alignment.center, child: _buildDoor('ประตูห้อง')),
      ],
    );
  }
}

class LastUpdateWidget extends StatelessWidget {
  final DateTime updateTime;
  const LastUpdateWidget({super.key, required this.updateTime});

  @override
  Widget build(BuildContext context) {
    final h = updateTime.hour.toString().padLeft(2, '0');
    final m = updateTime.minute.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Text(
        'อัปเดตล่าสุด: $h:$m น.',
        style: TextStyle(color: Colors.blue[900], fontSize: 16, fontWeight: FontWeight.bold), 
      ),
    );
  }
}

// ==========================================
// Lucky Wheel Dialog (แก้ปัญหา Overflow ด้วย Wrap)
// ==========================================
class LuckyWheelDialog extends StatefulWidget {
  final int currentScore;
  const LuckyWheelDialog({super.key, required this.currentScore});

  @override
  State<LuckyWheelDialog> createState() => _LuckyWheelDialogState();
}

class _WheelReward {
  final String label;
  final String shortText;
  final Color color;
  final String type;
  final dynamic value;

  const _WheelReward(this.label, this.shortText, this.color, this.type, this.value);
}

class _LuckyWheelDialogState extends State<LuckyWheelDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  double _currentAngle = 0.0;
  String? _resultText;
  int _selectedWheelIndex = 0;

  final List<_WheelReward> standardRewards = const [
    _WheelReward('JACKPOT +500 แต้ม! 💥', '+500 💥', Color(0xFFFF1493), 'jackpot', 500),
    _WheelReward('🏆 สุ่มกรอบโปรไฟล์ (เงิน/ลม/มืด/Challenger)', 'สุ่มกรอบ 🖼️', Colors.deepPurple, 'sub_frame_random_normal', null),
    _WheelReward('โล่กันแต้มลด 🛡️', 'โล่ 🛡️', Colors.blueAccent, 'shield', 1),
    _WheelReward('👑 ฉายา: "ไร้พ่าย No.1"', 'ไร้พ่าย 👑', Colors.amber, 'fixed_title', 'ไร้พ่าย No.1'),
    _WheelReward('ฉายา: "Tryhard ตัวจริง"', 'Tryhard 🎯', Colors.purpleAccent, 'fixed_title', 'Tryhard ตัวจริง'),
    _WheelReward('ฉายา: "นักไต่แรงก์"', 'ไต่แรงก์ ⚔️', Colors.indigoAccent, 'fixed_title', 'นักไต่แรงก์'),
    _WheelReward('บัฟแต้ม x2 (30 นาที) 🔥', 'บัฟ x2', Colors.deepOrange, 'buff', 30),
    _WheelReward('ตั๋วหมุนฟรี 🎟️', 'หมุนฟรี 🎟️', Colors.teal, 'free_spin', 20),
    _WheelReward('โบนัส +100 แต้ม ✨', '+100 ✨', Colors.amber, 'bonus', 100),
    _WheelReward('โบนัส +20 แต้ม 🌟', '+20 🌟', Colors.orangeAccent, 'bonus', 20),
    _WheelReward('โบนัส +10 แต้ม 🌟', '+10 🌟', Colors.amberAccent, 'bonus', 10),
    _WheelReward('เกลือ 🧂', 'เกลือ 🧂', Colors.grey, 'salt', 0),
    _WheelReward('แย่แล้ว! -2 แต้ม 🔻', '-2 🔻', Color(0xFFEF5350), 'penalty', -2),
    _WheelReward('แย่แล้ว! -6 แต้ม 🔻', '-6 🔻', Color(0xFFE53935), 'penalty', -6),
    _WheelReward('กุญแจกล่องสุ่ม (50-200 แต้ม) 🎁', 'กล่องสุ่ม 🎁', Color(0xFF9C27B0), 'mystery_key', null),
  ];

  final List<_WheelReward> premiumRewards = const [
    _WheelReward('SUPER JACKPOT +2,000 แต้ม! 🌟', '+2000 🌟', Color(0xFFFFD700), 'jackpot', 2000),
    _WheelReward('🪽 กรอบโปรไฟล์: "ปีกแห่งแสง"', 'กรอบปีก 🪽', Colors.amberAccent, 'vip_frame', 'wing'),
    _WheelReward('🔮 กรอบโปรไฟล์: "ออร่าจักรวาล"', 'กรอบออร่า 🔮', Colors.deepPurpleAccent, 'vip_frame', 'aura'),
    _WheelReward('✨ กรอบโปรไฟล์: "วิ้งๆ ประกายเพชร"', 'กรอบวิ้ง ✨', Colors.pinkAccent, 'vip_frame', 'sparkle'),
    _WheelReward('👑 ฉายา: "มหาเศรษฐีตัวจริง"', 'เศรษฐี 💰', Colors.amber, 'fixed_title', 'มหาเศรษฐีตัวจริง'),
    _WheelReward('ฉายา: "เทพแห่งดวงดาว 🌌"', 'ดวงดาว 🌌', Colors.purple, 'fixed_title', 'เทพแห่งดวงดาว 🌌'),
    _WheelReward('ฉายา: "พนักงานระดับตำนาน 🌟"', 'ตำนาน 🌟', Colors.deepOrange, 'fixed_title', 'พนักงานระดับตำนาน 🌟'),
    _WheelReward('โล่ป้องกัน x3 🛡️🛡️🛡️', 'โล่ x3 🛡️', Colors.blue, 'shield_multi', 3),
    _WheelReward('บัฟแต้ม x2 (2 ชั่วโมง!) 🔥', 'บัฟ 2ชม. 🔥', Colors.redAccent, 'buff', 120),
    _WheelReward('โบนัสใหญ่ +500 แต้ม ✨', '+500 ✨', Colors.teal, 'bonus', 500),
    _WheelReward('โบนัส +250 แต้ม 🌟', '+250 🌟', Colors.green, 'bonus', 250),
    _WheelReward('กล่องสมบัติทองคำ (300-800 แต้ม) 🎁', 'กล่องทอง 🎁', Colors.deepPurpleAccent, 'mystery_key_gold', null),
    _WheelReward('คืนทุน +100 แต้ม 💸', '+100 💸', Colors.orange, 'bonus', 100),
    _WheelReward('เกลือพรีเมียมสีชมพู 🧂✨', 'เกลือชมพู 🧂', Color(0xFFB0BEC5), 'salt', 0),
    _WheelReward('ปลอบใจเบาๆ +10 แต้ม 🥺', '+10 🥺', Color(0xFFCFD8DC), 'bonus', 10),
    _WheelReward('กลิ่นอายความเค็ม 💨', 'ลมเปล่า 💨', Color(0xFF90A4AE), 'salt', 0),
    _WheelReward('👑 ฉายา: "ราชาเกลือ VIP 🧂"', 'ราชาเกลือ 🧂', Colors.blueGrey, 'fixed_title', 'ราชาเกลือ VIP 🧂'),
    _WheelReward('ภาษีความมั่งคั่ง -20 แต้ม 💸🔻', '-20 🔻', Color(0xFFEF5350), 'penalty', -20),
    _WheelReward('โดนปล้นกลางทาง -50 แต้ม 🏴‍☠️🔻', '-50 🔻', Color(0xFFC62828), 'penalty', -50),
  ];

  List<_WheelReward> get currentRewards => _selectedWheelIndex == 0 ? standardRewards : premiumRewards;
  int get currentCost => _selectedWheelIndex == 0 ? 20 : 100;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_isSpinning) return;
    final cost = currentCost;

    if (globalUserScore < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('คุณต้องการคะแนนอย่างน้อย $cost แต้มเพื่อหมุนตู้นี้')),
      );
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? globalUserId;

    setState(() {
      _isSpinning = true;
      _resultText = null;
      globalUserScore = max(0, globalUserScore - cost);
    });

    if (currentUid.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(currentUid).set({
        'score': globalUserScore,
      }, SetOptions(merge: true)).catchError((e) => debugPrint('Error deduct score: $e'));
    }

    await recordCustomDailyQuest('wheelSpinCount', 1);

    final random = Random();
    final activeList = currentRewards;
    final targetIndex = random.nextInt(activeList.length);
    final sectionAngle = (2 * pi) / activeList.length;

    final targetSectorAngle = (3 * pi / 2) - (targetIndex * sectionAngle + sectionAngle / 2);
    final totalRotation = (5 * 2 * pi) + targetSectorAngle;
    final endAngle = _currentAngle + totalRotation;

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.reset();
    await _controller.forward();

    _currentAngle = endAngle % (2 * pi);

    final reward = activeList[targetIndex];
    final updateData = <String, dynamic>{};
    String finalRewardLabel = reward.label;

    if (reward.type == 'jackpot' || reward.type == 'bonus' || reward.type == 'free_spin') {
      int finalScore = max(0, globalUserScore + (reward.value as int));
      updateData['score'] = finalScore;
      globalUserScore = finalScore;
    } else if (reward.type == 'shield' || reward.type == 'shield_multi') {
      int count = reward.value as int;
      globalUserShields += count;
      updateData['shields'] = FieldValue.increment(count);
      finalRewardLabel = 'โล่กันแต้มลด 🛡️ (+$count ชิ้นในคลัง)';
    } else if (reward.type == 'sub_frame_random_normal') {
      final normalFrames = [
        {'id': 'silver', 'name': '🥈 กรอบสีเงินพรีเมียม'},
        {'id': 'wind', 'name': '🍃 กรอบสายลมวายุ'},
        {'id': 'dark', 'name': '🌑 กรอบธาตุมืดทมิฬ'},
        {'id': 'challenger', 'name': '🏆 Challenger Aura ⚡'},
      ];
      final picked = normalFrames[random.nextInt(normalFrames.length)];
      final frameId = picked['id']!;
      final frameName = picked['name']!;

      updateData['frame'] = frameId;
      updateData['unlockedFrames'] = FieldValue.arrayUnion([frameId]);
      globalUserFrame = frameId;
      if (!globalUnlockedFrames.contains(frameId)) globalUnlockedFrames.add(frameId);
      finalRewardLabel = 'สุ่มได้กรอบ: $frameName';
    } else if (reward.type == 'vip_frame') {
      final frameId = reward.value as String;
      String frameTitle = '🪽 กรอบมีปีกแห่งแสง';
      if (frameId == 'aura') frameTitle = '🔮 กรอบออร่าจักรวาล';
      if (frameId == 'sparkle') frameTitle = '✨ กรอบวิ้งๆ ประกายเพชร';

      updateData['frame'] = frameId;
      updateData['unlockedFrames'] = FieldValue.arrayUnion([frameId]);
      globalUserFrame = frameId;
      if (!globalUnlockedFrames.contains(frameId)) globalUnlockedFrames.add(frameId);
      finalRewardLabel = 'สุ่มได้กรอบ VIP: $frameTitle';
    } else if (reward.type == 'fixed_title') {
      final title = reward.value as String;
      updateData['title'] = title;
      updateData['unlockedTitles'] = FieldValue.arrayUnion([title]);
      globalUserTitle = title;
      if (!globalUnlockedTitles.contains(title)) globalUnlockedTitles.add(title);
      finalRewardLabel = 'สุ่มได้ฉายา: "$title"';
    } else if (reward.type == 'mystery_key') {
      final gained = 50 + random.nextInt(151);
      int finalScore = globalUserScore + gained;
      updateData['score'] = finalScore;
      globalUserScore = finalScore;
      finalRewardLabel = 'กุญแจกล่องสุ่ม 🎁 เปิดได้ +$gained แต้ม!';
    } else if (reward.type == 'mystery_key_gold') {
      final gained = 300 + random.nextInt(501);
      int finalScore = globalUserScore + gained;
      updateData['score'] = finalScore;
      globalUserScore = finalScore;
      finalRewardLabel = 'กล่องทองคำ 🎁 เปิดได้ +$gained แต้ม!';
    } else if (reward.type == 'penalty') {
      if (globalUserShields > 0) {
        globalUserShields -= 1;
        updateData['shields'] = FieldValue.increment(-1);
        finalRewardLabel = '🛡️ โล่ทำงาน! ป้องกันบทลงโทษ (${reward.label}) ได้สำเร็จ';
      } else {
        int penaltyVal = reward.value as int;
        int finalScore = max(0, globalUserScore + penaltyVal);
        updateData['score'] = finalScore;
        globalUserScore = finalScore;
      }
    } else if (reward.type == 'buff') {
      final buffExpiry = DateTime.now().add(Duration(minutes: reward.value as int));
      final ts = Timestamp.fromDate(buffExpiry);
      updateData['buffX2Until'] = ts;
      globalBuffX2Until = ts;
    }

    if (currentUid.isNotEmpty && updateData.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(currentUid).set(
        updateData,
        SetOptions(merge: true),
      ).catchError((e) => debugPrint('Error updating user data: $e'));
    }

    FirebaseFirestore.instance.collection('wheel_history').add({
      'userName': globalUserName.isNotEmpty ? globalUserName : 'Staff',
      'userAvatar': globalUserAvatar,
      'wheelType': _selectedWheelIndex == 0 ? 'Standard' : 'VIP High Roller',
      'rewardLabel': finalRewardLabel,
      'rewardType': reward.type,
      'timestamp': Timestamp.now(),
    }).catchError((e) => debugPrint('Error adding wheel_history: $e'));

    if (mounted) {
      setState(() {
        _isSpinning = false;
        _resultText = finalRewardLabel;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: reward.type == 'penalty' ? Colors.red[50] : Colors.purple[50],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    reward.type == 'jackpot' ? '💥' : (reward.type == 'penalty' ? '🔻' : '🎁'),
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('ยินดีด้วย!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: reward.type == 'penalty' ? Colors.red[50] : Colors.amber[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: reward.type == 'penalty' ? Colors.red[300]! : Colors.amber[400]!),
                ),
                child: Text(
                  finalRewardLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: reward.type == 'penalty' ? Colors.red[800] : Colors.purple[900],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('แต้มคงเหลือ: $globalUserScore แต้ม', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedWheelIndex == 0 ? Colors.purple[700] : Colors.amber[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ตกลง', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _selectedWheelIndex == 0 ? Colors.purple[700]! : Colors.amber[800]!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      title: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('คลาสสิก (20แต้ม)', style: TextStyle(fontSize: 12)),
                selected: _selectedWheelIndex == 0,
                selectedColor: Colors.purple[100],
                onSelected: _isSpinning
                    ? null
                    : (val) {
                        if (val) setState(() => _selectedWheelIndex = 0);
                      },
              ),
              ChoiceChip(
                label: const Text('👑 VIP (100แต้ม)', style: TextStyle(fontSize: 12)),
                selected: _selectedWheelIndex == 1,
                selectedColor: Colors.amber[200],
                onSelected: _isSpinning
                    ? null
                    : (val) {
                        if (val) setState(() => _selectedWheelIndex = 1);
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'แต้มของคุณ: $globalUserScore แต้ม • 🛡️ โล่: $globalUserShields',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 380,
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final angle = _isSpinning ? _animation.value : _currentAngle;
                      return Transform.rotate(
                        angle: angle,
                        child: CustomPaint(
                          size: const Size(150, 150),
                          painter: _WheelPainter(rewards: currentRewards),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: const Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 32),
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.stars, color: activeColor, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (_resultText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedWheelIndex == 0 ? Colors.purple[50] : Colors.amber[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: activeColor),
                ),
                child: Text(
                  '🎉 ผลลัพธ์: $_resultText',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: activeColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                _selectedWheelIndex == 0 ? 'หมุนตู้คลาสสิก (ลุ้น +500 / กรอบ ⚡)' : 'หมุนตู้ VIP (ลุ้น +2,000 / กรอบ VIP 🪽)',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.history, size: 14, color: activeColor),
                const SizedBox(width: 4),
                Text('ประวัติการสุ่มล่าสุด 📜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: activeColor)),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('wheel_history')
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('โหลดประวัติไม่สำเร็จ', style: TextStyle(fontSize: 10, color: Colors.red)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('ยังไม่มีประวัติการสุ่ม', style: TextStyle(fontSize: 10, color: Colors.grey)));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final item = docs[index].data() as Map<String, dynamic>;
                      final uName = item['userName'] ?? 'Unknown';
                      final rLabel = item['rewardLabel'] ?? '-';
                      final rType = item['rewardType'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(
                          children: [
                            Text('• ', style: TextStyle(color: activeColor.withOpacity(0.5), fontWeight: FontWeight.bold)),
                            Text('$uName: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                            Expanded(
                              child: Text(
                                rLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: (rType == 'jackpot' || rLabel.contains('500') || rLabel.contains('2,000') || rLabel.contains('กล่อง'))
                                      ? Colors.red[700]
                                      : (rType == 'penalty' ? Colors.red : Colors.black87),
                                  fontWeight: rLabel.contains('500') || rLabel.contains('2,000') || rType == 'fixed_title' || rType.contains('frame')
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: _isSpinning ? null : () => Navigator.pop(context),
          child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: _isSpinning ? null : _spin,
          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
          label: Text(
            _isSpinning ? 'กำลังหมุน...' : 'หมุนเลย ($currentCost แต้ม)',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<_WheelReward> rewards;
  _WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final arcAngle = (2 * pi) / rewards.length;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 1.5;

    for (int i = 0; i < rewards.length; i++) {
      paint.color = rewards[i].color;
      final startAngle = i * arcAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle,
        true,
        paint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle,
        true,
        borderPaint,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + arcAngle / 2);

      final textSpan = TextSpan(
        text: rewards[i].shortText,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius * 0.38, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 🌌 หน้าต่างเปิดซองการ์ดอวกาศ (Card Pack Dialog)
// ==========================================
class CardPackOpeningDialog extends StatefulWidget {
  final int currentScore;
  const CardPackOpeningDialog({super.key, required this.currentScore});

  @override
  State<CardPackOpeningDialog> createState() => _CardPackOpeningDialogState();
}

class _CardPackOpeningDialogState extends State<CardPackOpeningDialog> with SingleTickerProviderStateMixin {
  bool _isOpening = false;
  bool _isRevealing = false;
  List<CardReward> _pulledCards = [];
  int _currentIndex = 0;
  bool _cardFlipped = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _openCardPack() async {
    if (globalUserScore < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณต้องการคะแนนอย่างน้อย 200 แต้มเพื่อเปิดซองการ์ดนี้!')),
      );
      return;
    }

    setState(() => _isOpening = true);
    _shakeController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 1800));
    _shakeController.stop();

    final random = Random();
    List<CardReward> results = [];
    
    for (int i = 0; i < 3; i++) {
      double roll = random.nextDouble() * 100;
      List<CardReward> pool = [];
      if (roll < 60) {
        pool = galaxyMeowCards.where((c) => c.rarity.contains('Common')).toList();
      } else if (roll < 85) {
        pool = galaxyMeowCards.where((c) => c.rarity.contains('Rare')).toList();
      } else if (roll < 97) {
        pool = galaxyMeowCards.where((c) => c.rarity.contains('Super Rare')).toList();
      } else {
        pool = galaxyMeowCards.where((c) => c.rarity.contains('Secret')).toList();
      }
      if (pool.isEmpty) pool = galaxyMeowCards;
      results.add(pool[random.nextInt(pool.length)]);
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? globalUserId;
    globalUserScore = max(0, globalUserScore - 200);

    List<String> cardDataList = results.map((c) => '${c.emoji}|${c.name}|${c.rarity}|${c.power}').toList();

    if (currentUid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
        'score': globalUserScore,
        'cardInventory': FieldValue.arrayUnion(cardDataList),
      }, SetOptions(merge: true));
    }

    setState(() {
      _isOpening = false;
      _isRevealing = true;
      _pulledCards = results;
      _currentIndex = 0;
      _cardFlipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF1A1A2E),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 300,
        height: 380,
        child: !_isRevealing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🌌 ซองการ์ด Celestial Meow', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('สุ่มการ์ดแมวอวกาศ 3 ใบ (ราคา 200 แต้ม)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 20),
                  
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      double offset = _isOpening ? sin(_shakeController.value * pi * 8) * 6 : 0;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: Container(
                          width: 140,
                          height: 190,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.purpleAccent, blurRadius: 16, spreadRadius: 2)],
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🐱✨', style: TextStyle(fontSize: 40)),
                                SizedBox(height: 8),
                                Text('GALAXY PACK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('คะแนนคงเหลือ: $globalUserScore แต้ม', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isOpening ? null : _openCardPack,
                      child: Text(_isOpening ? 'กำลังฉีกซอง... 📦' : 'เปิดซอง (200 แต้ม)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('การ์ดใบที่ ${_currentIndex + 1} จาก 3', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _cardFlipped = true),
                    child: SizedBox(
                      width: 170,
                      height: 240,
                      child: _cardFlipped
                          ? PremiumMeowCardWidget(
                              emoji: _pulledCards[_currentIndex].emoji,
                              name: _pulledCards[_currentIndex].name,
                              rarity: _pulledCards[_currentIndex].rarity,
                              power: _pulledCards[_currentIndex].power.toString(),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.indigo[900],
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.amber, width: 2.5),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('❓', style: TextStyle(fontSize: 42)),
                                  SizedBox(height: 8),
                                  Text('แตะเพื่อเปิดการ์ด!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_cardFlipped)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        onPressed: () {
                          if (_currentIndex < _pulledCards.length - 1) {
                            setState(() {
                              _currentIndex++;
                              _cardFlipped = false;
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(_currentIndex < _pulledCards.length - 1 ? 'เปิดใบถัดไป ➡️' : 'เสร็จสิ้น ✨', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    const Text('แตะที่การ์ดเพื่อเปิดดูผลลัพธ์', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}

// ==========================================
// 🖼️ หน้าต่างแสดงคลังการ์ดสะสม (Card Inventory Dialog)
// ==========================================
class CardInventoryDialog extends StatelessWidget {
  const CardInventoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🖼️ คลังการ์ดสะสมของคุณ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 440,
        child: globalCardInventory.isEmpty
            ? const Center(child: Text('ยังไม่มีการ์ดในคลัง\n(เปิดซองการ์ดเพื่อสะสม!)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)))
            : GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.68,
                ),
                itemCount: globalCardInventory.length,
                itemBuilder: (context, index) {
                  final rawText = globalCardInventory[index].toString();
                  final parts = rawText.split('|');
                  
                  String emoji = '🐱';
                  String name = rawText;
                  String rarity = 'Common';
                  String power = '50';

                  if (parts.length >= 4) {
                    emoji = parts[0];
                    name = parts[1];
                    rarity = parts[2];
                    power = parts[3];
                  } else {
                    name = rawText;
                    if (rawText.contains('Super Rare')) {
                      rarity = 'Super Rare 🥇';
                      emoji = '👑🦁';
                      power = '120';
                    } else if (rawText.contains('Rare')) {
                      rarity = 'Rare 🥈';
                      emoji = '🛸🐈';
                      power = '80';
                    } else if (rawText.contains('Secret')) {
                      rarity = 'Secret Rare 💎🔥';
                      emoji = '🕳️🐈‍⬛';
                      power = '250';
                    } else {
                      rarity = 'Common 🥉';
                      emoji = '🐱🪐';
                      power = '50';
                    }
                  }

                  return PremiumMeowCardWidget(
                    emoji: emoji,
                    name: name,
                    rarity: rarity,
                    power: power,
                  );
                },
              ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
// ==========================================
// ⚔️ มินิเกมประลองสัตว์เลี้ยงแบบเห็นการต่อสู้ (Animated Pet Battle Arena)
// ==========================================
class AnimatedPetBattleDialog extends StatefulWidget {
  final String enemyId;
  final String enemyName;
  final Map<String, dynamic> enemyPet;

  const AnimatedPetBattleDialog({
    super.key,
    required this.enemyId,
    required this.enemyName,
    required this.enemyPet,
  });

  @override
  State<AnimatedPetBattleDialog> createState() => _AnimatedPetBattleDialogState();
}

class _AnimatedPetBattleDialogState extends State<AnimatedPetBattleDialog> with TickerProviderStateMixin {
  late int myMaxHp;
  late int myHp;
  late int myAtk;
  late String myName;
  late String myType;
  late String myWeapon;
  late String myHat;

  late int enemyMaxHp;
  late int enemyHp;
  late int enemyAtk;
  late String enemyPetName;
  late String enemyType;
  late String enemyWeapon;
  late String enemyHat;

  late AnimationController _myAttackController;
  late AnimationController _enemyAttackController;
  late Animation<double> _myAttackAnim;
  late Animation<double> _enemyAttackAnim;

  List<String> combatLogs = [];
  bool isBattleEnded = false;
  bool isPlayerWon = false;
  String? currentEffect;
  String? currentDamage;
  bool isTargetEnemy = true;
  int calculatedDamageTaken = 0;

  @override
  void initState() {
    super.initState();
    final myLvl = (globalUserPet['level'] is num) ? (globalUserPet['level'] as num).toInt() : 1;
    myName = globalUserPet['name'] ?? 'น้องนำโชค';
    myType = globalUserPet['type'] ?? '🐱';
    myWeapon = globalUserPet['equippedWeapon'] ?? '';
    myHat = globalUserPet['equippedHat'] ?? '';
    myAtk = 10 + (myLvl * 5) + getItemBonusAtk(myWeapon);
    myMaxHp = 80 + (myLvl * 20) + getItemBonusHp(myHat);
    myHp = (globalUserPet['hp'] is num) ? (globalUserPet['hp'] as num).toInt() : myMaxHp;

    final enemyLvl = (widget.enemyPet['level'] is num) ? (widget.enemyPet['level'] as num).toInt() : 1;
    enemyPetName = widget.enemyPet['name'] ?? 'สัตว์เลี้ยงคู่แข่ง';
    enemyType = widget.enemyPet['type'] ?? '🐶';
    enemyWeapon = widget.enemyPet['equippedWeapon'] ?? '';
    enemyHat = widget.enemyPet['equippedHat'] ?? '';
    enemyAtk = 10 + (enemyLvl * 5) + getItemBonusAtk(enemyWeapon);
    enemyMaxHp = 80 + (enemyLvl * 20) + getItemBonusHp(enemyHat);
    enemyHp = (widget.enemyPet['hp'] is num) ? (widget.enemyPet['hp'] as num).toInt() : enemyMaxHp;

    _myAttackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _myAttackAnim = Tween<double>(begin: 0.0, end: 40.0).animate(
      CurvedAnimation(parent: _myAttackController, curve: Curves.easeInOutBack),
    );

    _enemyAttackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _enemyAttackAnim = Tween<double>(begin: 0.0, end: -40.0).animate(
      CurvedAnimation(parent: _enemyAttackController, curve: Curves.easeInOutBack),
    );

    _startBattleSequence();
  }

  @override
  void dispose() {
    _myAttackController.dispose();
    _enemyAttackController.dispose();
    super.dispose();
  }

  void _startBattleSequence() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // คำนวณผลแพ้ชนะจากสูตรเดิม (เปรียบเทียบ Turns ในการตีจนตาย)
    final int turnsToDefeatEnemy = (enemyHp / max(1, myAtk)).ceil();
    final int turnsToDefeatMe = (myHp / max(1, enemyAtk)).ceil();
    isPlayerWon = turnsToDefeatEnemy <= turnsToDefeatMe;

    // 1. เทิร์นผู้เล่นพุ่งโจมตี
    await _myAttackController.forward();
    await _myAttackController.reverse();

    if (mounted) {
      setState(() {
        currentEffect = '💥';
        currentDamage = '-$myAtk';
        isTargetEnemy = true;
        combatLogs.insert(0, '⚡ $myName โจมตีด้วยพลัง $myAtk ATK!');
      });
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      currentEffect = null;
      currentDamage = null;
    });

    // 2. เทิร์นศัตรูพุ่งสวนกลับ
    await _enemyAttackController.forward();
    await _enemyAttackController.reverse();

    if (mounted) {
      setState(() {
        currentEffect = '⚔️';
        currentDamage = '-$enemyAtk';
        isTargetEnemy = false;
        combatLogs.insert(0, '🔥 $enemyPetName สวนกลับด้วยพลัง $enemyAtk ATK!');
      });
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      currentEffect = null;
      currentDamage = null;
    });

    // 3. สรุปผล: ถ้าแพ้ เลือดจะลดตามส่วนต่างพลังโจมตี (ไม่ใช่ลดจนเหลือ 0)
    final updatedPet = Map<String, dynamic>.from(globalUserPet);

    if (isPlayerWon) {
      combatLogs.insert(0, '🏆 $myName เอาชนะการประลองได้อย่างงดงาม!');
      await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
        'score': FieldValue.increment(5),
      });
      globalUserScore += 5;
    } else {
      calculatedDamageTaken = max(5, enemyAtk - myAtk);
      myHp = max(0, myHp - calculatedDamageTaken);
      updatedPet['hp'] = myHp;

      combatLogs.insert(0, '💥 คุณพ่ายแพ้! ได้รับความเสียหายหักลบ -$calculatedDamageTaken HP');
      await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
        'pet': updatedPet,
      });
      globalUserPet = updatedPet;
    }

    if (mounted) {
      setState(() {
        isBattleEnded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF161B22),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: 320,
        height: 480,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.sports_kabaddi, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text('Pet Arena ประลอง ⚔️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const Divider(color: Colors.white24, height: 16),
            
            // สนามประลอง (Arena Field)
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // ฝั่งผู้เล่น (Player)
                      AnimatedBuilder(
                        animation: _myAttackAnim,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_myAttackAnim.value, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(myType, style: const TextStyle(fontSize: 46)),
                                const SizedBox(height: 4),
                                Text(myName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 85,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: myMaxHp > 0 ? (myHp / myMaxHp).clamp(0.0, 1.0) : 0,
                                      minHeight: 6,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('❤️ $myHp/$myMaxHp', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('⚔️ ATK: $myAtk', style: const TextStyle(color: Colors.cyanAccent, fontSize: 9.5)),
                              ],
                            ),
                          );
                        },
                      ),

                      const Text('VS', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),

                      // ฝั่งศัตรู (Enemy)
                      AnimatedBuilder(
                        animation: _enemyAttackAnim,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_enemyAttackAnim.value, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(enemyType, style: const TextStyle(fontSize: 46)),
                                const SizedBox(height: 4),
                                Text(enemyPetName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 85,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: enemyMaxHp > 0 ? (enemyHp / enemyMaxHp).clamp(0.0, 1.0) : 0,
                                      minHeight: 6,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('❤️ $enemyHp/$enemyMaxHp', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('⚔️ ATK: $enemyAtk', style: const TextStyle(color: Colors.orangeAccent, fontSize: 9.5)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Floating Damage / Effect
                  if (currentEffect != null && currentDamage != null)
                    Positioned(
                      left: isTargetEnemy ? 190 : 45,
                      top: 35,
                      child: Column(
                        children: [
                          Text(currentEffect!, style: const TextStyle(fontSize: 28)),
                          Text(currentDamage!, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Combat Log Box
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: combatLogs.isEmpty
                    ? const Center(child: Text('⚔️ กำลังเตรียมการประลอง...', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        itemCount: combatLogs.length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              combatLogs[idx],
                              style: TextStyle(
                                color: idx == 0 ? Colors.amberAccent : Colors.white70,
                                fontSize: 11,
                                fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // ปุ่มผลลัพธ์
            if (isBattleEnded)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPlayerWon ? Colors.green[700] : Colors.red[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isPlayerWon ? '🎉 ชนะการประลอง (+5 แต้ม)! ตกลง' : '💥 พ่ายแพ้ (-$calculatedDamageTaken HP)! ตกลง',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              const Text('⚔️ การต่อสู้กำลังดำเนินอยู่...', style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// LeaderboardScreen
// ==========================================
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isFeeding = false;
  bool _isGachaSpinning = false;
  bool _showHeart = false;

  Future<void> _sendHeartToUser(String targetDocId, String targetUserName) async {
    if (targetDocId == globalUserId) return;

    final now = DateTime.now();

    if (globalLastHeartSent.containsKey(targetDocId)) {
      final lastTimestamp = globalLastHeartSent[targetDocId];
      if (lastTimestamp is Timestamp) {
        final lastSentTime = lastTimestamp.toDate();
        final difference = now.difference(lastSentTime);

        if (difference.inMinutes < 60) {
          final minutesLeft = 60 - difference.inMinutes;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.grey[800],
              content: Text('⏳ คุณกดส่งใจให้ $targetUserName ไปแล้ว (รออีก $minutesLeft นาที)'),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
    }

    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetDocId);
    final myUserRef = FirebaseFirestore.instance.collection('users').doc(globalUserId);
    final today = getTodayKey();

    try {
      final currentTimestamp = Timestamp.now();
      await targetUserRef.update({'hearts': FieldValue.increment(1)});

      final mySnap = await myUserRef.get();
      final myData = mySnap.data() ?? {};

      Map<String, dynamic> allDailyQuests = {};
      if (myData['dailyQuests'] is Map) {
        allDailyQuests = Map<String, dynamic>.from(myData['dailyQuests']);
      }

      Map<String, dynamic> todayQuest = {};
      if (allDailyQuests[today] is Map) {
        todayQuest = Map<String, dynamic>.from(allDailyQuests[today]);
      }

      List<dynamic> heartSentUsers = (todayQuest['heartSentUsers'] is List) ? List.from(todayQuest['heartSentUsers']) : [];
      if (!heartSentUsers.contains(targetDocId)) {
        heartSentUsers.add(targetDocId);
      }
      int heartSentTotal = (todayQuest['heartSentTotal'] is num) ? (todayQuest['heartSentTotal'] as num).toInt() : 0;
      heartSentTotal += 1;

      todayQuest['heartSentUsers'] = heartSentUsers;
      todayQuest['heartSentTotal'] = heartSentTotal;
      allDailyQuests[today] = todayQuest;

      Map<String, dynamic> lastHeartMap = {};
      if (myData['lastHeartSent'] is Map) {
        lastHeartMap = Map<String, dynamic>.from(myData['lastHeartSent']);
      }
      lastHeartMap[targetDocId] = currentTimestamp;

      await myUserRef.set({
        'score': FieldValue.increment(1),
        'lastHeartSent': lastHeartMap,
        'dailyQuests': allDailyQuests,
      }, SetOptions(merge: true));

      setState(() {
        globalUserScore += 1;
        globalLastHeartSent[targetDocId] = currentTimestamp;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.pink[600],
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white),
                const SizedBox(width: 8),
                Text('ส่งกำลังใจให้ $targetUserName แล้ว! (+1 แต้ม)'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending heart: $e');
    }
  }

  void _openLuckyWheelDialog(int myScore) {
    showDialog(
      context: context,
      builder: (context) => LuckyWheelDialog(currentScore: myScore),
    );
  }

  void _openCardPackDialog(int myScore) {
    showDialog(
      context: context,
      builder: (context) => CardPackOpeningDialog(currentScore: myScore),
    );
  }

  void _openCardInventoryDialog() {
    showDialog(
      context: context,
      builder: (context) => const CardInventoryDialog(),
    );
  }

  void _openChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: const SizedBox(height: 500, child: TeamChatBottomSheet()),
        );
      },
    );
  }

  void _claimOrEquipTitle(int currentScore, int requiredScore, String titleName) async {
    final bool isOwned = globalUnlockedTitles.contains(titleName);

    if (!isOwned && currentScore < requiredScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('คุณต้องการคะแนนอย่างน้อย $requiredScore แต้มเพื่อแลกฉายานี้ (ปัจจุบันมี $currentScore แต้ม)')),
      );
      return;
    }

    try {
      if (!isOwned) {
        await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
          'title': titleName,
          'unlockedTitles': FieldValue.arrayUnion([titleName]),
        });
        setState(() {
          globalUserTitle = titleName;
          globalUnlockedTitles.add(titleName);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🎉 ยินดีด้วย! คุณได้รับฉายา "$titleName" แล้ว!'), backgroundColor: Colors.green[700]),
          );
        }
      } else {
        final newTitle = (globalUserTitle == titleName) ? '' : titleName;
        await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({'title': newTitle});
        setState(() => globalUserTitle = newTitle);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(newTitle.isEmpty ? 'ถอดฉายาแล้ว' : 'สวมใส่ฉายา "$newTitle" แล้ว')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error title: $e');
    }
  }

  void _equipOrUnequipFrame(String frameType) async {
    final newFrame = (globalUserFrame == frameType) ? '' : frameType;
    try {
      await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({'frame': newFrame});
      setState(() => globalUserFrame = newFrame);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newFrame.isEmpty ? 'ถอดกรอบโปรไฟล์แล้ว' : 'สวมใส่กรอบโปรไฟล์แล้ว')),
        );
      }
    } catch (e) {
      debugPrint('Error frame: $e');
    }
  }

  void _spinPetGacha() async {
    if (_isGachaSpinning) return;
    _isGachaSpinning = true;

    if (globalUserScore < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องการ 50 แต้มเพื่อสุ่มกาชาสัตว์เลี้ยง')),
      );
      _isGachaSpinning = false;
      return;
    }

    final randomItem = petGachaDatabase[Random().nextInt(petGachaDatabase.length)];
    final itemName = randomItem['name'] as String;

    try {
      await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
        'score': FieldValue.increment(-50),
        'petInventory': FieldValue.arrayUnion([itemName]),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Center(child: Text('🐾 กาชาสัตว์เลี้ยง 🐾', style: TextStyle(fontWeight: FontWeight.bold))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉 ยินดีด้วย! สุ่มได้รับไอเทม:', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(12)),
                  child: Text(itemName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber[900])),
                ),
                const SizedBox(height: 10),
                const Text('สามารถกดติดตั้งได้ในคลังไอเทมด้านล่าง!', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ตกลง', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } finally {
      _isGachaSpinning = false;
    }
  }

  void _feedPet() async {
    if (_isFeeding) return;
    _isFeeding = true;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? globalUserId;
    if (uid.isEmpty) {
      _isFeeding = false;
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      bool levelUp = false;
      int newLevel = 1;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(userRef);
        if (!snap.exists) return;

        final data = snap.data()!;
        final currentScore = (data['score'] is num) ? (data['score'] as num).toInt() : 0;

        if (currentScore < 50) {
          throw Exception('score_not_enough');
        }

        final petData = Map<String, dynamic>.from(data['pet'] ?? {});
        int pExp = (petData['exp'] is num) ? (petData['exp'] as num).toInt() + 20 : 20;
        int pLevel = (petData['level'] is num) ? (petData['level'] as num).toInt() : 1;
        int pHp = (petData['hp'] is num) ? (petData['hp'] as num).toInt() : 100;
        
        final String hat = petData['equippedHat'] ?? '';
        int maxHp = 80 + (pLevel * 20) + getItemBonusHp(hat);

        while (pExp >= 100) {
          pExp -= 100;
          pLevel += 1;
          levelUp = true;
          maxHp = 80 + (pLevel * 20) + getItemBonusHp(hat);
        }

        if (levelUp) {
          pHp = maxHp; // รีเซ็ตเลือดเต็มหลอดทันทีเมื่อเลเวลอัป
        } else {
          pHp = min(maxHp, pHp + 10); // ถ้าไม่เลเวลอัป ฟื้นฟูปกติ +10
        }

        pHp = min(maxHp, pHp + 10);

        newLevel = pLevel;
        petData['exp'] = pExp;
        petData['level'] = pLevel;
        petData['hp'] = pHp;

        transaction.update(userRef, {
          'score': currentScore - 50,
          'pet': petData,
        });
      });

      setState(() => _showHeart = true);
      Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showHeart = false);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[700],
            content: Text(levelUp
                ? '🎉 สัตว์เลี้ยงเลเวลอัปเป็น Lv.$newLevel! ฟื้นฟู HP เต็มหลอดแล้ว ❤️'
                : '🍖 ให้อาหารสำเร็จ (-50 แต้ม)! ได้รับ +20 EXP และฟื้นฟู HP +10 ❤️'),
          ),
        );
      }
    } catch (e) {
      if (e.toString().contains('score_not_enough') && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ต้องการ 50 แต้มเพื่อซื้ออาหารสัตว์เลี้ยง')),
        );
      }
    } finally {
      _isFeeding = false;
    }
  }

  void _showEditPetCustomizationDialog() {
    final nameCtrl = TextEditingController(text: globalUserPet['name'] ?? 'น้องนำโชค');
    String selectedType = globalUserPet['type'] ?? '🐱';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('ตั้งค่าสัตว์เลี้ยง 🐾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เลือกชนิดสัตว์เลี้ยง (18 ชนิด):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: petTypesList.map((p) {
                        final isSel = selectedType == p['type'];
                        return ChoiceChip(
                          avatar: Text(p['type']!, style: const TextStyle(fontSize: 16)),
                          label: Text(p['name']!),
                          selected: isSel,
                          selectedColor: Colors.amber[200],
                          onSelected: (val) {
                            if (val) setDlgState(() => selectedType = p['type']!);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อสัตว์เลี้ยง',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  onPressed: () async {
                    final newName = nameCtrl.text.trim();
                    if (newName.isEmpty) return;

                    final updated = Map<String, dynamic>.from(globalUserPet);
                    updated['name'] = newName;
                    updated['type'] = selectedType;

                    await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
                      'pet': updated,
                    });

                    setState(() {
                      globalUserPet = updated;
                    });

                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  },
                  child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startPetBattle(String enemyId, String enemyName, Map<String, dynamic> enemyPet) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnimatedPetBattleDialog(
        enemyId: enemyId,
        enemyName: enemyName,
        enemyPet: enemyPet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rank, Pet & Shop 🏆', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: false,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.emoji_events), text: 'อันดับ'),
              Tab(icon: Icon(Icons.pets), text: 'สัตว์เลี้ยง'),
              Tab(icon: Icon(Icons.shopping_bag), text: 'ร้านค้า & วงล้อ'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').orderBy('score', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final users = snapshot.data!.docs;
            int myCurrentScore = globalUserScore;

            for (var u in users) {
              if (u.id == globalUserId) {
                final d = u.data() as Map<String, dynamic>;
                myCurrentScore = (d['score'] is num) ? (d['score'] as num).toInt() : 0;
                globalUserFrame = d['frame'] ?? '';
                globalBuffX2Until = d['buffX2Until'];
                globalUserHearts = (d['hearts'] is num) ? (d['hearts'] as num).toInt() : 0;
                globalUserShields = (d['shields'] is num) ? (d['shields'] as num).toInt() : 0;
                globalLastHeartSent = d['lastHeartSent'] != null ? Map<String, dynamic>.from(d['lastHeartSent']) : {};
                globalUserPet = d['pet'] != null ? Map<String, dynamic>.from(d['pet']) : {};
                globalPetInventory = List<dynamic>.from(d['petInventory'] ?? []);
                globalCardInventory = List<dynamic>.from(d['cardInventory'] ?? []);
                break;
              }
            }

            final petType = globalUserPet['type'] ?? '🐱';
            final petName = globalUserPet['name'] ?? 'น้องนำโชค';
            final petLevel = (globalUserPet['level'] is num) ? (globalUserPet['level'] as num).toInt() : 1;
            final petExp = (globalUserPet['exp'] is num) ? (globalUserPet['exp'] as num).toInt() : 0;
            final petWeapon = globalUserPet['equippedWeapon'] ?? 'ไม่มี';
            final petHat = globalUserPet['equippedHat'] ?? 'ไม่มี';

            final int baseAtk = 10 + (petLevel * 5);
            final int bonusAtk = getItemBonusAtk(petWeapon);
            final int totalAtk = baseAtk + bonusAtk;

            final int baseHp = 80 + (petLevel * 20);
            final int bonusHp = getItemBonusHp(petHat);
            final int totalMaxHp = baseHp + bonusHp;
            final int currentHp = (globalUserPet['hp'] is num) ? (globalUserPet['hp'] as num).toInt() : totalMaxHp;

            return TabBarView(
              children: [
                // แท็บ 1: อันดับ
                users.isEmpty
                    ? const Center(child: Text('ยังไม่มีข้อมูลคะแนน', style: TextStyle(fontSize: 18)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userData = users[index].data() as Map<String, dynamic>;
                          final docId = users[index].id;
                          final name = userData['name'] ?? 'Unknown';
                          final avatar = userData['avatar'] ?? '🐱';
                          final score = (userData['score'] is num) ? (userData['score'] as num).toInt() : 0;
                          final level = (userData['level'] is num) ? (userData['level'] as num).toInt() : 1;
                          final title = userData['title'] ?? '';
                          final frame = userData['frame'] ?? '';
                          final hearts = (userData['hearts'] is num) ? (userData['hearts'] as num).toInt() : 0;
                          final isMe = docId == globalUserId;
                          final enemyPet = userData['pet'] != null ? Map<String, dynamic>.from(userData['pet']) : null;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  buildUserAvatarWidget(avatar, radius: 24, fontSize: 24, frame: frame),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey[400] : (index == 2 ? Colors.brown[300] : Colors.blue[100])),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: index < 3 ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text('$name (Lv.$level)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  if (title.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber[800]!, width: 0.8),
                                      ),
                                      child: Text(title, style: TextStyle(fontSize: 10, color: Colors.amber[900], fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              subtitle: Text('$score แต้ม • ❤️ $hearts', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isMe && enemyPet != null)
                                    IconButton(
                                      icon: const Icon(Icons.sports_kabaddi, color: Colors.deepOrange, size: 24),
                                      tooltip: 'ท้าดวลสัตว์เลี้ยง (PvP)',
                                      onPressed: () => _startPetBattle(docId, name, enemyPet),
                                    ),
                                  IconButton(
                                    icon: Icon(isMe ? Icons.favorite : Icons.favorite_border, color: Colors.pink),
                                    onPressed: isMe ? null : () => _sendHeartToUser(docId, name),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // แท็บ 2: สัตว์เลี้ยง
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 4,
                      color: Colors.orange[50],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.orange[300]!, width: 1.5)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            PetCharacter3DWidget(
                              petType: petType,
                              equippedWeapon: petWeapon,
                              equippedHat: petHat,
                              size: 190,
                              showHeartEffect: _showHeart,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$petName (Lv.$petLevel)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.deepOrange),
                                  tooltip: 'เปลี่ยนชื่อ / ชนิดสัตว์เลี้ยง',
                                  onPressed: _showEditPetCustomizationDialog,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: petExp / 100.0,
                                minHeight: 8,
                                backgroundColor: Colors.orange[100],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('EXP: $petExp/100', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('⚔️ ATK รวม: $totalAtk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                                    Text('(พื้นฐาน $baseAtk + ไอเทม $bonusAtk)', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('❤️ HP: $currentHp / $totalMaxHp', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                                    const Text('พลังชีวิตปัจจุบัน', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Text('🗡️ อาวุธที่ใส่: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Expanded(child: Text(petWeapon.isEmpty ? 'ไม่มี' : petWeapon, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      if (petWeapon != 'ไม่มี' && petWeapon.isNotEmpty)
                                        TextButton(
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 20)),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({'pet.equippedWeapon': 'ไม่มี'});
                                            setState(() => globalUserPet['equippedWeapon'] = 'ไม่มี');
                                          },
                                          child: const Text('ถอด', style: TextStyle(color: Colors.red, fontSize: 11)),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 8),
                                  Row(
                                    children: [
                                      const Text('🎩 หมวก/ประดับ: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Expanded(child: Text(petHat.isEmpty ? 'ไม่มี' : petHat, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      if (petHat != 'ไม่มี' && petHat.isNotEmpty)
                                        TextButton(
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 20)),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({'pet.equippedHat': 'ไม่มี'});
                                            setState(() => globalUserPet['equippedHat'] = 'ไม่มี');
                                          },
                                          child: const Text('ถอด', style: TextStyle(color: Colors.red, fontSize: 11)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _feedPet,
                                icon: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                                label: const Text('ให้อาหารสัตว์เลี้ยง (ใช้ 50 แต้ม +20 EXP +10 HP)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🏆 Pet Level Leaderboard (เรียงลำดับตามเลเวลสัตว์เลี้ยงจากมากไปน้อย)
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.leaderboard, color: Colors.deepOrange, size: 22),
                                SizedBox(width: 8),
                                Text('🏆 อันดับเลเวลสัตว์เลี้ยง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const Divider(height: 16),
                            SizedBox(
                              height: 140,
                              child: Builder(
                                builder: (context) {
                                  final sortedUsersByPetLevel = List<QueryDocumentSnapshot>.from(users);
                                  sortedUsersByPetLevel.sort((a, b) {
                                    final pMapA = (a.data() as Map<String, dynamic>)['pet'] is Map ? (a.data() as Map<String, dynamic>)['pet'] as Map<String, dynamic> : {};
                                    final pMapB = (b.data() as Map<String, dynamic>)['pet'] is Map ? (b.data() as Map<String, dynamic>)['pet'] as Map<String, dynamic> : {};
                                    final int lvlA = (pMapA['level'] is num) ? (pMapA['level'] as num).toInt() : 1;
                                    final int lvlB = (pMapB['level'] is num) ? (pMapB['level'] as num).toInt() : 1;
                                    return lvlB.compareTo(lvlA);
                                  });

                                  return ListView.builder(
                                    itemCount: sortedUsersByPetLevel.length,
                                    itemBuilder: (context, idx) {
                                      final uData = sortedUsersByPetLevel[idx].data() as Map<String, dynamic>;
                                      final uName = uData['name'] ?? 'Staff';
                                      final pMap = uData['pet'] is Map ? uData['pet'] as Map<String, dynamic> : {};
                                      final pType = pMap['type'] ?? '🐱';
                                      final pName = pMap['name'] ?? 'สัตว์เลี้ยง';
                                      final pLvl = (pMap['level'] is num) ? (pMap['level'] as num).toInt() : 1;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Text('${idx + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                                                Text('$pType $pName ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                Text('($uName)', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                                              child: Text('Lv.$pLvl', style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white24,
                              child: Text('🎰', style: TextStyle(fontSize: 28)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('ตู้กาชาไอเทมสัตว์เลี้ยง 🐾', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                  SizedBox(height: 2),
                                  Text('สุ่มรับอาวุธ & หมวกเทพ 16 แบบ (+15 ถึง +100 พลัง)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: _spinPetGacha,
                              child: const Text('สุ่ม 50 แต้ม', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text('🎒 คลังไอเทมสวมใส่ของคุณ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (globalPetInventory.isEmpty)
                      const Text('ยังไม่มีไอเทม (กดสุ่มได้จากตู้กาชาด้านบน)', style: TextStyle(color: Colors.grey, fontSize: 13))
                    else
                      ...globalPetInventory.map((item) {
                        final isEquipped = (petWeapon == item || petHat == item);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isEquipped ? Colors.amber[50] : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isEquipped ? Colors.amber[700]! : Colors.grey[300]!),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(item.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEquipped ? Colors.green[600] : Colors.blue[900],
                                minimumSize: const Size(60, 28),
                              ),
                              onPressed: () async {
                                final isWeapon = item.toString().contains('ATK');
                                final updateKey = isWeapon ? 'equippedWeapon' : 'equippedHat';
                                final newEquip = isEquipped ? 'ไม่มี' : item.toString();

                                await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
                                  'pet.$updateKey': newEquip,
                                });
                                setState(() => globalUserPet[updateKey] = newEquip);
                              },
                              child: Text(isEquipped ? 'ใช้งานอยู่' : 'สวมใส่', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }),
                  ],
                ),

                // แท็บ 3: ร้านค้า & วงล้อ
                ListView(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber[300]!, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('คะแนนสะสมของคุณ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('🛡️ โล่ป้องกัน: $globalUserShields ชิ้น', style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('$myCurrentScore แต้ม', style: TextStyle(fontSize: 20, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Text('🎰', style: TextStyle(fontSize: 30)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Lucky Wheel 2 ตู้เสี่ยงโชค', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 4),
                                  Text('ตู้ Standard (20 แต้ม) หรือตู้ VIP (100 แต้ม) ลุ้น Jackpot 2,000 แต้ม!', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () => _openLuckyWheelDialog(myCurrentScore),
                              child: const Text('หมุนเลย', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Text('📦', style: TextStyle(fontSize: 30)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('ซองการ์ด Celestial Meow ✨', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 4),
                                  Text('เปิดซองสุ่มการ์ดแมวอวกาศ 3 ใบ (ราคา 200 แต้ม)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () => _openCardPackDialog(myCurrentScore),
                              child: const Text('เปิดซอง', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.purple[700]!, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _openCardInventoryDialog,
                      icon: const Icon(Icons.style, color: Colors.purple),
                      label: Text('🖼️ ดูคลังการ์ดสะสมของคุณ (${globalCardInventory.length} ใบ)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[900], fontSize: 15)),
                    ),
                    const SizedBox(height: 20),

                    const Text('🖼️ กรอบโปรไฟล์ในคลัง & โอกาสสุ่มได้ (12 แบบ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('นีออน 💎', 'neon')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('ทองคำ 👑', 'gold')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('สีรุ้ง 🌈', 'rainbow')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('เปลวไฟ 🔥', 'fire')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('น้ำแข็ง ❄️', 'ice')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('Challenger ⚡', 'challenger')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('สีเงิน 🥈', 'silver')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('สายลม 🍃', 'wind')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('ธาตุมืด 🌑', 'dark')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('มีปีก 🪽', 'wing')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('ออร่า 🔮', 'aura')),
                        SizedBox(width: (MediaQuery.of(context).size.width - 56) / 3, child: _buildFrameCard('วิ้งๆ ✨', 'sparkle')),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text('🎖️ ฉายา & คลังฉายา', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    _buildTitleItem('นักอัปเดตโต๊ะ 🥉', 100, myCurrentScore),
                    _buildTitleItem('นักอัปเดตโต๊ะจอมซน 😼', 300, myCurrentScore),
                    _buildTitleItem('ยอดอัพเดตโต๊ะ 🥈', 500, myCurrentScore),
                    _buildTitleItem('ท่านเทพอัพเดตโต๊ะ 🥇', 700, myCurrentScore),
                    _buildTitleItem('GMจอมขยัน 👑', 1000, myCurrentScore),
                    if (globalUnlockedTitles.contains('ไร้พ่าย No.1')) _buildTitleItem('👑 ไร้พ่าย No.1', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('มหาเศรษฐีตัวจริง')) _buildTitleItem('💰 มหาเศรษฐีตัวจริง', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('เทพแห่งดวงดาว 🌌')) _buildTitleItem('🌌 เทพแห่งดวงดาว', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('พนักงานระดับตำนาน 🌟')) _buildTitleItem('🌟 พนักงานระดับตำนาน', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('ราชาเกลือ VIP 🧂')) _buildTitleItem('🧂 ราชาเกลือ VIP', 0, myCurrentScore),
                  ],
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openChatBottomSheet,
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          child: const Icon(Icons.chat_bubble, size: 26),
        ),
      ),
    );
  }

  Widget _buildFrameCard(String label, String frameType) {
    final bool isOwned = globalUnlockedFrames.contains(frameType);
    final bool isEquipped = globalUserFrame == frameType;

    return Card(
      color: isEquipped ? Colors.blue[50] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isEquipped ? Colors.blue[900]! : Colors.grey[300]!, width: isEquipped ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            buildUserAvatarWidget(globalUserAvatar, radius: 18, fontSize: 18, frame: isOwned ? frameType : ''),
            const SizedBox(height: 8),
            if (!isOwned)
              const Text('(จากวงล้อ)', style: TextStyle(fontSize: 10, color: Colors.grey))
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEquipped ? Colors.red[400] : Colors.blue[900],
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(60, 28),
                ),
                onPressed: () => _equipOrUnequipFrame(frameType),
                child: Text(isEquipped ? 'ถอด' : 'ใช้', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleItem(String title, int requiredScore, int currentScore) {
    final bool isOwned = globalUnlockedTitles.contains(title);
    final bool isEquipped = globalUserTitle == title;
    final bool canClaim = currentScore >= requiredScore;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isEquipped ? Colors.amber[800]! : Colors.transparent, width: isEquipped ? 2 : 0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  isOwned ? 'ปลดล็อกแล้ว (อยู่ในคลัง)' : 'เงื่อนไข: $requiredScore แต้ม',
                  style: TextStyle(fontSize: 13, color: isOwned ? Colors.green[700] : Colors.grey),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEquipped ? Colors.green[600] : (isOwned ? Colors.blue[900] : (canClaim ? Colors.amber[700] : Colors.grey[400])),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: (!isOwned && !canClaim) ? null : () => _claimOrEquipTitle(currentScore, requiredScore, title),
              child: Text(
                isEquipped ? 'ใช้งานอยู่ (แตะเพื่อถอด)' : (isOwned ? 'เลือกใช้' : 'แลกฉายา'),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TeamChatBottomSheet
// ==========================================
class TeamChatBottomSheet extends StatefulWidget {
  const TeamChatBottomSheet({super.key});

  @override
  State<TeamChatBottomSheet> createState() => _TeamChatBottomSheetState();
}

class _TeamChatBottomSheetState extends State<TeamChatBottomSheet> {
  final TextEditingController _msgController = TextEditingController();

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isNotEmpty && globalUserId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('chat_messages').add({
        'senderId': globalUserId,
        'senderName': globalUserName,
        'senderAvatar': globalUserAvatar,
        'senderTitle': globalUserTitle,
        'message': text,
        'timestamp': Timestamp.now(),
      });
      _msgController.clear();

      await recordCustomDailyQuest('hasChattedToday', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber[700],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('ห้องแชททีม 💬', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chat_messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อความ'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('ยังไม่มีข้อความ เริ่มคุยกันเลย!', style: TextStyle(color: Colors.grey, fontSize: 16)));
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == globalUserId;
                  final senderName = data['senderName'] ?? 'Unknown';
                  final senderAvatar = data['senderAvatar'] ?? '🐱';
                  final senderTitle = data['senderTitle'] ?? '';
                  final message = data['message'] ?? '';
                  final Timestamp? ts = data['timestamp'];

                  String timeStr = '';
                  if (ts != null) {
                    final dt = ts.toDate();
                    final h = dt.hour.toString().padLeft(2, '0');
                    final m = dt.minute.toString().padLeft(2, '0');
                    timeStr = '$h:$m น.';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          buildUserAvatarWidget(senderAvatar, radius: 16, fontSize: 16, frame: globalUserFrame),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                Text(
                                  senderTitle.isNotEmpty ? '$senderName [$senderTitle]' : senderName,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.amber[700] : Colors.grey[200],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 16),
                                  ),
                                ),
                                child: Text(
                                  message,
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          buildUserAvatarWidget(senderAvatar, radius: 16, fontSize: 16, frame: globalUserFrame),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความสั้นๆ...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.amber[700],
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}