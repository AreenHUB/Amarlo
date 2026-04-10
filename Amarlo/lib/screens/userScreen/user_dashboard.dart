import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'create_post_screen.dart';
import 'offers_screen.dart'; 
import 'models.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Post> _posts = [];
  List<Offer> _offers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPosts();
    _fetchOffers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      final response = await _getRequest('posts', accessToken);
      if (response != null) {
        final List<dynamic> postsData = jsonDecode(response.body);
        setState(() {
          _posts = postsData.map((data) => Post.fromJson(data)).toList();
        });
      } else {
        _showSnackBar('Failed to load posts');
      }
    }
  }

  Future<void> _fetchOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/users/me/offers'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final offersData = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _offers = offersData.map((offer) => Offer.fromJson(offer)).toList();
        });
      } else {
        print('Failed to fetch offers: ${response.statusCode}');
      }
    }
  }

  Future<http.Response?> _getRequest(
      String endpoint, String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/$endpoint'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      print('Error fetching $endpoint: $e');
    }
    return null;
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_type');
    await prefs.remove('email');
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<void> _updatePost(Post post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(post: post),
      ),
    );
    if (result == true) {
      _fetchPosts();
    }
  }

  Future<void> _deletePost(Post post) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      try {
        final response = await http.delete(
          Uri.parse('http://10.0.2.2:8000/posts/${post.id}'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (response.statusCode == 200) {
          _showSnackBar('Post deleted successfully');
          _fetchPosts();
        } else {
          _showSnackBar('Failed to delete post');
        }
      } catch (e) {
        _showSnackBar('Failed to delete post');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        backgroundColor: Colors.brown[400],
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Posts'),
            Tab(text: 'Offers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Posts View
          PostsView(
            posts: _posts,
            editPost: _updatePost,
            deletePost: _deletePost,
            showSnackBar: _showSnackBar,
          ),

          // Offers View
          OffersScreen(
            offers: _offers,
          ),
        ],
      ),
    );
  }
}

// Separate Widget for displaying Posts
class PostsView extends StatelessWidget {
  final List<Post> posts;
  final Function(Post) editPost;
  final Function(Post) deletePost;
  final Function(String) showSnackBar;

  const PostsView({
    Key? key,
    required this.posts,
    required this.editPost,
    required this.deletePost,
    required this.showSnackBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 12.0),
                textStyle: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreatePostScreen()),
                );
              },
              child: const Text('Create Post'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: ListTile(
                    title: Text(post.title),
                    subtitle: Text(post.priceRange),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.brown[400]),
                          onPressed: () => editPost(post),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deletePost(post),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
