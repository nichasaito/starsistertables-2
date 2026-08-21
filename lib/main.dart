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
String globalUserFrame = ''; // 'gold', 'neon', ''
List<String> globalUnlockedTitles = [];
List<String> globalUnlockedFrames = [];
Timestamp? globalBuffX2Until;
int globalUserLevel = 1;
int globalUserUpdateCount = 0;
int globalUserScore = 0;
int globalUserHearts = 0;
Map<String, dynamic> globalLastHeartSent = {};

// คลังอิโมจิโปรไฟล์แบบจุใจ 60+ แบบ
const List<String> avatarList = [
  '🐱', '🐶', '🦊', '🐼', '🐰', '🐻', '🦁', '🐯', '🐸', '🐵', 
  '🦄', '🐧', '🦉', '🐨', '🐹', '🐥', '🐙', '🐬', '🦖', '🐝', 
  '🦋', '🦥', '🦦', '🦔', '🐺', '🐮', '🐷', '🐲', '🦈',
  '☕', '🧋', '🍰', '🍩', '🍕', '🍔', '🍟', '🍣', '🍦', '🍓', 
  '🥑', '🍜', '🥐', '🥞', '🍪', '🍫', '🍿', '🍹', '🍧', '🍉',
  '👑', '⭐', '✨', '🔥', '💎', '🎮', '🎱', '🎯', '🎨', '🎧', 
  '🚀', '🛸', '⚡', '🌈', '🍀', '🌸', '🌻', '🌙', '🪄', '💖'
];

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

// Widget สำหรับแสดงผลรูปโปรไฟล์ (รองรับกรอบนีออน/ทอง)
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
      padding: const EdgeInsets.all(2),
      child: circle,
    );
  }

  return circle;
}

