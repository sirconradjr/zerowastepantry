import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'recipes_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentIndex = 0;
  String _searchQuery = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Calculate days until expiry and return status
  Map<String, dynamic> _getExpiryStatus(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    
    String status;
    Color color;
    
    if (difference > 7) {
      status = 'Fresh';
      color = Colors.green;
    } else if (difference >= 3 && difference <= 7) {
      status = 'Soon Expiring';
      color = Colors.yellow[700]!;
    } else {
      status = 'Expiring';
      color = Colors.red;
    }
    
    return {'status': status, 'color': color, 'daysLeft': difference};
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Pantry Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    selectedDate == null
                        ? 'Select Expiry Date'
                        : 'Expiry: ${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && selectedDate != null) {
                  await _addItemToDatabase(
                    nameController.text,
                    selectedDate!,
                    int.tryParse(quantityController.text) ?? 1,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA500)),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItemToDatabase(String name, DateTime expiryDate, int quantity) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newItemRef = _database.child('users/${user.uid}/pantry_items').push();
    
    await newItemRef.set({
      'name': name,
      'expiryDate': expiryDate.millisecondsSinceEpoch,
      'quantity': quantity,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'imageUrl': null,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name added to pantry!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/pantry_items/$itemId').remove();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item removed from pantry'), backgroundColor: Colors.orange),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Fresh':
        return Colors.green;
      case 'Soon Expiring':
        return Colors.yellow[700]!;
      case 'Expiring':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFA500),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFFFA500)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35, color: Color(0xFFFFA500)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.email ?? 'User',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Recipes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Add settings screen later
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await _auth.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // User Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 12),
                  // Greeting Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.displayName ?? user?.email?.split('@')[0] ?? 'User'} !',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'What are you hungry for today?',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Menu Button
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search for foods',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Pantry Items List
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: StreamBuilder<DatabaseEvent>(
                  stream: _database
                      .child('users/${user?.uid}/pantry_items')
                      .onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No items in pantry',
                              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add items',
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      );
                    }

                    final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    var items = data.entries.toList();
                    
                    // Sort by expiry date
                    items.sort((a, b) {
                      final aExpiry = (a.value as Map)['expiryDate'] as int;
                      final bExpiry = (b.value as Map)['expiryDate'] as int;
                      return aExpiry.compareTo(bExpiry);
                    });
                    
                    // Filter items based on search query
                    if (_searchQuery.isNotEmpty) {
                      items = items.where((entry) {
                        final itemData = entry.value as Map<dynamic, dynamic>;
                        final name = itemData['name']?.toString().toLowerCase() ?? '';
                        return name.contains(_searchQuery);
                      }).toList();
                    }

                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No items found',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final entry = items[index];
                        final itemData = entry.value as Map<dynamic, dynamic>;
                        final itemId = entry.key as String;
                        final expiryDate = DateTime.fromMillisecondsSinceEpoch(
                          itemData['expiryDate'] as int
                        );
                        final statusInfo = _getExpiryStatus(expiryDate);
                        
                        return Dismissible(
                          key: Key(itemId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white, size: 32),
                          ),
                          onDismissed: (direction) => _deleteItem(itemId),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  // Product Image Placeholder
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCC8400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: itemData['imageUrl'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              itemData['imageUrl'],
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.fastfood,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Product Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemData['name'] ?? 'Unknown Item',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Expiry date: ${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${statusInfo['daysLeft']} days left',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Status Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: statusInfo['color'],
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                statusInfo['status'],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFFFA500),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
        ],
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecipesScreen()),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
              break;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}