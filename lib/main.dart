import 'dart:io';
import 'dart:async';
import 'dart:math';
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
String globalUserFrame = ''; // 'gold', 'neon', 'rainbow', 'fire', 'ice', ''
List<String> globalUnlockedTitles = [];
List<String> globalUnlockedFrames = [];
Timestamp? globalBuffX2Until;
int globalUserLevel = 1;
int globalUserUpdateCount = 0;
int globalUserScore = 0;
int globalUserHearts = 0;
int globalUserShields = 0;
Map<String, dynamic> globalLastHeartSent = {};

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

// Widget สำหรับแสดงผลรูปโปรไฟล์ (รองรับ นีออน / ทอง / สีรุ้ง / เปลวไฟ / น้ำแข็ง)
Widget buildUserAvatarWidget(String avatar, {double radius = 24, double fontSize = 24, String frame = ''}) {
  bool isUrl = avatar.startsWith('http://') || avatar.startsWith('https://');
  
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
  }

  Widget circle = CircleAvatar(
    radius: radius,
    backgroundColor: Colors.blue[50],
    backgroundImage: isUrl ? NetworkImage(avatar) : null,
    child: !isUrl ? Text(avatar, style: TextStyle(fontSize: fontSize)) : null,
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

// ระบบบันทึกคลิก: ครบ 100 คลิก เลเวลอัปและรับโบนัส +50 แต้ม (บัฟ x2 ได้ +100 แต้ม) พร้อมบันทึก Daily Quest 1
Future<void> registerUserUpdateAction(BuildContext? context) async {
  final user = FirebaseAuth.instance.currentUser;
  final currentUid = user?.uid ?? globalUserId;
  if (currentUid.isEmpty) {
    debugPrint('⚠️ ไม่พบ User ID สำหรับบันทึกแต้ม');
    return;
  }
  globalUserId = currentUid;

  final userDocRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
  final today = getTodayKey();

  try {
    bool isBuffActive = globalBuffX2Until != null && globalBuffX2Until!.toDate().isAfter(DateTime.now());

    globalUserUpdateCount += 1;

    int gainedLevels = 0;
    int bonusScore = 0;

    if (globalUserUpdateCount >= 100) {
      gainedLevels = globalUserUpdateCount ~/ 100;
      globalUserUpdateCount = globalUserUpdateCount % 100;
      globalUserLevel += gainedLevels;

      int baseBonus = 50;
      bonusScore = isBuffActive ? (baseBonus * 2 * gainedLevels) : (baseBonus * gainedLevels);
      globalUserScore += bonusScore;
    }

    Map<String, dynamic> updateData = {
      'updateCount': FieldValue.increment(1),
      'dailyQuests.$today.tableUpdates': FieldValue.increment(1),
    };

    if (gainedLevels > 0) {
      updateData['level'] = FieldValue.increment(gainedLevels);
      updateData['score'] = FieldValue.increment(bonusScore);
      updateData['updateCount'] = globalUserUpdateCount;
    }

    await userDocRef.set(updateData, SetOptions(merge: true));

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
    debugPrint('เกิดข้อผิดพลาดในการบันทึกเลเวล: $e');
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
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 80);
    if (picked != null) {
      setState(() {
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

        if (_pickedImageFile != null) {
          final ref = FirebaseStorage.instance.ref().child('user_avatars').child('$uid.jpg');
          await ref.putFile(_pickedImageFile!);
          finalAvatar = await ref.getDownloadURL();
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
          'buffX2Until': null,
          'email': email,
          'streakCount': 0,
          'lastCheckInDate': '',
          'dailyQuests': {},
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
                          backgroundImage: _pickedImageFile != null ? FileImage(_pickedImageFile!) : null,
                          child: _pickedImageFile == null
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
                              final isSelected = avatar == _selectedAvatar && _pickedImageFile == null;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedAvatar = avatar;
                                  _pickedImageFile = null;
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
                          newPickedFile != null
                              ? Container(
                                  decoration: selectedFrame == 'gold'
                                      ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber[600]!, width: 3))
                                      : selectedFrame == 'neon'
                                          ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.cyanAccent, width: 3))
                                          : selectedFrame == 'rainbow'
                                              ? const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: SweepGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red]),
                                                )
                                              : selectedFrame == 'fire'
                                                  ? const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: LinearGradient(colors: [Colors.deepOrange, Colors.orangeAccent, Colors.redAccent]),
                                                    )
                                                  : selectedFrame == 'ice'
                                                      ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.lightBlueAccent, width: 3))
                                                      : null,
                                  padding: const EdgeInsets.all(3),
                                  child: CircleAvatar(radius: 28, backgroundImage: FileImage(newPickedFile!)),
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
                                      maxWidth: 500,
                                      maxHeight: 500,
                                      imageQuality: 80,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
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
                                final isSelected = avatar == selectedAvatar && newPickedFile == null;
                                return GestureDetector(
                                  onTap: isSaving
                                      ? null
                                      : () => setDialogState(() {
                                            selectedAvatar = avatar;
                                            newPickedFile = null;
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
                              onSelected: (selected) {
                                setDialogState(() => selectedFrame = selected ? 'neon' : '');
                              },
                            ),
                          if (globalUnlockedFrames.contains('gold'))
                            ChoiceChip(
                              label: const Text('👑 ทองคำ'),
                              selected: selectedFrame == 'gold',
                              selectedColor: Colors.amber[100],
                              onSelected: (selected) {
                                setDialogState(() => selectedFrame = selected ? 'gold' : '');
                              },
                            ),
                          if (globalUnlockedFrames.contains('rainbow'))
                            ChoiceChip(
                              label: const Text('🌈 สีรุ้ง'),
                              selected: selectedFrame == 'rainbow',
                              selectedColor: Colors.purple[100],
                              onSelected: (selected) {
                                setDialogState(() => selectedFrame = selected ? 'rainbow' : '');
                              },
                            ),
                          if (globalUnlockedFrames.contains('fire'))
                            ChoiceChip(
                              label: const Text('🔥 เปลวไฟ'),
                              selected: selectedFrame == 'fire',
                              selectedColor: Colors.deepOrange[100],
                              onSelected: (selected) {
                                setDialogState(() => selectedFrame = selected ? 'fire' : '');
                              },
                            ),
                          if (globalUnlockedFrames.contains('ice'))
                            ChoiceChip(
                              label: const Text('❄️ น้ำแข็ง'),
                              selected: selectedFrame == 'ice',
                              selectedColor: Colors.lightBlue[100],
                              onSelected: (selected) {
                                setDialogState(() => selectedFrame = selected ? 'ice' : '');
                              },
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
                                      onSelected: (selected) {
                                        setDialogState(() => selectedTitle = selected ? t : '');
                                      },
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

                            if (newPickedFile != null) {
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('user_avatars')
                                  .child('$globalUserId.jpg');
                              await ref.putFile(newPickedFile!);
                              finalAvatar = await ref.getDownloadURL();
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
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard & Shop'),
        ],
      ),
    );
  }
}