// ระบบบันทึกและคำนวณเลเวล รองรับคนกดพร้อมกันโดยใช้ FieldValue.increment
Future<void> registerUserUpdateAction(BuildContext? context) async {
  if (globalUserId.isEmpty) return;

  final userDocRef = FirebaseFirestore.instance.collection('users').doc(globalUserId);

  try {
    bool isBuffActive = globalBuffX2Until != null && globalBuffX2Until!.toDate().isAfter(DateTime.now());
    int scoreGained = isBuffActive ? 2 : 1;

    await userDocRef.update({
      'updateCount': FieldValue.increment(1),
      'score': FieldValue.increment(scoreGained),
    });

    globalUserUpdateCount += 1;
    globalUserScore += scoreGained;

    if (globalUserUpdateCount >= 100) {
      int gainedLevels = globalUserUpdateCount ~/ 100;
      globalUserUpdateCount = globalUserUpdateCount % 100;
      globalUserLevel += gainedLevels;

      int baseBonus = 20;
      int bonusScore = isBuffActive ? (baseBonus * 2 * gainedLevels) : (baseBonus * gainedLevels);

      await userDocRef.update({
        'level': FieldValue.increment(gainedLevels),
        'score': FieldValue.increment(bonusScore),
        'updateCount': globalUserUpdateCount,
      });

      globalUserScore += bonusScore;

      if (context != null && context.mounted) {
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
                        ? '🎉 เลเวลอัปเป็น Lv.$globalUserLevel! (+โบนัสบัฟ x2 = $bonusScore แต้ม)'
                        : '🎉 เลเวลอัปเป็น Lv.$globalUserLevel! (+$bonusScore คะแนนโบนัส)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
          'lastHeartSent': {},
          'updateCount': 0,
          'level': 1,
          'title': '',
          'frame': '',
          'unlockedTitles': [],
          'unlockedFrames': [],
          'buffX2Until': null,
          'email': email,
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
                  Text('StarSister Tables', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(height: 12),
                  Text(isLogin ? 'เข้าสู่ระบบเพื่อใช้งาน' : 'สร้างโปรไฟล์ใหม่', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 20),
                  if (!isLogin) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue[50],
                          backgroundImage: _pickedImageFile != null ? FileImage(_pickedImageFile!) : null,
                          child: _pickedImageFile == null ? Text(_selectedAvatar, style: const TextStyle(fontSize: 32)) : null,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text('เลือกรูป'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้งาน', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'อีเมล (Email)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
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
                        child: Text(isLogin ? 'เข้าสู่ระบบ' : 'ลงทะเบียนใช้งาน', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? 'ยังไม่มีบัญชี? สมัครสมาชิกที่นี่' : 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ', style: TextStyle(color: Colors.blue[900])),
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
            
            // ซิงค์ฉายา/กรอบปัจจุบันเข้าคลังอัตโนมัติหากยังไม่มี
            if (globalUserTitle.isNotEmpty && !globalUnlockedTitles.contains(globalUserTitle)) {
              globalUnlockedTitles.add(globalUserTitle);
            }
            if (globalUserFrame.isNotEmpty && !globalUnlockedFrames.contains(globalUserFrame)) {
              globalUnlockedFrames.add(globalUserFrame);
            }

            globalBuffX2Until = data['buffX2Until'];
            globalUserLevel = data['level'] ?? 1;
            globalUserUpdateCount = data['updateCount'] ?? 0;
            globalUserScore = data['score'] ?? 0;
            globalUserHearts = data['hearts'] ?? 0;
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
              title: const Text('แก้ไขโปรไฟล์ & ตกแต่ง', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                          : null,
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(radius: 28, backgroundImage: FileImage(newPickedFile!)),
                                )
                              : buildUserAvatarWidget(selectedAvatar, radius: 28, fontSize: 28, frame: selectedFrame),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final picker = ImagePicker();
                                    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 80);
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
                                  onTap: isSaving ? null : () => setDialogState(() {
                                    selectedAvatar = avatar;
                                    newPickedFile = null;
                                  }),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue[100] : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isSelected ? Colors.blue[900]! : Colors.grey[300]!, width: isSelected ? 2 : 1),
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
                        decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้งาน', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),

                      // เลือกลายกรอบโปรไฟล์ที่มี
                      const Text('🖼️ กรอบโปรไฟล์ที่ปลดล็อกแล้ว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
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
                        ],
                      ),
                      const SizedBox(height: 16),

                      // เลือกฉายาที่มี
                      const Text('🎖️ ฉายาที่ปลดล็อกแล้ว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      globalUnlockedTitles.isEmpty
                          ? const Text('ยังไม่มีฉายา (ไปแลกหรือสุ่มได้ที่ร้านค้า)', style: TextStyle(color: Colors.grey, fontSize: 13))
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
                              final ref = FirebaseStorage.instance.ref().child('user_avatars').child('$globalUserId.jpg');
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
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
              hintText: 'พิมพ์ข้อความประกาศ...',
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
                final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;

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
              SizedBox(width: 8),
              Text('เปลี่ยนสถานะทุกโต๊ะ ($floorName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text('กรุณาเลือกสถานะที่ต้องการปรับใช้กับทุกโต๊ะในชั้นนี้พร้อมกัน:'),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
              label: const Text('ว่างทั้งหมด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _executeBatchStatusUpdate(collectionName, floorName, true);
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isAvailable': targetStatus,
          'lastUpdated': now,
          'updatedBy': userDisplayName,
        });
      }

      await batch.commit();
      if (mounted) {
        await registerUserUpdateAction(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: targetStatus ? Colors.green[800] : Colors.red[800],
            content: Text('เปลี่ยนทุกโต๊ะใน $floorName เป็น "${targetStatus ? 'ว่างทั้งหมด' : 'ไม่ว่างทั้งหมด'}" เรียบร้อยแล้ว'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
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
                          Text('โต๊ะที่ว่าง (${_menuTitles[activeIndex]})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                        child: Text('ว่าง ${docs.length} โต๊ะ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('ไม่มีโต๊ะว่างในขณะนี้ (เต็มทุกโต๊ะ)', style: TextStyle(fontSize: 16, color: Colors.grey))),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.green[300]!)),
                            child: ListTile(
                              dense: true,
                              leading: const CircleAvatar(radius: 14, backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white, size: 16)),
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
      final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'lastUpdated': now, 'updatedBy': userDisplayName});
      }

      await batch.commit();
      if (mounted) {
        await registerUserUpdateAction(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blue[900],
            content: Text('⚡ อัปเดตเวลาเช็คสถานะทุกโต๊ะใน ${_menuTitles[activeIndex]} แล้ว'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
              onPressed: () async {
                final String tableName = nameController.text.trim();
                if (tableName.isNotEmpty) {
                  final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;
                  await FirebaseFirestore.instance.collection(_collections[activeIndex]).add({
                    'name': tableName,
                    'isAvailable': true,
                    'lastUpdated': Timestamp.now(),
                    'updatedBy': userDisplayName,
                    'waitingQueue': [],
                  });
                  if (context.mounted) {
                    await registerUserUpdateAction(context);
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
    final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName\n[$globalUserTitle]' : globalUserName;
    bool isBuffActive = globalBuffX2Until != null && globalBuffX2Until!.toDate().isAfter(DateTime.now());

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (tabContext) {
          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('StarSister Tables', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (isBuffActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                          child: const Text('🔥 x2', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    'Lv.$globalUserLevel ($globalUserUpdateCount/100) • $globalUserScore แต้ม • ❤️ $globalUserHearts',
                    style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.w600),
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
                  tooltip: 'อัปเดตเวลาทุกโต๊ะตอนนี้',
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
                tabs: [Tab(text: 'ชั้น 1'), Tab(text: 'ชั้น 2'), Tab(text: 'ชั้น 3')],
              ),
            ),
            drawer: Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
                    color: Colors.blue[900],
                    child: Column(
                      children: [
                        buildUserAvatarWidget(globalUserAvatar, radius: 36, fontSize: 36, frame: globalUserFrame),
                        const SizedBox(height: 8),
                        Text('สวัสดี, $userDisplayName', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('เลเวล $globalUserLevel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('$globalUserScore แต้ม (❤️ $globalUserHearts)', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: globalUserUpdateCount / 100.0,
                                  minHeight: 6,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
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
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onEditProfile();
                              },
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('แก้ไขโปรไฟล์', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red[200], side: BorderSide(color: Colors.red[200]!)),
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
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('app_settings').doc('daily_note').snapshots(),
                    builder: (context, snapshot) {
                      String message = 'ยังไม่มีประกาศสำคัญประจำวันนี้';
                      String updatedBy = '';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        message = data['message'] ?? message;
                        updatedBy = data['updatedBy'] ?? '';
                      }

                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Card(
                          elevation: 2,
                          color: Colors.amber[50],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber[400]!, width: 1.2)),
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
                                        Text('ประกาศประจำวัน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber[900])),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 22),
                                      color: Colors.blue[900],
                                      onPressed: () => _showEditDailyNoteDialog(context, message == 'ยังไม่มีประกาศสำคัญประจำวันนี้' ? '' : message),
                                    ),
                                  ],
                                ),
                                Text(message, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                if (updatedBy.isNotEmpty) Text('โดย: $updatedBy', style: TextStyle(fontSize: 10, color: Colors.grey[700], fontStyle: FontStyle.italic)),
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
                                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; }))
                                : null,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('แสดงเฉพาะโต๊ะว่าง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          value: _onlyAvailable,
                          activeColor: Colors.blue[900],
                          onChanged: (val) => setState(() => _onlyAvailable = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                TableGrid(collectionName: 'tables_f1', onlyAvailable: _onlyAvailable, searchQuery: _searchQuery),
                TableGrid(collectionName: 'tables_f2', onlyAvailable: _onlyAvailable, searchQuery: _searchQuery),
                TableGrid(collectionName: 'tables_f3', onlyAvailable: _onlyAvailable, searchQuery: _searchQuery),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddTableDialog(context, DefaultTabController.of(tabContext).index),
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

  const TableGrid({super.key, required this.collectionName, this.onlyAvailable = false, this.searchQuery = ''});

  void _showDeleteDialog(BuildContext context, String docId, String tableName, CollectionReference ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('ลบ "$tableName" ?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: const Text('คุณต้องการลบโต๊ะนี้ออกจากระบบใช่หรือไม่?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await ref.doc(docId).delete();
                  if (context.mounted) {
                    await registerUserUpdateAction(context);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint('Delete error: $e');
                }
              },
              child: const Text('ลบโต๊ะ', style: TextStyle(color: Colors.white)),
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
          content = CustomFloorPlanF1(docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef));
        } else if (collectionName == 'tables_f2') {
          content = CustomFloorPlanF2(docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef));
        } else if (collectionName == 'tables_f3') {
          content = CustomFloorPlanF3(docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef));
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

  bool get _isMergeableTable => collectionName == 'tables_f1' && (expectedName.startsWith('โต๊ะ '));
  bool get _hasQueueSystem => expectedName.contains('พูล') || expectedName == 'ห้องกระจก';

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
              title: Text('รวมโต๊ะกับ $currentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: otherAvailableTables.map((tbl) {
                    final docId = tbl['docId'] as String;
                    final name = tbl['name'] as String;
                    return CheckboxListTile(
                      dense: true,
                      title: Text(name),
                      value: selectedDocIds.contains(docId),
                      onChanged: (val) {
                        setDialogState(() {
                          val == true ? selectedDocIds.add(docId) : selectedDocIds.remove(docId);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  onPressed: selectedDocIds.isEmpty
                      ? null
                      : () async {
                          final batch = FirebaseFirestore.instance.batch();
                          final newGroupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
                          final allNamesInGroup = [currentName];

                          for (var tbl in otherAvailableTables) {
                            if (selectedDocIds.contains(tbl['docId'])) allNamesInGroup.add(tbl['name'] as String);
                          }
                          allNamesInGroup.sort();
                          final now = Timestamp.now();
                          final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;

                          batch.update(FirebaseFirestore.instance.collection(collectionName).doc(currentDocId), {
                            'mergedGroupId': newGroupId,
                            'mergedWith': allNamesInGroup,
                            'isAvailable': false,
                            'lastUpdated': now,
                            'updatedBy': userDisplayName,
                          });

                          for (var docId in selectedDocIds) {
                            batch.update(FirebaseFirestore.instance.collection(collectionName).doc(docId), {
                              'mergedGroupId': newGroupId,
                              'mergedWith': allNamesInGroup,
                              'isAvailable': false,
                              'lastUpdated': now,
                              'updatedBy': userDisplayName,
                            });
                          }

                          await batch.commit();
                          if (context.mounted) {
                            await registerUserUpdateAction(context);
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: const Text('ยืนยันรวมโต๊ะ', style: TextStyle(color: Colors.white)),
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
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).where('mergedGroupId', isEqualTo: mergedGroupId).get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;

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
        await registerUserUpdateAction(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✂️ แยกโต๊ะเรียบร้อยแล้ว'), backgroundColor: Colors.blue));
      }
    } catch (e) {
      debugPrint('Unmerge error: $e');
    }
  }

  Future<void> _toggleMergedGroupAvailability(BuildContext context, String mergedGroupId, bool currentStatus) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).where('mergedGroupId', isEqualTo: mergedGroupId).get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isAvailable': !currentStatus,
          'lastUpdated': now,
          'updatedBy': userDisplayName,
        });
      }

      await batch.commit();
      if (context.mounted) await registerUserUpdateAction(context);
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
                  title: const Text('แยกโต๊ะออกจากกลุ่ม', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _unmergeTables(context, mergedGroupId);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue, size: 26),
                  title: const Text('รวมโต๊ะกับโต๊ะอื่น', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _showMergeDialog(context, docId, tableName);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red, size: 26),
                title: const Text('ลบโต๊ะออกจากระบบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('คิวรอ: $expectedName', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อผู้รอ / โน้ต', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 8),
                      TextField(controller: countCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'จำนวนคน', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            final count = int.tryParse(countCtrl.text.trim()) ?? 0;
                            if (name.isNotEmpty) {
                              setDialogState(() {
                                queueList.add({'name': name, 'count': count});
                                nameCtrl.clear();
                                countCtrl.clear();
                              });
                              await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                                'waitingQueue': queueList,
                                'lastUpdated': Timestamp.now(),
                              });
                              if (context.mounted) await registerUserUpdateAction(context);
                            }
                          },
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text('ลงชื่อต่อคิว', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...queueList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value as Map<String, dynamic>;
                        return ListTile(
                          dense: true,
                          title: Text(item['name'] ?? '-'),
                          subtitle: Text('${item['count'] ?? 0} คน'),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            onPressed: () async {
                              setDialogState(() => queueList.removeAt(index));
                              await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                                'waitingQueue': queueList,
                                'lastUpdated': Timestamp.now(),
                              });
                              if (context.mounted) await registerUserUpdateAction(context);
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ปิด'))],
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

    final String userDisplayName = globalUserTitle.isNotEmpty ? '$globalUserName [$globalUserTitle]' : globalUserName;

    if (targetDoc == null) {
      return Card(
        color: Colors.grey[100],
        child: InkWell(
          onTap: () async {
            try {
              await FirebaseFirestore.instance.collection(collectionName).add({
                'name': expectedName,
                'isAvailable': true,
                'lastUpdated': Timestamp.now(),
                'updatedBy': userDisplayName,
                'waitingQueue': [],
              });
              if (context.mounted) await registerUserUpdateAction(context);
            } catch (e) {
              debugPrint('Create error: $e');
            }
          },
          child: Center(child: Text('$expectedName\n(แตะเพื่อสร้าง)', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))),
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
        child: Card(child: Center(child: Text(expectedName, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
      );
    }

    String timeStr = '';
    if (ts != null) {
      final dt = ts.toDate();
      timeStr = ' (${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.)';
    }

    return Card(
      elevation: 4,
      color: isAvailable ? Colors.green[50] : Colors.red[50],
      shape: isCircle
          ? CircleBorder(side: BorderSide(color: isAvailable ? Colors.green : Colors.red, width: 2))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: mergedGroupId != null ? Colors.blue[900]! : (isAvailable ? Colors.green : Colors.red), width: 2),
            ),
      child: InkWell(
        onTap: () async {
          try {
            if (mergedGroupId != null) {
              await _toggleMergedGroupAvailability(context, mergedGroupId, isAvailable);
            } else {
              await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                'isAvailable': !isAvailable,
                'lastUpdated': Timestamp.now(),
                'updatedBy': userDisplayName,
              });
              if (context.mounted) await registerUserUpdateAction(context);
            }
          } catch (e) {
            debugPrint('Update error: $e');
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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(expectedName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: isAvailable ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Text(isAvailable ? 'ว่าง' : 'ไม่ว่าง', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                if (mergedGroupId != null && mergedWith != null) ...[
                  const SizedBox(height: 3),
                  Text('🔗 ${mergedWith.join("+")}', style: TextStyle(color: Colors.blue[900], fontSize: 10, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 3),
                Text('โดย: $updatedBy$timeStr', style: TextStyle(fontSize: 10, color: Colors.grey[800], fontStyle: FontStyle.italic)),
              ],
            ),
            if (_hasQueueSystem)
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () => _showQueueDialog(context, docId, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: queueList.isNotEmpty ? Colors.amber[800] : Colors.blue[900], borderRadius: BorderRadius.circular(10)),
                    child: Text(queueList.isNotEmpty ? '${queueList.length} คิว' : '+คิว', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

// แผนผังชั้น 1, 2, 3
class CustomFloorPlanF1 extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final bool onlyAvailable;
  final String searchQuery;
  final Function(String, String) onDelete;

  const CustomFloorPlanF1({super.key, required this.docs, required this.collectionName, this.onlyAvailable = false, this.searchQuery = '', required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(alignment: Alignment.center, child: _buildDoor('ประตูร้าน')),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'Nintendo 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 8),
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'Nintendo 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 8),
                  Container(height: 160, decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('บาร์น้ำ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
                  const SizedBox(height: 8),
                  SizedBox(height: 110, child: FloorPlanCard(expectedName: 'เหลี่ยมขาว', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 8),
                  SizedBox(height: 120, child: FloorPlanCard(expectedName: 'ห้องกระจก', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 8),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 8),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 3', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 8),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 4', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
                  const SizedBox(height: 8),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 5', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
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

  const CustomFloorPlanF2({super.key, required this.docs, required this.collectionName, this.onlyAvailable = false, this.searchQuery = '', required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      children: [
        SizedBox(height: 140, child: FloorPlanCard(expectedName: 'ห้อง VIP', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 10),
        SizedBox(height: 130, child: FloorPlanCard(expectedName: 'กลมขาว 1', isCircle: true, docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 10),
        SizedBox(height: 130, child: FloorPlanCard(expectedName: 'กลมขาว 2', isCircle: true, docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 10),
        SizedBox(height: 110, child: FloorPlanCard(expectedName: 'เหลี่ยมดำ', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 10),
        SizedBox(height: 110, child: FloorPlanCard(expectedName: 'ข้างห้องกระจก', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 10),
        SizedBox(height: 140, child: FloorPlanCard(expectedName: 'ห้องกระจก', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
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

  const CustomFloorPlanF3({super.key, required this.docs, required this.collectionName, this.onlyAvailable = false, this.searchQuery = '', required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('โซนพูล', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'พูล 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'พูล 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete)),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        const Text('โซนในห้อง', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            FloorPlanCard(expectedName: 'ในห้อง 1', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 3', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 2', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 4', docs: docs, collectionName: collectionName, onlyAvailable: onlyAvailable, searchQuery: searchQuery, onDelete: onDelete),
          ],
        ),
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(20)),
      child: Text('อัปเดตล่าสุด: $h:$m น.', style: TextStyle(color: Colors.blue[900], fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

// ==========================================
// Lucky Wheel Dialog & Painter
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

  final List<_WheelReward> rewards = const [
    _WheelReward('โบนัส +100 แต้ม! 🎉', '+100', Colors.amber, 'bonus', 100),
    _WheelReward('เกลือ 🧂', 'เกลือ', Colors.grey, 'salt', 0),
    _WheelReward('แย่แล้ว! -2 แต้ม 🔻', '-2', Colors.redAccent, 'penalty', -2),
    _WheelReward('ฉายาลับ: "ดวงดีจัดๆ ⭐"', 'ฉายา ⭐', Colors.purpleAccent, 'title', 'ดวงดีจัดๆ ⭐'),
    _WheelReward('โบนัส +10 แต้ม ✨', '+10', Colors.orangeAccent, 'bonus', 10),
    _WheelReward('บัฟแต้ม x2 (30 นาที) 🔥', 'บัฟ x2', Colors.deepOrange, 'buff', 30),
    _WheelReward('แย่แล้ว! -4 แต้ม 🔻', '-4', Colors.redAccent, 'penalty', -4),
    _WheelReward('กรอบโปรไฟล์นีออน 💎', 'กรอบนีออน', Colors.cyan, 'frame', 'neon'),
    _WheelReward('โบนัส +50 แต้ม 🌟', '+50', Colors.amberAccent, 'bonus', 50),
    _WheelReward('แย่แล้ว! -6 แต้ม 🔻', '-6', Colors.red, 'penalty', -6),
    _WheelReward('ฉายาลับ: "นักเสี่ยงดวงแห่งปี 🎰"', 'ฉายา 🎰', Colors.deepPurple, 'title', 'นักเสี่ยงดวงแห่งปี 🎰'),
    _WheelReward('กรอบโปรไฟล์ทองคำ 👑', 'กรอบทอง', Colors.amber, 'frame', 'gold'),
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
    if (globalUserScore < 25) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ต้องการคะแนนอย่างน้อย 25 แต้ม')));
      return;
    }

    setState(() {
      _isSpinning = true;
      _resultText = null;
    });

    int newScore = globalUserScore - 25;
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

      if (reward.type == 'bonus' || reward.type == 'penalty') {
        int finalScore = max(0, globalUserScore + (reward.value as int));
        updateData['score'] = finalScore;
        globalUserScore = finalScore;
      } else if (reward.type == 'title') {
        updateData['title'] = reward.value;
        updateData['unlockedTitles'] = FieldValue.arrayUnion([reward.value]);
        globalUserTitle = reward.value;
        if (!globalUnlockedTitles.contains(reward.value)) globalUnlockedTitles.add(reward.value);
      } else if (reward.type == 'frame') {
        updateData['frame'] = reward.value;
        updateData['unlockedFrames'] = FieldValue.arrayUnion([reward.value]);
        globalUserFrame = reward.value;
        if (!globalUnlockedFrames.contains(reward.value)) globalUnlockedFrames.add(reward.value);
      } else if (reward.type == 'buff') {
        final buffExpiry = DateTime.now().add(Duration(minutes: reward.value as int));
        final ts = Timestamp.fromDate(buffExpiry);
        updateData['buffX2Until'] = ts;
        globalBuffX2Until = ts;
      }

      if (updateData.isNotEmpty) await userDoc.update(updateData);

      if (mounted) {
        setState(() {
          _isSpinning = false;
          _resultText = reward.label;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(child: Text('🎰 Lucky Wheel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
      content: SizedBox(
        width: 300,
        height: 360,
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
                      child: CustomPaint(size: const Size(240, 240), painter: _WheelPainter(rewards: rewards)),
                    );
                  },
                ),
                const Positioned(top: 0, child: Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 40)),
                CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.stars, color: Colors.amber[700])),
              ],
            ),
            const SizedBox(height: 16),
            if (_resultText != null)
              Text('🎉 คุณได้รับ: $_resultText', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))
            else
              const Text('ใช้ 25 แต้มต่อการหมุน', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSpinning ? null : () => Navigator.pop(context), child: const Text('ปิด')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
          onPressed: _isSpinning ? null : _spin,
          child: Text(_isSpinning ? 'กำลังหมุน...' : 'หมุนเลย', style: const TextStyle(color: Colors.white)),
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
    final borderPaint = Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2;

    for (int i = 0; i < rewards.length; i++) {
      paint.color = rewards[i].color;
      final startAngle = i * arcAngle;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, arcAngle, true, paint);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, arcAngle, true, borderPaint);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + arcAngle / 2);
      final textPainter = TextPainter(
        text: TextSpan(text: rewards[i].shortText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(radius * 0.45, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// LeaderboardScreen (ระบบสลับฉายาและกรอบ)
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
        final difference = now.difference(lastTimestamp.toDate());
        if (difference.inMinutes < 60) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⏳ รออีก ${60 - difference.inMinutes} นาที')));
          return;
        }
      }
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(targetDocId).update({'hearts': FieldValue.increment(1)});
      final currentTimestamp = Timestamp.now();
      await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
        'score': FieldValue.increment(1),
        'lastHeartSent.$targetDocId': currentTimestamp,
      });

      setState(() {
        globalUserScore += 1;
        globalLastHeartSent[targetDocId] = currentTimestamp;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.pink[600], content: Text('ส่งใจให้ $targetUserName แล้ว! (+1 แต้ม)')));
      }
    } catch (e) {
      debugPrint('Error heart: $e');
    }
  }

  void _claimOrEquipTitle(int currentScore, int requiredScore, String titleName) async {
    final bool isOwned = globalUnlockedTitles.contains(titleName);

    if (!isOwned && currentScore < requiredScore) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ต้องการแต้มอย่างน้อย $requiredScore แต้ม')));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green[700], content: Text('🎉 ปลดล็อกและสวมใส่ฉายา "$titleName" แล้ว!')));
      } else {
        // ถ้าเป็นเจ้าของอยู่แล้ว ให้สลับใส่/ถอด
        final newTitle = (globalUserTitle == titleName) ? '' : titleName;
        await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({'title': newTitle});
        setState(() => globalUserTitle = newTitle);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newTitle.isEmpty ? 'ถอดฉายาแล้ว' : 'สวมใส่ฉายา "$newTitle" แล้ว')));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newFrame.isEmpty ? 'ถอดกรอบโปรไฟล์แล้ว' : 'สวมใส่กรอบโปรไฟล์แล้ว')));
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
            if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาด'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final users = snapshot.data!.docs;
            int myCurrentScore = globalUserScore;

            for (var u in users) {
              if (u.id == globalUserId) {
                final d = u.data() as Map<String, dynamic>;
                myCurrentScore = d['score'] ?? 0;
                break;
              }
            }

            return TabBarView(
              children: [
                // หน้ารายชื่อ Leaderboard
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final docId = users[index].id;
                    final name = userData['name'] ?? 'Unknown';
                    final avatar = userData['avatar'] ?? '🐱';
                    final score = userData['score'] ?? 0;
                    final level = userData['level'] ?? 1;
                    final title = userData['title'] ?? '';
                    final frame = userData['frame'] ?? '';
                    final hearts = userData['hearts'] ?? 0;
                    final isMe = docId == globalUserId;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: buildUserAvatarWidget(avatar, radius: 22, fontSize: 22, frame: frame),
                        title: Row(
                          children: [
                            Text('$name (Lv.$level)', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (title.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(6)),
                                child: Text(title, style: TextStyle(fontSize: 10, color: Colors.amber[900], fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text('$score แต้ม • ❤️ $hearts', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: Icon(isMe ? Icons.favorite : Icons.favorite_border, color: Colors.pink),
                          onPressed: isMe ? null : () => _sendHeartToUser(docId, name),
                        ),
                      ),
                    );
                  },
                ),

                // หน้าร้านค้าและคลังของสะสม
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('คะแนนสะสมของคุณ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('$myCurrentScore แต้ม', style: TextStyle(fontSize: 20, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // วงล้อเสี่ยงโชค
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
                        ),
                        child: Row(
                          children: [
                            const Text('🎰', style: TextStyle(fontSize: 32)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Lucky Wheel วงล้อเสี่ยงโชค', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('ลุ้นฉายาลับ, กรอบ และแต้ม (25 แต้ม/ครั้ง)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                              onPressed: () => showDialog(context: context, builder: (context) => LuckyWheelDialog(currentScore: myCurrentScore)),
                              child: const Text('หมุนเลย', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ส่วนจัดการกรอบโปรไฟล์ที่ปลดล็อกแล้ว
                    const Text('🖼️ กรอบโปรไฟล์ในคลัง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildFrameCard('นีออน 💎', 'neon', Colors.cyanAccent),
                        const SizedBox(width: 12),
                        _buildFrameCard('ทองคำ 👑', 'gold', Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ส่วนฉายา
                    const Text('🎖️ ฉายา & คลังฉายา', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildTitleItem('นักอัปเดตโต๊ะ 🥉', 100, myCurrentScore),
                    _buildTitleItem('นักอัปเดตโต๊ะจอมซน 😼', 300, myCurrentScore),
                    _buildTitleItem('ยอดอัพเดตโต๊ะ 🥈', 500, myCurrentScore),
                    _buildTitleItem('ท่านเทพอัพเดตโต๊ะ 🥇', 700, myCurrentScore),
                    _buildTitleItem('GMจอมขยัน 👑', 1000, myCurrentScore),
                    if (globalUnlockedTitles.contains('ดวงดีจัดๆ ⭐')) _buildTitleItem('ดวงดีจัดๆ ⭐', 0, myCurrentScore),
                    if (globalUnlockedTitles.contains('นักเสี่ยงดวงแห่งปี 🎰')) _buildTitleItem('นักเสี่ยงดวงแห่งปี 🎰', 0, myCurrentScore),
                  ],
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: const SizedBox(height: 500, child: TeamChatBottomSheet())),
            );
          },
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          child: const Icon(Icons.chat_bubble),
        ),
      ),
    );
  }

  Widget _buildFrameCard(String label, String frameType, Color frameColor) {
    final bool isOwned = globalUnlockedFrames.contains(frameType);
    final bool isEquipped = globalUserFrame == frameType;

    return Expanded(
      child: Card(
        color: isEquipped ? Colors.blue[50] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isEquipped ? Colors.blue[900]! : Colors.grey[300]!, width: isEquipped ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              buildUserAvatarWidget(globalUserAvatar, radius: 20, fontSize: 20, frame: isOwned ? frameType : ''),
              const SizedBox(height: 8),
              if (!isOwned)
                const Text('(สุ่มได้จากวงล้อ)', style: TextStyle(fontSize: 11, color: Colors.grey))
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped ? Colors.red[400] : Colors.blue[900],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () => _equipOrUnequipFrame(frameType),
                  child: Text(isEquipped ? 'ถอดออก' : 'เลือกใช้', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleItem(String title, int requiredScore, int currentScore) {
    final bool isOwned = globalUnlockedTitles.contains(title);
    final bool isEquipped = globalUserTitle == title;
    final bool canClaim = currentScore >= requiredScore;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isEquipped ? Colors.amber[800]! : Colors.transparent, width: isEquipped ? 2 : 0),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(isOwned ? 'ปลดล็อกแล้ว (อยู่ในคลัง)' : 'เงื่อนไข: $requiredScore แต้ม', style: TextStyle(fontSize: 12, color: isOwned ? Colors.green[700] : Colors.grey)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isEquipped ? Colors.green[600] : (isOwned ? Colors.blue[900] : (canClaim ? Colors.amber[700] : Colors.grey[400])),
          ),
          onPressed: (!isOwned && !canClaim) ? null : () => _claimOrEquipTitle(currentScore, requiredScore, title),
          child: Text(
            isEquipped ? 'ใช้งานอยู่ (แตะเพื่อถอด)' : (isOwned ? 'เลือกใช้' : 'แลกฉายา'),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
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
          decoration: BoxDecoration(color: Colors.amber[700], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
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
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chat_messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาด'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
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
                              if (!isMe) Text(senderTitle.isNotEmpty ? '$senderName [$senderTitle]' : senderName, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.amber[700] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(message, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                              ),
                            ],
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
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความ...',
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
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendMessage),
              ),
            ],
          ),
        ),
      ],
    );
  }
}