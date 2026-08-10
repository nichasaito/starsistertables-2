import 'dart:io';
import 'dart:async';
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

const List<String> avatarList = [
  '🐱', '🐶', '🦊', '🐼', '🐰', 
  '🐻', '🦁', '🐯', '🐸', '🐵', 
  '🦄', '🐧', '🦉', '👑', '⭐'
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

// Widget สำหรับแสดงผลรูปโปรไฟล์
Widget buildUserAvatarWidget(String avatar, {double radius = 24, double fontSize = 24}) {
  bool isUrl = avatar.startsWith('http://') || avatar.startsWith('https://');
  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.blue[50],
    backgroundImage: isUrl ? NetworkImage(avatar) : null,
    child: !isUrl ? Text(avatar, style: TextStyle(fontSize: fontSize)) : null,
  );
}

// ==========================================
// AuthScreen: หน้าเข้าสู่ระบบ / สมัครสมาชิก
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
          'clickCount': 0,
          'title': '',
          'email': email,
        });
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'เกิดข้อผิดพลาด';
      if (e.code == 'user-not-found') msg = 'ไม่พบอีเมลนี้ในระบบ';
      if (e.code == 'wrong-password') msg = 'รหัสผ่านไม่ถูกต้อง';
      if (e.code == 'email-already-in-use') msg = 'อีเมลนี้ถูกใช้งานแล้ว';
      if (e.code == 'weak-password') msg = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';

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
                  Image.asset(
                    'assets/images/starsister_logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Text(
                      'StarSister Tables',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                    ),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
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
  bool _isInitLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      globalUserId = user.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          globalUserName = data['name'] ?? 'Staff';
          globalUserAvatar = data['avatar'] ?? '🐱';
          globalUserTitle = data['title'] ?? '';
          _isInitLoaded = true;
        });
      } else {
        setState(() => _isInitLoaded = true);
      }
    }
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(text: globalUserName);
    String selectedAvatar = globalUserAvatar;
    File? newPickedFile;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('แก้ไขโปรไฟล์', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              ? CircleAvatar(radius: 28, backgroundImage: FileImage(newPickedFile!))
                              : buildUserAvatarWidget(selectedAvatar, radius: 28, fontSize: 28),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
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
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: avatarList.map((avatar) {
                            final isSelected = avatar == selectedAvatar && newPickedFile == null;
                            return GestureDetector(
                              onTap: () => setDialogState(() {
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อผู้ใช้งาน',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
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
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty) {
                      String finalAvatar = selectedAvatar;

                      if (newPickedFile != null) {
                        final ref = FirebaseStorage.instance.ref().child('user_avatars').child('$globalUserId.jpg');
                        await ref.putFile(newPickedFile!);
                        finalAvatar = await ref.getDownloadURL();
                      }

                      await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
                        'name': newName,
                        'avatar': finalAvatar,
                      });

                      setState(() {
                        globalUserName = newName;
                        globalUserAvatar = finalAvatar;
                      });

                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    }
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
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
              onPressed: () {
                final String tableName = nameController.text.trim();
                if (tableName.isNotEmpty) {
                  final String userDisplayName = globalUserTitle.isNotEmpty 
                      ? '$globalUserName [$globalUserTitle]' 
                      : globalUserName;

                  FirebaseFirestore.instance.collection(_collections[activeIndex]).add({
                    'name': tableName,
                    'isAvailable': true,
                    'lastUpdated': Timestamp.now(),
                    'updatedBy': userDisplayName,
                  });
                  _incrementUserScore();
                  Navigator.pop(context);
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
  Widget build(BuildContext context) {
    final String userDisplayName = globalUserTitle.isNotEmpty 
        ? '$globalUserName\n[$globalUserTitle]' 
        : globalUserName;

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('StarSister Tables', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), 
              backgroundColor: Colors.blue[900], 
              foregroundColor: Colors.white,
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
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 60, bottom: 20, left: 16, right: 16),
                    color: Colors.blue[900],
                    child: Column(
                      children: [
                        buildUserAvatarWidget(globalUserAvatar, radius: 36, fontSize: 36),
                        const SizedBox(height: 8),
                        Text(
                          'สวัสดี, $userDisplayName', 
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await FirebaseAuth.instance.signOut();
                              },
                              icon: const Icon(Icons.logout, size: 14),
                              label: const Text('ออกจากระบบ', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('ระบบจัดการผังโต๊ะ StarSister Tables', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                TableGrid(key: const ValueKey('tables_f1'), collectionName: 'tables_f1'),
                TableGrid(key: const ValueKey('tables_f2'), collectionName: 'tables_f2'),
                TableGrid(key: const ValueKey('tables_f3'), collectionName: 'tables_f3'),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                final int currentTabIndex = DefaultTabController.of(context).index;
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

void _incrementUserScore() async {
  if (globalUserId.isNotEmpty) {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(globalUserId);
    final docSnapshot = await userDocRef.get();

    int currentClicks = 0;
    if (docSnapshot.exists && docSnapshot.data()!.containsKey('clickCount')) {
      currentClicks = docSnapshot.data()!['clickCount'] ?? 0;
    }

    currentClicks += 1;

    if (currentClicks >= 5) {
      await userDocRef.set({
        'id': globalUserId,
        'name': globalUserName,
        'avatar': globalUserAvatar,
        'score': FieldValue.increment(1),
        'clickCount': 0,
        'title': globalUserTitle,
      }, SetOptions(merge: true));
    } else {
      await userDocRef.set({
        'id': globalUserId,
        'name': globalUserName,
        'avatar': globalUserAvatar,
        'clickCount': currentClicks,
        'score': FieldValue.increment(0),
        'title': globalUserTitle,
      }, SetOptions(merge: true));
    }
  }
}

// ==========================================
// TableGrid
// ==========================================
class TableGrid extends StatelessWidget {
  final String collectionName;
  const TableGrid({super.key, required this.collectionName});

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
              onPressed: () {
                ref.doc(docId).delete(); 
                Navigator.pop(context);
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
        int availableCount = 0;
        int occupiedCount = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['isAvailable'] == true) {
            availableCount++;
          } else {
            occupiedCount++;
          }

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
          content = CustomFloorPlanF1(docs: docs, collectionName: collectionName, onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef));
        } else if (collectionName == 'tables_f2') {
          content = CustomFloorPlanF2(docs: docs, collectionName: collectionName, onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef));
        } else if (collectionName == 'tables_f3') {
          content = CustomFloorPlanF3(docs: docs, collectionName: collectionName, onDelete: (docId, name) => _showDeleteDialog(context, docId, name, tablesRef));
        } else {
          content = const Center(child: Text('ไม่มีข้อมูลแผนผัง'));
        }

        return Column(
          children: [
            // แถบสรุปสถานะจำนวนโต๊ะ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('ทั้งหมด: ${docs.length}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  Text('ว่าง: $availableCount', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text('ไม่ว่าง: $occupiedCount', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  content,
                  Positioned(bottom: 12, left: 12, child: LastUpdateWidget(updateTime: lastUpdateTime)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// FloorPlanCard: แสดงเวลาแบบ HH:mm น. (ไม่มีวินาที)
// ==========================================
class FloorPlanCard extends StatelessWidget {
  final String expectedName;
  final bool isCircle;
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final Function(String docId, String name) onDelete;

  const FloorPlanCard({
    super.key,
    required this.expectedName,
    this.isCircle = false,
    required this.docs,
    required this.collectionName,
    required this.onDelete,
  });

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
          onTap: () {
            FirebaseFirestore.instance.collection(collectionName).add({
              'name': expectedName,
              'isAvailable': true,
              'lastUpdated': Timestamp.now(),
              'updatedBy': userDisplayName,
            });
            _incrementUserScore();
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
    final Timestamp? ts = data['lastUpdated'];

    // แปลงเวลาให้เหลือแค่ ชั่วโมง:นาที (HH:mm น.)
    String timeStr = '';
    if (ts != null) {
      final dt = ts.toDate();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      timeStr = ' ($h:$m น.)';
    }

    return Card(
      elevation: 4,
      color: isAvailable ? Colors.green[50] : Colors.red[50],
      shape: isCircle
          ? CircleBorder(side: BorderSide(color: isAvailable ? Colors.green : Colors.red, width: 2))
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isAvailable ? Colors.green : Colors.red, width: 2)),
      child: InkWell(
        customBorder: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () {
          FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
            'isAvailable': !isAvailable,
            'lastUpdated': Timestamp.now(),
            'updatedBy': userDisplayName,
          });
          _incrementUserScore();
        },
        onLongPress: () => onDelete(docId, expectedName),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(expectedName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: isAvailable ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isAvailable ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(isAvailable ? 'ว่าง' : 'ไม่ว่าง', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'โดย: $updatedBy$timeStr',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[800], fontStyle: FontStyle.italic),
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
// แผนผังชั้น 1, 2, 3
// ==========================================
class CustomFloorPlanF1 extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final Function(String, String) onDelete;

  const CustomFloorPlanF1({super.key, required this.docs, required this.collectionName, required this.onDelete});

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
                  SizedBox(height: 120, child: FloorPlanCard(expectedName: 'Nintendo 1', docs: docs, collectionName: collectionName, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 120, child: FloorPlanCard(expectedName: 'Nintendo 2', docs: docs, collectionName: collectionName, onDelete: onDelete)),
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
                  SizedBox(height: 120, child: FloorPlanCard(expectedName: 'เหลี่ยมขาว', docs: docs, collectionName: collectionName, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 140, child: FloorPlanCard(expectedName: 'ห้องกระจก', docs: docs, collectionName: collectionName, onDelete: onDelete)),
                ],
              ),
            ),
            const Expanded(flex: 1, child: SizedBox()), 
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 1', docs: docs, collectionName: collectionName, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 2', docs: docs, collectionName: collectionName, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 3', docs: docs, collectionName: collectionName, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 4', docs: docs, collectionName: collectionName, onDelete: onDelete)),
                  const SizedBox(height: 12),
                  SizedBox(height: 100, child: FloorPlanCard(expectedName: 'โต๊ะ 5', docs: docs, collectionName: collectionName, onDelete: onDelete)),
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
  final Function(String, String) onDelete;

  const CustomFloorPlanF2({super.key, required this.docs, required this.collectionName, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 80, left: 40, right: 40),
      children: [
        SizedBox(height: 160, child: FloorPlanCard(expectedName: 'ห้อง VIP', docs: docs, collectionName: collectionName, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'กลมขาว 1', isCircle: true, docs: docs, collectionName: collectionName, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'กลมขาว 2', isCircle: true, docs: docs, collectionName: collectionName, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'เหลี่ยมดำ', docs: docs, collectionName: collectionName, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: FloorPlanCard(expectedName: 'ข้างห้องกระจก', docs: docs, collectionName: collectionName, onDelete: onDelete)),
        const SizedBox(height: 12),
        SizedBox(height: 160, child: FloorPlanCard(expectedName: 'ห้องกระจก', docs: docs, collectionName: collectionName, onDelete: onDelete)),
        const SizedBox(height: 16),
        Align(alignment: Alignment.bottomRight, child: _buildDoor('ประตู')),
      ],
    );
  }
}

class CustomFloorPlanF3 extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String collectionName;
  final Function(String, String) onDelete;

  const CustomFloorPlanF3({super.key, required this.docs, required this.collectionName, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 80, left: 24, right: 24),
      children: [
        const Text('โซนพูล', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)), 
        const SizedBox(height: 16),
        SizedBox(height: 140, child: FloorPlanCard(expectedName: 'พูล 2', docs: docs, collectionName: collectionName, onDelete: onDelete)),
        const SizedBox(height: 16),
        SizedBox(height: 140, child: FloorPlanCard(expectedName: 'พูล 1', docs: docs, collectionName: collectionName, onDelete: onDelete)),
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
            FloorPlanCard(expectedName: 'ในห้อง 1', docs: docs, collectionName: collectionName, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 3', docs: docs, collectionName: collectionName, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 2', docs: docs, collectionName: collectionName, onDelete: onDelete),
            FloorPlanCard(expectedName: 'ในห้อง 4', docs: docs, collectionName: collectionName, onDelete: onDelete),
          ],
        ),
        const SizedBox(height: 24),
        Align(alignment: Alignment.center, child: _buildDoor('ประตูห้อง')),
      ],
    );
  }
}

// แสดงเวลาแบบ HH:mm น. (ไม่มีวินาที)
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
// LeaderboardScreen
// ==========================================
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {

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

  void _claimTitle(int currentScore, int requiredScore, String titleName) async {
    if (currentScore < requiredScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('คุณต้องการคะแนนอย่างน้อย $requiredScore แต้มเพื่อแลกฉายานี้ (ปัจจุบันมี $currentScore แต้ม)')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(globalUserId).update({
      'title': titleName,
    });

    setState(() => globalUserTitle = titleName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 ยินดีด้วย! คุณได้รับฉายา "$titleName" แล้ว!'), backgroundColor: Colors.green[700]),
      );
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
              Tab(icon: Icon(Icons.shopping_bag), text: 'ร้านค้าฉายา'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').orderBy('score', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final users = snapshot.data!.docs;
            int myCurrentScore = 0;

            for (var u in users) {
              if (u.id == globalUserId) {
                myCurrentScore = (u.data() as Map<String, dynamic>)['score'] ?? 0;
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
                          final score = userData['score'] ?? 0;
                          final title = userData['title'] ?? '';

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  buildUserAvatarWidget(avatar, radius: 24, fontSize: 24),
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
                                  Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
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
                              subtitle: Text('$score แต้ม', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                              trailing: PopupMenuButton<String>(
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
                          const Text('คะแนนสะสมของคุณ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('$myCurrentScore แต้ม', style: TextStyle(fontSize: 20, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('🎖️ เลือกแลกฉายาประจำตัว', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    _buildTitleRewardItem(
                      title: 'นักอัปเดตโต๊ะ 🥉',
                      requiredScore: 100,
                      currentScore: myCurrentScore,
                      onClaim: () => _claimTitle(myCurrentScore, 100, 'นักอัปเดตโต๊ะ 🥉'),
                    ),
                    const SizedBox(height: 10),
                    _buildTitleRewardItem(
                      title: 'นักอัปเดตโต๊ะจอมซน 😼',
                      requiredScore: 300,
                      currentScore: myCurrentScore,
                      onClaim: () => _claimTitle(myCurrentScore, 300, 'นักอัปเดตโต๊ะจอมซน 😼'),
                    ),
                    const SizedBox(height: 10),
                    _buildTitleRewardItem(
                      title: 'ยอดอัพเดตโต๊ะ 🥈',
                      requiredScore: 500,
                      currentScore: myCurrentScore,
                      onClaim: () => _claimTitle(myCurrentScore, 500, 'ยอดอัพเดตโต๊ะ 🥈'),
                    ),
                    const SizedBox(height: 10),
                    _buildTitleRewardItem(
                      title: 'ท่านเทพอัพเดตโต๊ะ 🥇',
                      requiredScore: 700,
                      currentScore: myCurrentScore,
                      onClaim: () => _claimTitle(myCurrentScore, 700, 'ท่านเทพอัพเดตโต๊ะ 🥇'),
                    ),
                    const SizedBox(height: 10),
                    _buildTitleRewardItem(
                      title: 'GMจอมขยัน 👑',
                      requiredScore: 1000,
                      currentScore: myCurrentScore,
                      onClaim: () => _claimTitle(myCurrentScore, 1000, 'GMจอมขยัน 👑'),
                    ),
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

  Widget _buildTitleRewardItem({
    required String title,
    required int requiredScore,
    required int currentScore,
    required VoidCallback onClaim,
  }) {
    final bool isEquipped = globalUserTitle == title;
    final bool canClaim = currentScore >= requiredScore;

    return Card(
      elevation: 2,
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
                Text('เงื่อนไข: $requiredScore แต้ม', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEquipped ? Colors.green[600] : (canClaim ? Colors.amber[700] : Colors.grey[400]),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: isEquipped ? null : onClaim,
              child: Text(
                isEquipped ? 'ใช้งานอยู่' : 'แลกฉายา',
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
                          buildUserAvatarWidget(senderAvatar, radius: 16, fontSize: 16),
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
                          buildUserAvatarWidget(senderAvatar, radius: 16, fontSize: 16),
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