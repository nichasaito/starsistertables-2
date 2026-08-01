import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

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
      home: const TableStatusScreen(),
    );
  }
}

class TableStatusScreen extends StatefulWidget {
  const TableStatusScreen({super.key});

  @override
  State<TableStatusScreen> createState() => _TableStatusScreenState();
}

class _TableStatusScreenState extends State<TableStatusScreen> {
  int _selectedIndex = 0;
  
  final List<String> _collections = const ['tables_f1', 'tables_f2', 'tables_f3'];
  final List<String> _menuTitles = const ['ชั้น 1', 'ชั้น 2', 'ชั้น 3'];

  void _showAddTableDialog(BuildContext context, String currentCollection) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('เพิ่มโต๊ะใหม่ (${_menuTitles[_selectedIndex]})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'พิมพ์ชื่อโต๊ะ',
              border: OutlineInputBorder(),
            ),
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
                  FirebaseFirestore.instance.collection(currentCollection).add({
                    'name': tableName,
                    'isAvailable': true,
                    'lastUpdated': Timestamp.now(),
                  });
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
    return Scaffold(
      appBar: AppBar(
        title: Text('StarSister Tables - ${_menuTitles[_selectedIndex]}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.blue[900], 
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 20),
              color: Colors.blue[900],
              child: const Center(
                child: Text(
                  'เลือกชั้น',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _menuTitles.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  return ListTile(
                    title: Text(
                      _menuTitles[index],
                      style: TextStyle(
                        color: isSelected ? Colors.blue[900] : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 18, 
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: Colors.blue[50],
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      Navigator.pop(context); 
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: TableGrid(
        key: ValueKey(_collections[_selectedIndex]),
        collectionName: _collections[_selectedIndex],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTableDialog(context, _collections[_selectedIndex]),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

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
    final CollectionReference tablesRef =
        FirebaseFirestore.instance.collection(collectionName);

    return StreamBuilder<QuerySnapshot>(
      stream: tablesRef.snapshots(), 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล', style: TextStyle(fontSize: 16)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        DateTime? latestTime;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['lastUpdated'] != null) {
            final Timestamp ts = data['lastUpdated'];
            final DateTime docTime = ts.toDate();
            if (latestTime == null) {
              latestTime = docTime;
            } else if (docTime.isAfter(latestTime)) {
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
          content = const Center(child: Text('ไม่มีข้อมูลแผนผัง', style: TextStyle(fontSize: 16)));
        }

        return Stack(
          children: [
            content,
            Positioned(
              bottom: 12,
              left: 12, 
              child: LastUpdateWidget(updateTime: lastUpdateTime), 
            ),
          ],
        );
      },
    );
  }
}

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

    if (targetDoc == null) {
      return Card(
        color: Colors.grey[100],
        elevation: 0,
        shape: isCircle
            ? const CircleBorder(side: BorderSide(color: Colors.grey, width: 2, style: BorderStyle.solid))
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.grey, width: 2, style: BorderStyle.solid),
              ),
        child: InkWell(
          customBorder: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () {
            FirebaseFirestore.instance.collection(collectionName).add({
              'name': expectedName,
              'isAvailable': true,
              'lastUpdated': Timestamp.now(),
            });
          },
          child: Center(
            child: Text(
              '$expectedName\n(แตะเพื่อสร้าง)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16), 
            ),
          ),
        ),
      );
    }

    final data = targetDoc.data() as Map<String, dynamic>;
    final String docId = targetDoc.id;
    final bool isAvailable = data['isAvailable'] ?? true;

    return Card(
      elevation: 4,
      color: isAvailable ? Colors.green[50] : Colors.red[50],
      shape: isCircle
          ? CircleBorder(side: BorderSide(color: isAvailable ? Colors.green : Colors.red, width: 2))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isAvailable ? Colors.green : Colors.red, width: 2),
            ),
      child: InkWell(
        customBorder: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () {
          FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
            'isAvailable': !isAvailable,
            'lastUpdated': Timestamp.now(),
          });
        },
        onLongPress: () => onDelete(docId, expectedName),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expectedName, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18) 
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isAvailable ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    isAvailable ? 'ว่าง' : 'ไม่ว่าง',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), 
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

Widget _buildDoor(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.blue[900]!, width: 3)),
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
  );
}

// ==========================================
// แผนผังชั้น 1
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
                        child: Text(
                          'บาร์น้ำ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue), 
                        ),
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

// ==========================================
// แผนผังชั้น 2
// ==========================================
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
        Align(
          alignment: Alignment.bottomRight,
          child: _buildDoor('ประตู'),
        ),
      ],
    );
  }
}

// ==========================================
// แผนผังชั้น 3 (แก้ไขโซนในห้องใหม่ให้ใช้ Grid)
// ==========================================
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
        
        // ใช้ GridView เพื่อให้โต๊ะทั้ง 4 สมส่วนกันแบบ 100%
        GridView.count(
          crossAxisCount: 2, // แบ่งเป็น 2 คอลัมน์ (ซ้าย-ขวา)
          shrinkWrap: true, // บังคับให้ Grid พอดีกับข้อมูลด้านใน
          physics: const NeverScrollableScrollPhysics(), // ปิดการเลื่อนของ Grid เพื่อให้เลื่อนไปกับหน้าจอหลักได้
          mainAxisSpacing: 16, // ระยะห่างแนวตั้ง
          crossAxisSpacing: 16, // ระยะห่างแนวนอน
          childAspectRatio: 1.15, // สัดส่วนโต๊ะ (กว้าง:สูง) 1.15 ทำให้เป็นทรงสี่เหลี่ยมโต๊ะสวยงาม
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

// ==========================================
// ระบบแสดงเวลาแบบตัวเลขบอกเวลา
// ==========================================
class LastUpdateWidget extends StatelessWidget {
  final DateTime updateTime;
  const LastUpdateWidget({super.key, required this.updateTime});

  @override
  Widget build(BuildContext context) {
    final h = updateTime.hour.toString().padLeft(2, '0');
    final m = updateTime.minute.toString().padLeft(2, '0');
    final s = updateTime.second.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Text(
        'อัปเดตล่าสุด: $h:$m:$s น.',
        style: TextStyle(color: Colors.blue[900], fontSize: 16, fontWeight: FontWeight.bold), 
      ),
    );
  }
}