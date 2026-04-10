class Post {
  final String id;
  final String title;
  final String description;
  final String priceRange;
  final String category;
  final String username;

  Post({
    required this.id,
    required this.title,
    required this.description,
    required this.priceRange,
    required this.category,
    required this.username,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'],
      title: json['title'],
      description: json['description'],
      priceRange: json['price_range'],
      category: json['category'],
      username: json['username'] ?? 'Unknown User',
    );
  }
}

class Offer {
  final String id;
  final String content;
  final double price;
  final String workerEmail;
  final String createdAt;
  final String? postTitle;
  String status;
  final String? postCreatorEmail; // Add creator's email
  final String? postCreatorUsername; // Add creator's username

  Offer({
    required this.id,
    required this.content,
    required this.price,
    required this.workerEmail,
    required this.createdAt,
    this.postTitle,
    required this.status,
    this.postCreatorEmail,
    this.postCreatorUsername,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['_id'],
      content: json['content'],
      price: json['price'].toDouble(),
      workerEmail: json['worker_email'],
      createdAt: json['created_at'],
      postTitle: json['post_title'],
      status: json['status'] ?? 'pending',
      postCreatorEmail: json['post_creator_email'], // Extract from JSON
      postCreatorUsername: json['post_creator_username'], // Extract from JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'content': content,
      'price': price,
      'worker_email': workerEmail,
      'created_at': createdAt,
      'post_title': postTitle,
      'status': status,
      'post_creator_email': postCreatorEmail,
      'post_creator_username': postCreatorUsername,
    };
  }
}
