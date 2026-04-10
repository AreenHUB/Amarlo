import 'package:flutter/material.dart';
import 'user_requests_model.dart';

class PostSearchDelegate extends SearchDelegate {
  final List<Post> posts;
  final Function(String) onSearch;

  PostSearchDelegate({required this.posts, required this.onSearch});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          onSearch(query);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    return ListView(
      children: posts
          .where(
              (post) => post.title.toLowerCase().contains(query.toLowerCase()))
          .map((post) => ListTile(
                title: Text(post.title),
                onTap: () {
                  close(context, post);
                },
              ))
          .toList(),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = posts
        .where((post) => post.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView(
      children: suggestions
          .map((post) => ListTile(
                title: Text(post.title),
                onTap: () {
                  query = post.title;
                  showResults(context);
                },
              ))
          .toList(),
    );
  }
}
