import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFFA500),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DatabaseEvent>(
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
                  Icon(Icons.notifications_none,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          
          // Generate notifications based on expiry dates
          final notifications = <Map<String, dynamic>>[];
          final now = DateTime.now();

          data.forEach((key, value) {
            final itemData = value as Map<dynamic, dynamic>;
            final expiryDate = DateTime.fromMillisecondsSinceEpoch(
              itemData['expiryDate'] as int
            );
            final daysLeft = expiryDate.difference(now).inDays;

            String title;
            String message;
            IconData icon;
            Color color;

            if (daysLeft < 0) {
              title = 'Item Expired';
              message = '${itemData['name']} has expired. Consider removing it.';
              icon = Icons.error_outline;
              color = Colors.red;
            } else if (daysLeft == 0) {
              title = 'Expires Today';
              message = '${itemData['name']} expires today! Use it now.';
              icon = Icons.warning_amber_rounded;
              color = Colors.red;
            } else if (daysLeft == 1) {
              title = 'Expires Tomorrow';
              message = '${itemData['name']} expires tomorrow.';
              icon = Icons.notifications_active;
              color = Colors.orange;
            } else if (daysLeft <= 3) {
              title = 'Expiring Soon';
              message = '${itemData['name']} expires in $daysLeft days.';
              icon = Icons.notifications;
              color = Colors.orange;
            } else if (daysLeft <= 7) {
              title = 'Check Expiry Date';
              message = '${itemData['name']} expires in $daysLeft days.';
              icon = Icons.info_outline;
              color = Colors.blue;
            } else {
              return; // Skip items with more than 7 days
            }

            notifications.add({
              'title': title,
              'message': message,
              'icon': icon,
              'color': color,
              'itemName': itemData['name'],
              'daysLeft': daysLeft,
              'timestamp': expiryDate,
            });
          });

          // Sort by urgency (days left)
          notifications.sort((a, b) => a['daysLeft'].compareTo(b['daysLeft']));

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.green[300]),
                  const SizedBox(height: 16),
                  Text(
                    'All items are fresh!',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No items expiring soon',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: notification['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      notification['icon'],
                      color: notification['color'],
                      size: 28,
                    ),
                  ),
                  title: Text(
                    notification['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      notification['message'],
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                  trailing: notification['daysLeft'] <= 1
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'URGENT',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}