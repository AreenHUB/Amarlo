import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fourthapp/models/user.dart';
import 'package:fourthapp/screens/chat_screen.dart';

import 'models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OffersScreen extends StatefulWidget {
  final List<Offer> offers;
  const OffersScreen({Key? key, required this.offers}) : super(key: key);

  @override
  _OffersScreenState createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.offers.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: widget.offers.length,
                  itemBuilder: (context, index) {
                    final offer = widget.offers[index];
                    return OfferCard(
                      offer: offer,
                      onAccept: () =>
                          _handleOfferAction(context, offer, 'accept'),
                      onReject: () =>
                          _handleOfferAction(context, offer, 'reject'),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No offers yet'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOfferAction(
      BuildContext context, Offer offer, String action) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      try {
        final response = await http.put(
          Uri.parse(
              'http://10.0.2.2:8000/api/v1/posts/${offer.postTitle}/offers/${offer.id}/${action}'),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          // Update the offer status in your local list
          final updatedOffers = widget.offers.map((o) {
            if (o.id == offer.id) {
              return Offer.fromJson({
                ...o.toJson(),
                'status': action == 'accept' ? 'accepted' : 'rejected'
              });
            }
            return o;
          }).toList();

          setState(() {
            widget.offers.clear();
            widget.offers.addAll(updatedOffers);
          });

          // Provide feedback to the user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Offer ${action == 'accept' ? 'accepted' : 'rejected'} successfully')),
          );
        } else {
          print('Error ${action}ing offer: ${response.statusCode}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to ${action} offer')),
          );
        }
      } catch (e) {
        print('Error ${action}ing offer: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${action} offer')),
        );
      }
    }
  }
}

class OfferCard extends StatelessWidget {
  final Offer offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const OfferCard(
      {Key? key,
      required this.offer,
      required this.onAccept,
      required this.onReject})
      : super(key: key);

  Future<User?> _getWorkerDetails(String workerEmail) async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/users?email=$workerEmail'),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      if (jsonData is Map<String, dynamic>) {
        return User.fromJson(jsonData);
      } else {
        print("Worker not found or unexpected response format");
        return null;
      }
    } else {
      print("Error fetching worker details: ${response.statusCode}");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  offer.content,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Price: \$${offer.price}',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.0),
            if (offer.postTitle != null)
              Text(
                'Post: ${offer.postTitle}',
                style: TextStyle(fontSize: 16.0),
              ),
            SizedBox(height: 8.0),
            Row(
              children: [
                Icon(Icons.person),
                SizedBox(width: 4.0),
                Text('From: ${offer.workerEmail}'),
              ],
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: offer.status == 'pending' ? onAccept : null,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text('Accept'),
                ),
                ElevatedButton(
                  onPressed: offer.status == 'pending' ? onReject : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('Reject'),
                ),
                IconButton(
                  icon: Icon(Icons.chat),
                  onPressed: () async {
                    // Fetch worker details (username and image)
                    User? worker = await _getWorkerDetails(offer.workerEmail);

                    if (worker != null) {
                      String? base64Image = worker.imageBase64 != null
                          ? base64Encode(worker.imageBase64!)
                          : null;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            recipientEmail: offer.workerEmail,
                            recipientUsername: worker.username,
                            recipientImageBase64: base64Image,
                          ),
                        ),
                      );
                    } else {
                      // Handle case where worker details couldn't be fetched
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Failed to get worker details"),
                      ));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
