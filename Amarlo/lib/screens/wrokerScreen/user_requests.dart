import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'user_requests_model.dart';
import 'post_card.dart';
import 'offer_form.dart';
import 'post_search_delegate.dart';

class UserRequestsScreen extends StatefulWidget {
  @override
  _UserRequestsScreenState createState() => _UserRequestsScreenState();
}

class _UserRequestsScreenState extends State<UserRequestsScreen> {
  List<Post> _posts = [];
  List<Post> _filteredPosts = [];
  String? _accessToken;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserEmail();
    _fetchPosts();
  }

  Future<void> _fetchCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('currentUserEmail');
    setState(() {
      _currentUserEmail = userEmail;
    });
  }

  Future<void> _fetchPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      setState(() {
        _accessToken = accessToken;
      });

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/v1/posts/public/all'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final postsData = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _posts = postsData.map((post) => Post.fromJson(post)).toList();
          _posts.sort((a, b) => a.title.compareTo(b.title));
          _filteredPosts = _posts;
        });
      } else {
        _showError('Failed to fetch posts');
      }
    } else {
      _showError('No access token found');
    }
  }

  Future<void> _sendOffer(String postId, String content, double price) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/v1/posts/$postId/offers'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'content': content,
        'price': price,
      }),
    );

    if (response.statusCode == 200) {
      _fetchPosts();
    } else {
      _showError('Failed to send offer');
    }
  }

  Future<void> _editOffer(
      String postId, String offerId, String content, double price) async {
    final response = await http.put(
      Uri.parse('http://10.0.2.2:8000/api/v1/posts/$postId/offers/$offerId'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'content': content, 'price': price}),
    );

    if (response.statusCode == 200) {
      _fetchPosts();
    } else {
      _showError('Failed to edit offer');
    }
  }

  Future<void> _deleteOffer(String postId, String offerId) async {
    final response = await http.delete(
      Uri.parse('http://10.0.2.2:8000/api/v1/posts/$postId/offers/$offerId'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      _fetchPosts();
    } else {
      _showError('Failed to delete offer');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showOfferForm(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: OfferForm(
            postId: post.id,
            onSubmit: (content, price) => _sendOffer(post.id, content, price),
          ),
        );
      },
    );
  }

  void _filterPosts() {
    setState(() {
      if (_searchQuery.isEmpty && _selectedCategory == null) {
        _filteredPosts = _posts;
      } else {
        _filteredPosts = _posts.where((post) {
          final matchesSearchQuery =
              post.title.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesCategory =
              _selectedCategory == null || post.category == _selectedCategory;

          return matchesSearchQuery && matchesCategory;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = _posts.map((post) => post.category).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('User Requests'),
        backgroundColor: Colors.brown[400],
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: PostSearchDelegate(
                  posts: _posts,
                  onSearch: (query) {
                    setState(() {
                      _searchQuery = query;
                      _filterPosts();
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory =
                            _selectedCategory == category ? null : category;
                        _filterPosts();
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.0),
                      padding:
                          EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: _selectedCategory == category
                            ? Colors.brown[400]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Text(
                        category ?? 'Uncategorized',
                        style: TextStyle(
                          color: _selectedCategory == category
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: _filteredPosts.length,
              itemBuilder: (context, index) {
                final post = _filteredPosts[index];
                return PostCard(
                  post: post,
                  onAddOffer: () => _showOfferForm(context, post),
                  onEditOffer: (postId, offerId, content, price) =>
                      _editOffer(postId, offerId, content, price),
                  onDeleteOffer: (postId, offerId) =>
                      _deleteOffer(postId, offerId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
