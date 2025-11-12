import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'recipes_screen.dart';
import 'notifications_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
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
    File? selectedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Pantry Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Picker
                GestureDetector(
                  onTap: isUploading ? null : () async {
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setDialogState(() => selectedImage = File(image.path));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(selectedImage!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
                              const SizedBox(height: 8),
                              Text('Tap to add photo', style: GoogleFonts.poppins(color: Colors.grey[600])),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  enabled: !isUploading,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  enabled: !isUploading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isUploading ? null : () async {
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
                if (isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text('Uploading...', style: GoogleFonts.poppins(fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (nameController.text.isNotEmpty && selectedDate != null) {
                  setDialogState(() => isUploading = true);
                  
                  await _addItemToDatabase(
                    nameController.text,
                    selectedDate!,
                    int.tryParse(quantityController.text) ?? 1,
                    selectedImage,
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

  Future<void> _addItemToDatabase(String name, DateTime expiryDate, int quantity, File? imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? imageUrl;

    // Upload image to Firebase Storage if provided
    if (imageFile != null) {
      try {
        final String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = _storage.ref().child('pantry_items/$fileName');
        
        await storageRef.putFile(imageFile);
        imageUrl = await storageRef.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
      }
    }

    final newItemRef = _database.child('users/${user.uid}/pantry_items').push();
    
    await newItemRef.set({
      'name': name,
      'expiryDate': expiryDate.millisecondsSinceEpoch,
      'quantity': quantity,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'imageUrl': imageUrl,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to pantry!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.child('users/${user.uid}/pantry_items/$itemId').remove();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed from pantry'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _deleteExpiredItems() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _database.child('users/${user.uid}/pantry_items').get();
    
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>;
    final now = DateTime.now();
    int deletedCount = 0;

    for (var entry in data.entries) {
      final itemData = entry.value as Map<dynamic, dynamic>;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(itemData['expiryDate'] as int);
      final daysExpired = now.difference(expiryDate).inDays;

      // Delete items expired for more than 7 days
      if (daysExpired > 7) {
        await _database.child('users/${user.uid}/pantry_items/${entry.key}').remove();
        deletedCount++;
      }
    }

    if (mounted && deletedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $deletedCount expired item${deletedCount > 1 ? 's' : ''}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditItemDialog(String itemId, Map<dynamic, dynamic> itemData) {
    final nameController = TextEditingController(text: itemData['name']);
    final quantityController = TextEditingController(text: itemData['quantity'].toString());
    DateTime selectedDate = DateTime.fromMillisecondsSinceEpoch(itemData['expiryDate'] as int);
    File? selectedImage;
    String? currentImageUrl = itemData['imageUrl'];
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Picker
                GestureDetector(
                  onTap: isUploading ? null : () async {
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setDialogState(() {
                        selectedImage = File(image.path);
                        currentImageUrl = null; // Clear old image preview
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(selectedImage!, fit: BoxFit.cover),
                          )
                        : (currentImageUrl != null && currentImageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  currentImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
                                        const SizedBox(height: 8),
                                        Text('Tap to change photo', style: GoogleFonts.poppins(color: Colors.grey[600])),
                                      ],
                                    );
                                  },
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text('Tap to change photo', style: GoogleFonts.poppins(color: Colors.grey[600])),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  enabled: !isUploading,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  enabled: !isUploading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isUploading ? null : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Expiry: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
                if (isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text('Updating...', style: GoogleFonts.poppins(fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isUploading ? null : () async {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    content: Text('Are you sure you want to delete this item?', style: GoogleFonts.poppins()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                
                if (shouldDelete == true) {
                  Navigator.pop(context);
                  await _deleteItem(itemId);
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (nameController.text.isNotEmpty) {
                  setDialogState(() => isUploading = true);
                  
                  await _updateItemInDatabase(
                    itemId,
                    nameController.text,
                    selectedDate,
                    int.tryParse(quantityController.text) ?? 1,
                    selectedImage,
                    currentImageUrl,
                  );
                  
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA500)),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateItemInDatabase(
    String itemId,
    String name,
    DateTime expiryDate,
    int quantity,
    File? imageFile,
    String? currentImageUrl,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? imageUrl = currentImageUrl;

    // Upload new image if provided
    if (imageFile != null) {
      try {
        final String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = _storage.ref().child('pantry_items/$fileName');
        
        await storageRef.putFile(imageFile);
        imageUrl = await storageRef.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
      }
    }

    await _database.child('users/${user.uid}/pantry_items/$itemId').update({
      'name': name,
      'expiryDate': expiryDate.millisecondsSinceEpoch,
      'quantity': quantity,
      'imageUrl': imageUrl,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name updated!'), backgroundColor: Colors.green),
      );
    }
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

  void _showEditProfileDialog() {
    final user = _auth.currentUser;
    if (user == null) return;

    final displayNameController = TextEditingController(text: user.displayName ?? '');
    final emailController = TextEditingController(text: user.email ?? '');
    File? selectedProfileImage;
    String? currentPhotoURL = user.photoURL;
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile Picture
                GestureDetector(
                  onTap: isUpdating ? null : () async {
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 400,
                      maxHeight: 400,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setDialogState(() {
                        selectedProfileImage = File(image.path);
                        currentPhotoURL = null; // Clear old preview
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFFFA500),
                        backgroundImage: selectedProfileImage != null
                            ? FileImage(selectedProfileImage!) as ImageProvider
                            : (currentPhotoURL != null && currentPhotoURL!.isNotEmpty)
                                ? NetworkImage(currentPhotoURL!)
                                : null,
                        child: (selectedProfileImage == null && 
                               (currentPhotoURL == null || currentPhotoURL!.isEmpty))
                            ? const Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFA500), width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 20, color: Color(0xFFFFA500)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tap to change photo', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 24),
                TextField(
                  controller: displayNameController,
                  enabled: !isUpdating,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  enabled: false, // Email can't be changed easily
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: isUpdating ? null : () {
                    Navigator.pop(context);
                    _showChangePasswordDialog();
                  },
                  icon: const Icon(Icons.lock),
                  label: const Text('Change Password'),
                ),
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                setDialogState(() => isUpdating = true);
                
                try {
                  // Upload profile picture if selected
                  String? photoURL = currentPhotoURL;
                  if (selectedProfileImage != null) {
                    final String fileName = '${user.uid}_profile.jpg';
                    final Reference storageRef = _storage.ref().child('profile_pictures/$fileName');
                    await storageRef.putFile(selectedProfileImage!);
                    photoURL = await storageRef.getDownloadURL();
                  }
                  
                  // Update profile
                  await user.updateDisplayName(displayNameController.text.trim());
                  if (photoURL != null) {
                    await user.updatePhotoURL(photoURL);
                  }
                  await user.reload();
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {}); // Refresh UI
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setDialogState(() => isUpdating = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA500)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Change Password', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  enabled: !isUpdating,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  enabled: !isUpdating,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  enabled: !isUpdating,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isUpdating = true);
                
                try {
                  final user = _auth.currentUser!;
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPasswordController.text,
                  );
                  
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString().contains('wrong-password') ? 'Current password is incorrect' : e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setDialogState(() => isUpdating = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA500)),
              child: const Text('Update Password', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
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
              leading: const Icon(Icons.person),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clean Expired Items'),
              onTap: () async {
                Navigator.pop(context);
                await _deleteExpiredItems();
              },
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
                Navigator.pop(context); // Close drawer first
                
                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    content: Text('Are you sure you want to logout?', style: GoogleFonts.poppins()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Logout', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                
                if (shouldLogout == true) {
                  await _auth.signOut();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
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
                          child: InkWell(
                            onTap: () => _showEditItemDialog(itemId, itemData),
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
                                    child: (itemData['imageUrl'] != null && itemData['imageUrl'].toString().isNotEmpty)
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              itemData['imageUrl'].toString(),
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                            loadingProgress.expectedTotalBytes!
                                                        : null,
                                                    color: Colors.white,
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(
                                                  Icons.fastfood,
                                                  color: Colors.white,
                                                  size: 40,
                                                );
                                              },
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
    ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}