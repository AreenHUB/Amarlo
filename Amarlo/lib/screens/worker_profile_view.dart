
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fourthapp/models/review.dart';
import 'package:fourthapp/models/user.dart';
import 'package:fourthapp/models/service.dart';
import 'package:fourthapp/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'chat_screen.dart';

class WorkerProfileViewPage extends StatefulWidget {
  final String email;

  const WorkerProfileViewPage({Key? key, required this.email})
      : super(key: key);

  @override
  _WorkerProfileViewPageState createState() => _WorkerProfileViewPageState();
}

class _WorkerProfileViewPageState extends State<WorkerProfileViewPage> {
  User? worker;
  List<Service> services = [];
  List<Review> reviews = [];
  TextEditingController _reviewController = TextEditingController();
  double _rating = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchWorkerData();
  }

  Future<void> _fetchWorkerData() async {
    try {
      worker = await ApiService.getWorkerByEmail(widget.email);
      services = await ApiService.getWorkerServicesByEmail(widget.email);
      reviews = await ApiService.getReviewsForWorker(widget.email);
      setState(() {});
    } catch (e) {
      print("Error fetching worker data: $e");
    }
  }

  Future<void> _submitReview() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id');
    final currentUserEmail = prefs.getString('email');

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to add a review.')));
      return;
    }

    if (currentUserEmail == worker!.email) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('You cannot review yourself.')));
      return;
    }

    if (_rating == 0.0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please select a rating.')));
      return;
    }

    try {
      Review newReview = Review(
        rating: _rating.toInt(),
        comment: _reviewController.text,
        reviewerUsername: '', // Change this as needed
        reviewerEmail: currentUserEmail ?? '', // Add this linez
      );

      await ApiService.addReview(widget.email, newReview);

      _reviewController.clear();
      setState(() {
        _rating = 0.0;
        reviews.add(newReview);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Review added successfully!')));
    } catch (e) {
      print("Failed to add review: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add review.')));
    }
  }

  Future<String?> _getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  void _navigateToChat(BuildContext context, User worker) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id');

    if (currentUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            recipientEmail: worker.email,
            recipientUsername: worker.username,
          ),
        ),
      );
    } else {
      print("Error: Current user ID not found.");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("You need to be logged in to chat."),
      ));
    }
  }

  Future<void> _editReview(Review review) async {
    int updatedRating = review.rating;
    String updatedComment = review.comment ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: updatedRating.toDouble(),
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                updatedRating = rating.toInt();
              },
            ),
            SizedBox(height: 10),
            TextField(
              onChanged: (value) => updatedComment = value,
              decoration: InputDecoration(
                hintText: 'Edit your comment',
              ),
              controller: TextEditingController(text: updatedComment),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ApiService.updateReview(
                  review.id!,
                  Review(
                    rating: updatedRating,
                    comment: updatedComment,
                    reviewerUsername: review.reviewerUsername,
                    reviewerEmail: '',
                  ),
                );
                _fetchWorkerData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Review updated!'),
                ));
              } catch (e) {
                print("Error updating review: $e");
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed to update review.'),
                ));
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await ApiService.deleteReview(reviewId);
      _fetchWorkerData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Review deleted!'),
      ));
    } catch (e) {
      print("Error deleting review: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to delete review.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(worker?.username ?? 'Worker Profile'),
      ),
      body: worker != null
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (worker!.imageBase64 != null)
                    Image.memory(
                      worker!.imageBase64!,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.5,
                      fit: BoxFit.cover,
                    ),
                  SizedBox(height: 20),

                  // About Me Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Me',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(worker!.introduction ??
                            'No introduction available'),
                        SizedBox(height: 20),
                        Text(
                          'Social Media Links',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                                width:
                                    5), // Add some spacing between the text and icon
                            Icon(FontAwesomeIcons.facebook,
                                size: 16, color: Colors.blue),
                            Text('  Facebook: ${worker!.facebook ?? 'N/A'}'),
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(width: 5),
                            Icon(FontAwesomeIcons.instagram,
                                size: 16, color: Colors.pink),
                            Text('  Instagram: ${worker!.instagram ?? 'N/A'}'),
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(width: 5),
                            Icon(FontAwesomeIcons.telegram,
                                size: 16, color: Colors.blue),
                            Text('  Telegram: ${worker!.telegram ?? 'N/A'}'),
                          ],
                        ),
                        SizedBox(height: 20)
                      ],
                    ),
                  ),

                  // Services Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Services',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: services.length,
                          itemBuilder: (context, index) {
                            final service = services[index];
                            return ListTile(
                              title: Text(service.name),
                              subtitle: Text(service.location),
                              leading: service.imageBase64 != null
                                  ? Image.memory(
                                      base64Decode(service.imageBase64!),
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(Icons.image),
                            );
                          },
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _navigateToChat(context, worker!),
                          child: Text("Chat"),
                        ),
                      ],
                    ),
                  ),

                  // Reviews Section
                  _buildReviewsSection(),
                ],
              ),
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),

          // Display average rating
          if (reviews.isNotEmpty)
            Center(
              child: RatingBarIndicator(
                rating: reviews
                        .map((review) => review.rating)
                        .reduce((a, b) => a + b) /
                    reviews.length,
                itemBuilder: (context, index) => Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                itemCount: 5,
                itemSize: 30.0,
                direction: Axis.horizontal,
              ),
            ),

          SizedBox(height: 10),

          FutureBuilder<List<Review>>(
            future: ApiService.getReviewsForWorker(worker!.email),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No reviews yet.'));
              } else {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final review = snapshot.data![index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(review.reviewerUsername),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RatingBarIndicator(
                              rating: review.rating.toDouble(),
                              itemBuilder: (context, index) => Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              itemCount: 5,
                              itemSize: 20.0,
                              direction: Axis.horizontal,
                            ),
                            if (review.comment != null &&
                                review.comment!.isNotEmpty)
                              Text(review.comment!),
                            // Add Edit and Delete Buttons here

                            // Get current user's email
                            FutureBuilder<String?>(
                              future: _getCurrentUserEmail(),
                              builder: (context, emailSnapshot) {
                                if (emailSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return SizedBox(); // or a loading indicator
                                } else if (emailSnapshot.hasError) {
                                  return Text('Error: ${emailSnapshot.error}');
                                } else {
                                  final currentUserEmail =
                                      emailSnapshot.data ?? ''; // Get the email

                                  // Now compare emails
                                  if (review.reviewerEmail ==
                                      currentUserEmail) {
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit),
                                          onPressed: () => _editReview(review),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete),
                                          onPressed: () =>
                                              _deleteReview(review.id!),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return SizedBox(); // No buttons if not the author
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),

          // Add Review Section
          Divider(height: 30),
          Text('Add Your Review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() {
                _rating = rating;
              });
            },
          ),
          SizedBox(height: 10),
          TextField(
            controller: _reviewController,
            decoration: InputDecoration(
              hintText: 'Write your review (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: _submitReview,
            child: Text('Submit Review'),
          ),
        ],
      ),
    );
  }
}
