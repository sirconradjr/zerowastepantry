import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _expiringItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpiringItems();
  }

  Future<void> _loadExpiringItems() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _database
        .child('users/${user.uid}/pantry_items')
        .get();

    if (!snapshot.exists) {
      setState(() => _isLoading = false);
      return;
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final now = DateTime.now();
    final items = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      final itemData = value as Map<dynamic, dynamic>;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(
        itemData['expiryDate'] as int
      );
      final daysLeft = expiryDate.difference(now).inDays;
      
      if (daysLeft <= 7) {
        items.add({
          'name': itemData['name'],
          'expiryDate': expiryDate,
          'daysLeft': daysLeft,
        });
      }
    });

    // Sort by days left
    items.sort((a, b) => a['daysLeft'].compareTo(b['daysLeft']));

    setState(() {
      _expiringItems = items;
      _isLoading = false;
    });
  }

  // Sample recipes - you can replace this with an API call later
  final List<Map<String, String>> _sampleRecipes = [
    {
      'title': 'Vegetable Stir Fry',
      'ingredients': 'Mixed vegetables, soy sauce, garlic',
      'time': '20 min',
    },
    {
      'title': 'Fresh Salad Bowl',
      'ingredients': 'Lettuce, tomatoes, cucumber, dressing',
      'time': '10 min',
    },
    {
      'title': 'Pasta Primavera',
      'ingredients': 'Pasta, seasonal vegetables, olive oil',
      'time': '25 min',
    },
    {
      'title': 'Quick Soup',
      'ingredients': 'Vegetables, broth, herbs',
      'time': '30 min',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recipe Suggestions', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFFA500),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expiring Items Section
                  if (_expiringItems.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                'Items Expiring Soon',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._expiringItems.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${item['name']} (${_getDaysLeft(item['expiryDate'])})',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              )),
                          const SizedBox(height: 8),
                          Text(
                            'Try recipes that use these ingredients!',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Recipe Suggestions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Suggested Recipes',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _sampleRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _sampleRecipes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: Color(0xFFFFA500),
                              size: 30,
                            ),
                          ),
                          title: Text(
                            recipe['title']!,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                recipe['ingredients']!,
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    recipe['time']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16),
                          onTap: () {
                            // Show recipe details
                            _showRecipeDetails(recipe);
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  String _getDaysLeft(DateTime expiryDate) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft == 0) return 'expires today';
    if (daysLeft == 1) return 'expires tomorrow';
    return 'expires in $daysLeft days';
  }

  void _showRecipeDetails(Map<String, String> recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe['title']!,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ingredients:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(recipe['ingredients']!, style: GoogleFonts.poppins()),
            const SizedBox(height: 16),
            Text('Cooking Time: ${recipe['time']}',
                style: GoogleFonts.poppins()),
            const SizedBox(height: 16),
            Text(
              'Full recipe instructions coming soon!',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}