// ==========================================
// DailyQuestsScreen (กล่องสุ่ม 10-60 แต้ม)
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

    // ปรับกล่องสุ่มแต้มล็อกอินเป็น 10 ถึง 60 แต้ม
    final random = Random();
    final int mysteryPoints = 10 + random.nextInt(51); // 10 ถึง 60 แต้ม
    int totalGainedPoints = mysteryPoints;

    if (streakCount == 7) {
      totalGainedPoints += 100;
    }

    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(globalUserId);

    batch.update(userRef, {
      'streakCount': streakCount,
      'lastCheckInDate': todayKey,
      'score': FieldValue.increment(totalGainedPoints),
    });

    final firstCheckInDoc = await FirebaseFirestore.instance.collection('app_settings').doc('first_checkin_$todayKey').get();
    bool isFirstCheckInToday = false;
    if (!firstCheckInDoc.exists) {
      isFirstCheckInToday = true;
      batch.set(FirebaseFirestore.instance.collection('app_settings').doc('first_checkin_$todayKey'), {
        'userId': globalUserId,
        'userName': globalUserName,
        'time': Timestamp.now(),
      });
      batch.set(userRef, {
        'dailyQuests.$todayKey.isFirstCheckIn': true,
      }, SetOptions(merge: true));
    }

    await batch.commit();

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
                const Text('🏆 คุณเป็นคนแรกของวัน! (สำเร็จเควส 4 แล้ว)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
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

    await userRef.set({
      'score': FieldValue.increment(rewardScore),
      'dailyQuests.$todayKey.claimed_$questKey': true,
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

          final dailyQuestsMap = (userData['dailyQuests'] != null && userData['dailyQuests'][todayKey] != null)
              ? Map<String, dynamic>.from(userData['dailyQuests'][todayKey])
              : <String, dynamic>{};

          final int tableUpdates = (dailyQuestsMap['tableUpdates'] is num) ? (dailyQuestsMap['tableUpdates'] as num).toInt() : 0;
          final List<dynamic> heartSentUsers = List.from(dailyQuestsMap['heartSentUsers'] ?? []);
          final int heartSentTotal = (dailyQuestsMap['heartSentTotal'] is num) ? (dailyQuestsMap['heartSentTotal'] as num).toInt() : 0;
          final bool isFirstCheckIn = dailyQuestsMap['isFirstCheckIn'] == true;

          final bool q1Claimed = dailyQuestsMap['claimed_q1'] == true;
          final bool q2Claimed = dailyQuestsMap['claimed_q2'] == true;
          final bool q3Claimed = dailyQuestsMap['claimed_q3'] == true;
          final bool q4Claimed = dailyQuestsMap['claimed_q4'] == true;

          final bool q1Completed = tableUpdates >= 30;
          final bool q2Completed = heartSentUsers.length >= 5;
          final bool q3Completed = heartSentTotal >= 20;
          final bool q4Completed = isFirstCheckIn;

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
                title: 'เควส 1: อัปเดตโต๊ะครบ 30 ครั้ง',
                subtitle: 'อัปเดตสถานะโต๊ะในร้าน ($tableUpdates/30)',
                progress: min(1.0, tableUpdates / 30.0),
                rewardText: '+10 แต้ม',
                rewardScore: 10,
                isCompleted: q1Completed,
                isClaimed: q1Claimed,
                onClaim: () => _claimQuestReward('q1', 10),
              ),

              _buildQuestCard(
                title: 'เควส 2: ส่งกำลังใจให้เพื่อนครบ 5 คน',
                subtitle: 'ส่งหัวใจให้เพื่อนไม่ซ้ำคน (${heartSentUsers.length}/5)',
                progress: min(1.0, heartSentUsers.length / 5.0),
                rewardText: '+5 แต้ม',
                rewardScore: 5,
                isCompleted: q2Completed,
                isClaimed: q2Claimed,
                onClaim: () => _claimQuestReward('q2', 5),
              ),

              _buildQuestCard(
                title: 'เควส 3: ส่งกำลังใจให้เพื่อนครบ 20 ครั้ง',
                subtitle: 'ส่งหัวใจรวมทั้งหมดในวันนี้ ($heartSentTotal/20)',
                progress: min(1.0, heartSentTotal / 20.0),
                rewardText: '+5 แต้ม',
                rewardScore: 5,
                isCompleted: q3Completed,
                isClaimed: q3Claimed,
                onClaim: () => _claimQuestReward('q3', 5),
              ),

              _buildQuestCard(
                title: 'เควส 4: เช็กชื่อคนแรกของวัน 🏆',
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
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
// TableStatusScreen (พร้อม Mini Banner ประกาศข้างปุ่มดูโต๊ะว่างบน AppBar)
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
              const SizedBox(width: 8),
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
        registerUserUpdateAction(context);
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
        registerUserUpdateAction(context);
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
                    registerUserUpdateAction(context);
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
                  // 1. ส่วนแสดงผลชื่อแอปและสถิติส่วนตัว (เลเวล, หลอดคลิก, แต้ม, หัวใจ)
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

                  // 2. Mini Banner ประกาศสำคัญประจำวัน (วางข้างปุ่มดูโต๊ะว่างบน AppBar)
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

                  // เมนูเปิดหน้า Daily Quests & Mystery Box
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
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
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
                    registerUserUpdateAction(context);
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
class FloorPlanCard extends StatelessWidget {
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

  bool get _isMergeableTable {
    return collectionName == 'tables_f1' &&
        (expectedName == 'โต๊ะ 1' ||
            expectedName == 'โต๊ะ 2' ||
            expectedName == 'โต๊ะ 3' ||
            expectedName == 'โต๊ะ 4' ||
            expectedName == 'โต๊ะ 5');
  }

  bool get _hasQueueSystem {
    return expectedName.contains('พูล') || expectedName == 'ห้องกระจก';
  }

  void _showMergeDialog(BuildContext context, String currentDocId, String currentName) {
    const mergeableNames = ['โต๊ะ 1', 'โต๊ะ 2', 'โต๊ะ 3', 'โต๊ะ 4', 'โต๊ะ 5'];
    
    final otherAvailableTables = <Map<String, dynamic>>[];
    for (var doc in docs) {
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
                            FirebaseFirestore.instance.collection(collectionName).doc(currentDocId),
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
                              FirebaseFirestore.instance.collection(collectionName).doc(docId),
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
                            registerUserUpdateAction(context);
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
          .collection(collectionName)
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
        registerUserUpdateAction(context);
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
          .collection(collectionName)
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
      if (context.mounted) registerUserUpdateAction(context);
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
                  onDelete(docId, tableName);
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
    final bool isGlassRoom = expectedName == 'ห้องกระจก';

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
                  Text('คิวรอใช้งาน: $expectedName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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

                                    await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                                      'waitingQueue': queueList,
                                      'lastUpdated': Timestamp.now(),
                                    });
                                    if (context.mounted) registerUserUpdateAction(context);
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

                                    await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                                      'waitingQueue': queueList,
                                      'lastUpdated': Timestamp.now(),
                                    });
                                    if (context.mounted) registerUserUpdateAction(context);
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
    for (var doc in docs) {
      if ((doc.data() as Map<String, dynamic>)['name'] == expectedName) {
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
        shape: isCircle
            ? const CircleBorder(side: BorderSide(color: Colors.grey, width: 2, style: BorderStyle.solid))
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.grey, width: 2)),
        child: InkWell(
          customBorder: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () async {
            registerUserUpdateAction(context);
            try {
              await FirebaseFirestore.instance.collection(collectionName).add({
                'name': expectedName,
                'isAvailable': true,
                'lastUpdated': Timestamp.now(),
                'updatedBy': userDisplayName,
                'waitingQueue': [],
              });
            } catch (e) {
              debugPrint('Create table error: $e');
            }
          },
          child: Center(
            child: Text('$expectedName\n(แตะเพื่อสร้าง)', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
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

    if (onlyAvailable && !isAvailable) {
      return Opacity(
        opacity: 0.25,
        child: Card(
          color: Colors.grey[200],
          shape: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(expectedName, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        ),
      );
    }

    if (searchQuery.isNotEmpty && !expectedName.toLowerCase().contains(searchQuery.toLowerCase())) {
      return Opacity(
        opacity: 0.2,
        child: Card(
          color: Colors.grey[200],
          shape: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(expectedName, style: const TextStyle(color: Colors.grey))),
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
      shape: isCircle
          ? CircleBorder(side: BorderSide(color: isAvailable ? Colors.green : Colors.red, width: 2))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: mergedGroupId != null ? Colors.blue[900]! : (isAvailable ? Colors.green : Colors.red),
                width: mergedGroupId != null ? 2.5 : 2,
              ),
            ),
      child: InkWell(
        customBorder: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () async {
          registerUserUpdateAction(context);

          try {
            if (mergedGroupId != null) {
              await _toggleMergedGroupAvailability(context, mergedGroupId, isAvailable);
            } else {
              await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                'isAvailable': !isAvailable,
                'lastUpdated': Timestamp.now(),
                'updatedBy': userDisplayName,
              });
            }
          } catch (e) {
            debugPrint('Error updating table: $e');
          }
        },
        onLongPress: () {
          if (_isMergeableTable) {
            _showTableOptionsBottomSheet(context, docId, expectedName, mergedGroupId);
          } else {
            onDelete(docId, expectedName);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCircle ? 16.0 : 8.0, vertical: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    expectedName,
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

// ==========================================
// แผนผังชั้น 1
// ==========================================
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
// Lucky Wheel Dialog & Painter (14 ช่องรางวัลครบตามสั่ง + ระบบสุ่มซ้อน + โล่กันแต้ม)
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
  final String type; // 'jackpot', 'sub_frame', 'shield', 'sub_title', 'buff', 'free_spin', 'bonus', 'salt', 'penalty', 'mystery_key'
  final dynamic value;

  const _WheelReward(this.label, this.shortText, this.color, this.type, this.value);
}

class _LuckyWheelDialogState extends State<LuckyWheelDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  double _currentAngle = 0.0;
  String? _resultText;

  // 14 ช่องรางวัลตามที่กำหนด
  final List<_WheelReward> rewards = const [
    _WheelReward('JACKPOT +500 แต้ม! 💥', '+500 💥', Color(0xFFFF1493), 'jackpot', 500),
    _WheelReward('กรอบโปรไฟล์ (สุ่ม) 🖼️', 'กรอบ 🖼️', Colors.deepPurple, 'sub_frame', null),
    _WheelReward('โล่กันแต้มลด 🛡️', 'โล่ 🛡️', Colors.blueAccent, 'shield', 1),
    _WheelReward('ฉายาลับใหม่ (สุ่ม) ⭐', 'ฉายา ⭐', Colors.purpleAccent, 'sub_title', null),
    _WheelReward('บัฟแต้ม x2 (30 นาที) 🔥', 'บัฟ x2', Colors.deepOrange, 'buff', 30),
    _WheelReward('ตั๋วหมุนฟรี 🎟️', 'หมุนฟรี 🎟️', Colors.teal, 'free_spin', 20),
    _WheelReward('โบนัส +100 แต้ม ✨', '+100 ✨', Colors.amber, 'bonus', 100),
    _WheelReward('โบนัส +20 แต้ม 🌟', '+20 🌟', Colors.orangeAccent, 'bonus', 20),
    _WheelReward('โบนัส +10 แต้ม 🌟', '+10 🌟', Colors.amberAccent, 'bonus', 10),
    _WheelReward('เกลือ 🧂', 'เกลือ 🧂', Colors.grey, 'salt', 0),
    _WheelReward('แย่แล้ว! -2 แต้ม 🔻', '-2 🔻', Color(0xFFEF5350), 'penalty', -2),
    _WheelReward('แย่แล้ว! -6 แต้ม 🔻', '-6 🔻', Color(0xFFE53935), 'penalty', -6),
    _WheelReward('แย่แล้ว! -10 แต้ม 🔻', '-10 🔻', Color(0xFFC62828), 'penalty', -10),
    _WheelReward('กุญแจกล่องสุ่ม (50-200 แต้ม) 🎁', 'กล่องสุ่ม 🎁', Color(0xFF9C27B0), 'mystery_key', null),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_isSpinning) return;
    if (globalUserScore < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณต้องการคะแนนอย่างน้อย 20 แต้มเพื่อหมุนวงล้อ')),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _resultText = null;
    });

    int newScore = globalUserScore - 20;
    await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({'score': newScore});
    globalUserScore = newScore;

    final random = Random();
    final targetIndex = random.nextInt(rewards.length);
    final sectionAngle = (2 * pi) / rewards.length;
    
    final targetSectorAngle = (3 * pi / 2) - (targetIndex * sectionAngle + sectionAngle / 2);
    final totalRotation = (5 * 2 * pi) + targetSectorAngle;

    _animation = Tween<double>(begin: _currentAngle, end: _currentAngle + totalRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.reset();
    _controller.forward().then((_) async {
      final reward = rewards[targetIndex];
      _currentAngle = (_currentAngle + totalRotation) % (2 * pi);

      final userDoc = FirebaseFirestore.instance.collection('users').doc(globalUserId);
      final updateData = <String, dynamic>{};
      String finalRewardLabel = reward.label;

      if (reward.type == 'jackpot' || reward.type == 'bonus' || reward.type == 'free_spin') {
        int finalScore = max(0, globalUserScore + (reward.value as int));
        updateData['score'] = finalScore;
        globalUserScore = finalScore;
      } else if (reward.type == 'shield') {
        globalUserShields += 1;
        updateData['shields'] = FieldValue.increment(1);
        finalRewardLabel = 'โล่กันแต้มลด 🛡️ (+1 ชิ้นในคลัง)';
      } else if (reward.type == 'sub_frame') {
        // สุ่มย่อยกรอบ: นีออน, ทอง, สีรุ้ง, เปลวไฟ, น้ำแข็ง
        final subFrames = ['neon', 'gold', 'rainbow', 'fire', 'ice'];
        final subFrameNames = {
          'neon': 'กรอบนีออน 💎',
          'gold': 'กรอบทองคำ 👑',
          'rainbow': 'กรอบสีรุ้ง 🌈',
          'fire': 'กรอบเปลวไฟ 🔥',
          'ice': 'กรอบน้ำแข็ง ❄️',
        };
        final pickedFrame = subFrames[random.nextInt(subFrames.length)];
        final frameName = subFrameNames[pickedFrame]!;
        
        updateData['frame'] = pickedFrame;
        updateData['unlockedFrames'] = FieldValue.arrayUnion([pickedFrame]);
        globalUserFrame = pickedFrame;
        if (!globalUnlockedFrames.contains(pickedFrame)) globalUnlockedFrames.add(pickedFrame);
        finalRewardLabel = 'สุ่มได้: $frameName';
      } else if (reward.type == 'sub_title') {
        // สุ่มย่อยฉายา
        final subTitles = [
          'ราชาเกลือแห่งปี 🧂',
          'เซียนพูลหน้ามน 🎱',
          'ทาสแมวตัวจริง 🐾',
          'พนักงานดีเด่น ☕',
          'ดวงดีจัดๆ ⭐',
          'นักเสี่ยงดวงแห่งปี 🎰',
        ];
        final pickedTitle = subTitles[random.nextInt(subTitles.length)];
        
        updateData['title'] = pickedTitle;
        updateData['unlockedTitles'] = FieldValue.arrayUnion([pickedTitle]);
        globalUserTitle = pickedTitle;
        if (!globalUnlockedTitles.contains(pickedTitle)) globalUnlockedTitles.add(pickedTitle);
        finalRewardLabel = 'สุ่มได้ฉายา: "$pickedTitle"';
      } else if (reward.type == 'mystery_key') {
        // สุ่มแต้ม 50 - 200 แต้ม
        final gained = 50 + random.nextInt(151);
        int finalScore = globalUserScore + gained;
        updateData['score'] = finalScore;
        globalUserScore = finalScore;
        finalRewardLabel = 'กุญแจกล่องสุ่ม 🎁 เปิดได้ +$gained แต้ม!';
      } else if (reward.type == 'penalty') {
        // ตรวจสอบโล่ป้องกัน
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

      if (updateData.isNotEmpty) {
        await userDoc.update(updateData);
      }

      // บันทึกลงประวัติการสุ่ม
      await FirebaseFirestore.instance.collection('wheel_history').add({
        'userName': globalUserName,
        'userAvatar': globalUserAvatar,
        'rewardLabel': finalRewardLabel,
        'rewardType': reward.type,
        'timestamp': Timestamp.now(),
      });

      if (mounted) {
        setState(() {
          _isSpinning = false;
          _resultText = finalRewardLabel;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          const Text('🎰 Lucky Wheel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.purple)),
          Text('แต้มของคุณ: $globalUserScore แต้ม (ใช้ 20 แต้ม) • 🛡️ โล่: $globalUserShields', style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
        ],
      ),
      content: SizedBox(
        width: 330,
        height: 490,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final angle = _isSpinning ? _animation.value : _currentAngle;
                    return Transform.rotate(
                      angle: angle,
                      child: CustomPaint(
                        size: const Size(220, 220),
                        painter: _WheelPainter(rewards: rewards),
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
                    child: const Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 40),
                  ),
                ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.stars, color: Colors.amber[700], size: 26),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_resultText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple),
                ),
                child: Text(
                  '🎉 ผลลัพธ์: $_resultText',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
                ),
              )
            else
              const Text('แตะปุ่มด้านล่างเพื่อเริ่มหมุนวงล้อ 14 รางวัล!', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 6),
            
            Row(
              children: const [
                Icon(Icons.history, size: 16, color: Colors.purple),
                SizedBox(width: 4),
                Text('ประวัติการสุ่มล่าสุด 📜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('wheel_history').orderBy('timestamp', descending: true).limit(10).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('ไม่สามารถโหลดประวัติได้', style: TextStyle(fontSize: 11)));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('ยังไม่มีประวัติการสุ่ม', style: TextStyle(fontSize: 11, color: Colors.grey)));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final item = docs[index].data() as Map<String, dynamic>;
                      final uName = item['userName'] ?? 'Unknown';
                      final rLabel = item['rewardLabel'] ?? '-';
                      final rType = item['rewardType'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          children: [
                            Text('• ', style: TextStyle(color: Colors.purple[300], fontWeight: FontWeight.bold)),
                            Text('$uName: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Expanded(
                              child: Text(
                                rLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (rType == 'jackpot' || rLabel.contains('500') || rLabel.contains('กล่องสุ่ม')) 
                                      ? Colors.red[700] 
                                      : (rType == 'penalty' ? Colors.red : Colors.black87),
                                  fontWeight: rLabel.contains('500') || rType == 'sub_title' || rType == 'sub_frame' ? FontWeight.bold : FontWeight.normal,
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
            backgroundColor: Colors.purple[700],
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: _isSpinning ? null : _spin,
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: Text(
            _isSpinning ? 'กำลังหมุน...' : 'หมุนเลย (20 แต้ม)',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius * 0.40, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
      await targetUserRef.update({
        'hearts': FieldValue.increment(1),
      });

      final currentTimestamp = Timestamp.now();
      await myUserRef.set({
        'score': FieldValue.increment(1),
        'lastHeartSent.$targetDocId': currentTimestamp,
        'dailyQuests.$today.heartSentUsers': FieldValue.arrayUnion([targetDocId]),
        'dailyQuests.$today.heartSentTotal': FieldValue.increment(1),
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

  void _deleteUserProfileDialog(String docId, String userName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('ลบโปรไฟล์ "$userName" ?', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('คุณต้องการลบโปรไฟล์นี้ออกจากระบบใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(docId).delete();
                
                if (docId == globalUserId) {
                  await FirebaseAuth.instance.signOut();
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('ลบโปรไฟล์', style: TextStyle(color: Colors.white)),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard & Shop 🏆', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.emoji_events), text: 'อันดับคะแนน'),
              Tab(icon: Icon(Icons.shopping_bag), text: 'ร้านค้า & คลัง'),
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
                break;
              }
            }

            return TabBarView(
              children: [
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
                              subtitle: Row(
                                children: [
                                  Text('$score แต้ม', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Text('•  ❤️ $hearts', style: const TextStyle(fontSize: 13, color: Colors.pink, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isMe ? Icons.favorite : Icons.favorite_border,
                                      color: isMe ? Colors.pink[300] : Colors.pink,
                                    ),
                                    tooltip: isMe ? 'หัวใจที่คุณได้รับ' : 'ส่งหัวใจให้กำลังใจ (ชั่วโมงละ 1 ครั้ง)',
                                    onPressed: isMe ? null : () => _sendHeartToUser(docId, name),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteUserProfileDialog(docId, name);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red, size: 20),
                                            SizedBox(width: 8),
                                            Text('ลบโปรไฟล์'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

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

                    // แบนเนอร์หมุนวงล้อ Lucky Wheel (20 แต้ม)
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
                                  Text(
                                    'Lucky Wheel วงล้อเสี่ยงโชค',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'ลุ้น Jackpot +500 แต้ม, กล่องสุ่ม, โล่ 🛡️, กรอบรุ้ง 🌈 (20 แต้ม/ครั้ง)',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
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
                    const SizedBox(height: 20),

                    // จัดการกรอบโปรไฟล์ในคลัง (นีออน / ทอง / รุ้ง / เปลวไฟ / น้ำแข็ง)
                    const Text('🖼️ กรอบโปรไฟล์ในคลัง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      ],
                    ),
                    const SizedBox(height: 20),

                    // เลือกแลกและสลับฉายา
                    const Text('🎖️ ฉายา & คลังฉายา', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    _buildTitleItem('นักอัปเดตโต๊ะ 🥉', 100, myCurrentScore),
                    _buildTitleItem('นักอัปเดตโต๊ะจอมซน 😼', 300, myCurrentScore),
                    _buildTitleItem('ยอดอัพเดตโต๊ะ 🥈', 500, myCurrentScore),
                    _buildTitleItem('ท่านเทพอัพเดตโต๊ะ 🥇', 700, myCurrentScore),
                    _buildTitleItem('GMจอมขยัน 👑', 1000, myCurrentScore),
                    if (globalUnlockedTitles.contains('ราชาเกลือแห่งปี 🧂')) _buildTitleItem('ราชาเกลือแห่งปี 🧂', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('เซียนพูลหน้ามน 🎱')) _buildTitleItem('เซียนพูลหน้ามน 🎱', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('ทาสแมวตัวจริง 🐾')) _buildTitleItem('ทาสแมวตัวจริง 🐾', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('พนักงานดีเด่น ☕')) _buildTitleItem('พนักงานดีเด่น ☕', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('ดวงดีจัดๆ ⭐')) _buildTitleItem('ดวงดีจัดๆ ⭐', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('นักเสี่ยงดวงแห่งปี 🎰')) _buildTitleItem('นักเสี่ยงดวงแห่งปี 🎰', 0, myCurrentScore),
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

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isNotEmpty && globalUserId.isNotEmpty) {
      FirebaseFirestore.instance.collection('chat_messages').add({
        'senderId': globalUserId,
        'senderName': globalUserName,
        'senderAvatar': globalUserAvatar,
        'senderTitle': globalUserTitle,
        'message': text,
        'timestamp': Timestamp.now(),
      });
      _msgController.clear();
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
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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