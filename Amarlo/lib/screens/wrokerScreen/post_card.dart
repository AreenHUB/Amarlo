import 'package:flutter/material.dart';
import 'package:fourthapp/models/user.dart';
import 'package:fourthapp/screens/chat_screen.dart'; // Import ChatScreen
import 'package:shared_preferences/shared_preferences.dart';
import 'user_requests_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onAddOffer;
  final Function(String postId, String offerId, String content, double price)
      onEditOffer;
  final Function(String postId, String offerId) onDeleteOffer;

  const PostCard({
    Key? key,
    required this.post,
    required this.onAddOffer,
    required this.onEditOffer,
    required this.onDeleteOffer,
  }) : super(key: key);

  static Future<User?> getWorkerByEmail(String email) async {
    final response =
        await http.get(Uri.parse('http://10.0.2.2:8000/usersTwo?email=$email'));
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      if (jsonData is Map<String, dynamic>) {
        // Check if jsonData is a Map
        return User.fromJson(jsonData);
      } else {
        print("User not found or unexpected response format");
        return null;
      }
    } else {
      print("Error fetching worker: ${response.statusCode}");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  post.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chat),
                  onPressed: () async {
                    // Fetch the recipient's user data (including image)
                    User? recipientUser =
                        await getWorkerByEmail(post.creatorEmail);

                    // Fetch the worker's username before navigating
                    User? worker = await getWorkerByEmail(
                        post.offers?.first.workerEmail ?? '');
                    final prefs = await SharedPreferences.getInstance();
                    final workerEmail = prefs.getString('email');

                    if (recipientUser != null) {
                      // Check if recipientUser is not null

                      String? base64Image = recipientUser.imageBase64 != null
                          ? base64Encode(recipientUser.imageBase64!)
                          : null;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            recipientEmail: post.creatorEmail,
                            recipientUsername: post.creatorUsername,
                            recipientImageBase64: base64Image,
                          ),
                        ),
                      );
                    } else {
                      // Handle case where recipient user details couldn't be fetched
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Failed to get recipient user details"),
                      ));
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 8.0),
            Text(
              post.description,
              style: TextStyle(
                fontSize: 16.0,
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              'Price Range: ${post.priceRange}',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 8.0), // Spacing
            Text(
              'Posted by: ${post.creatorUsername}',
              style: TextStyle(fontSize: 14.0),
            ),
            SizedBox(height: 12.0),
            Expanded(
              child: post.offers != null && post.offers!.isNotEmpty
                  ? ListView.builder(
                      itemCount: post.offers!.length,
                      itemBuilder: (context, index) {
                        final offer = post.offers![index];
                        return FutureBuilder<User?>(
                          future: getWorkerByEmail(offer.workerEmail!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            } else if (snapshot.hasError || !snapshot.hasData) {
                              return ListTile(
                                title: Text(offer.content!),
                                subtitle: Text('Error loading user'),
                              );
                            } else {
                              final user = snapshot.data!;
                              final isCurrentUserOffer =
                                  user.email == offer.workerEmail;

                              return ListTile(
                                title: Text(offer.content!),
                                subtitle: Text(
                                    '${user.email} - \$${offer.price.toStringAsFixed(2)}'),
                                trailing: isCurrentUserOffer
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit),
                                            color: Colors.green,
                                            onPressed: () {
                                              _buildEditOfferDialog(
                                                  context, post, offer);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete),
                                            color: Colors.green,
                                            onPressed: () {
                                              _buildDeleteOfferDialog(
                                                  context, post, offer);
                                            },
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            }
                          },
                        );
                      },
                    )
                  : Center(
                      child: Text('No offers available'),
                    ),
            ),
            SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: onAddOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[400],
                foregroundColor: Colors.white,
              ),
              child: Text('Add Offer'),
            ),
          ],
        ),
      ),
    );
  }

  void _buildEditOfferDialog(BuildContext context, Post post, Offer offer) {
    TextEditingController contentController =
        TextEditingController(text: offer.content);
    TextEditingController priceController =
        TextEditingController(text: offer.price.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Offer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                decoration: InputDecoration(hintText: 'Offer Content'),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(hintText: 'Offer Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                onEditOffer(post.id, offer.id!, contentController.text,
                    double.parse(priceController.text));
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _buildDeleteOfferDialog(BuildContext context, Post post, Offer offer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Offer'),
          content: Text('Are you sure you want to delete this offer?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                onDeleteOffer(post.id, offer.id!);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
