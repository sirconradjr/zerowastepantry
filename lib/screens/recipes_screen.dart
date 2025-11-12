import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _nearExpiryItems = [];
  List<Map<String, dynamic>> _suggestedRecipes = [];
  bool _isLoading = true;
  bool _isLoadingRecipes = false;

  final String _apiKey = 'ea5b0d3b61ca4a26b74003d08bc33817';

  @override
  void initState() {
    super.initState();
    _loadNearExpiryItems();
  }

  Future<void> _loadNearExpiryItems() async {
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
      
      // Only include items expiring within 7 days (Near Expiry)
      if (daysLeft >= 0 && daysLeft <= 7) {
        items.add({
          'name': itemData['name'],
          'expiryDate': expiryDate,
          'daysLeft': daysLeft,
        });
      }
    });

    // Sort by days left (most urgent first)
    items.sort((a, b) => a['daysLeft'].compareTo(b['daysLeft']));

    setState(() {
      _nearExpiryItems = items;
      _isLoading = false;
    });

    // Auto-generate recipes if there are near-expiry items
    if (items.isNotEmpty) {
      _fetchRecipesFromAPI();
    }
  }

  Future<void> _fetchRecipesFromAPI() async {
    if (_nearExpiryItems.isEmpty) return;

    setState(() => _isLoadingRecipes = true);

    // Get ingredient names - only near expiry items
    final ingredients = _nearExpiryItems.map((item) => item['name'] as String).join(',');
    
    try {
      // Using Spoonacular API - Find by Ingredients endpoint
      final url = Uri.parse(
        'https://api.spoonacular.com/recipes/findByIngredients?'
        'apiKey=$_apiKey&'
        'ingredients=$ingredients&'
        'number=10&'
        'ranking=2&' // Maximize used ingredients
        'ignorePantry=true'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> recipesData = json.decode(response.body);
        final recipes = <Map<String, dynamic>>[];

        for (var recipe in recipesData) {
          // Get detailed recipe information
          final detailUrl = Uri.parse(
            'https://api.spoonacular.com/recipes/${recipe['id']}/information?'
            'apiKey=$_apiKey'
          );
          
          final detailResponse = await http.get(detailUrl);
          
          if (detailResponse.statusCode == 200) {
            final recipeDetail = json.decode(detailResponse.body);
            
            // Extract only the ingredients from our pantry that are used
            final usedIngredients = (recipe['usedIngredients'] as List)
                .map((ing) => ing['name'].toString())
                .toList();
            
            recipes.add({
              'id': recipe['id'],
              'title': recipe['title'],
              'image': recipe['image'],
              'usedIngredientCount': recipe['usedIngredientCount'],
              'missedIngredientCount': recipe['missedIngredientCount'],
              'usedIngredients': usedIngredients,
              'missedIngredients': (recipe['missedIngredients'] as List)
                  .map((ing) => ing['name'].toString())
                  .toList(),
              'readyInMinutes': recipeDetail['readyInMinutes'] ?? 30,
              'servings': recipeDetail['servings'] ?? 2,
              'instructions': recipeDetail['instructions'] ?? 'Instructions not available',
              'sourceUrl': recipeDetail['sourceUrl'],
            });
          }
        }

        setState(() {
          _suggestedRecipes = recipes;
          _isLoadingRecipes = false;
        });
      } else {
        // Fallback to local recipes if API fails
        _generateLocalRecipes();
      }
    } catch (e) {
      print('Error fetching recipes: $e');
      // Fallback to local recipes
      _generateLocalRecipes();
    }
  }

  void _generateLocalRecipes() {
    // Fallback local recipes
    final ingredients = _nearExpiryItems.map((item) => item['name'] as String).toList();
    
    final recipes = <Map<String, dynamic>>[
      {
        'title': 'Quick Stir Fry',
        'description': 'Use up your fresh ingredients in a delicious stir fry',
        'time': '15 min',
        'difficulty': 'Easy',
        'usedIngredients': ingredients.take(3).toList(),
        'instructions': [
          'Heat oil in a large pan or wok over high heat',
          'Add your ingredients: ${ingredients.take(3).join(', ')}',
          'Stir fry for 5-7 minutes until cooked',
          'Season with soy sauce, garlic, and ginger',
          'Serve hot with rice or noodles'
        ],
      },
      {
        'title': 'Fresh Salad Mix',
        'description': 'A healthy way to use fresh produce before it expires',
        'time': '10 min',
        'difficulty': 'Easy',
        'usedIngredients': ingredients.take(4).toList(),
        'instructions': [
          'Wash and chop: ${ingredients.take(4).join(', ')}',
          'Combine in a large bowl',
          'Add your favorite dressing',
          'Toss well and serve immediately',
          'Optional: Add nuts or cheese for extra flavor'
        ],
      },
    ];

    setState(() {
      _suggestedRecipes = recipes;
      _isLoadingRecipes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recipe Suggestions', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFFA500),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadNearExpiryItems();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _nearExpiryItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
                      const SizedBox(height: 16),
                      Text(
                        'All items are fresh!',
                        style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No near-expiry items to make recipes with',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Near Expiry Items Section
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
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  'Expiring Soon (Use These!)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._nearExpiryItems.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: item['daysLeft'] <= 1 
                                            ? Colors.red 
                                            : item['daysLeft'] <= 3 
                                                ? Colors.orange 
                                                : Colors.yellow[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${item['name']} (${_getDaysLeft(item['expiryDate'])})',
                                          style: GoogleFonts.poppins(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 8),
                            Text(
                              'All recipes below use ONLY these ingredients!',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Recipe Suggestions Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Suggested Recipes',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isLoadingRecipes)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),

                      // Recipe Cards
                      if (_suggestedRecipes.isEmpty && !_isLoadingRecipes)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No recipes available. Try refreshing!',
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _suggestedRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = _suggestedRecipes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _showRecipeDetails(recipe),
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Recipe Image (if available from API)
                                    if (recipe['image'] != null)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: Image.network(
                                          recipe['image'],
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: 150,
                                              color: Colors.orange[100],
                                              child: const Icon(Icons.restaurant, size: 50, color: Color(0xFFFFA500)),
                                            );
                                          },
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recipe['title']!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Show which pantry ingredients are used
                                          if (recipe['usedIngredients'] != null)
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: (recipe['usedIngredients'] as List).map((ing) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[100],
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '✓ $ing',
                                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.green[800]),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          if (recipe['missedIngredients'] != null && 
                                              (recipe['missedIngredients'] as List).isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                'Additional: ${(recipe['missedIngredients'] as List).join(', ')}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildInfoChip(
                                                Icons.access_time,
                                                '${recipe['readyInMinutes'] ?? recipe['time'] ?? '30'} min',
                                                Colors.blue,
                                              ),
                                              if (recipe['servings'] != null)
                                                _buildInfoChip(
                                                  Icons.restaurant_menu,
                                                  '${recipe['servings']} servings',
                                                  Colors.orange,
                                                ),
                                              if (recipe['usedIngredientCount'] != null)
                                                _buildInfoChip(
                                                  Icons.check_circle,
                                                  '${recipe['usedIngredientCount']} from pantry',
                                                  Colors.green,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getDaysLeft(DateTime expiryDate) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft == 0) return 'expires today';
    if (daysLeft == 1) return 'expires tomorrow';
    return 'expires in $daysLeft days';
  }

  void _showRecipeDetails(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  recipe['title']!,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.access_time,
                      '${recipe['readyInMinutes'] ?? recipe['time'] ?? '30'} min',
                      Colors.blue,
                    ),
                    if (recipe['servings'] != null)
                      _buildInfoChip(Icons.restaurant_menu, '${recipe['servings']} servings', Colors.orange),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Ingredients from your pantry:',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...(recipe['usedIngredients'] as List).map((ingredient) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            ingredient,
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),
                Text(
                  'Instructions:',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (recipe['instructions'] is List)
                  ...(recipe['instructions'] as List).asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFA500),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Text(
                    recipe['instructions'] ?? 'No instructions available',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                const SizedBox(height: 20),
                if (recipe['sourceUrl'] != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      // You can use url_launcher package to open the URL
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Full recipe: ${recipe['sourceUrl']}')),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View Full Recipe'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}