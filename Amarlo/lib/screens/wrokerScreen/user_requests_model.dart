class Post {
  final String id;
  final String title;
  final String description;
  final String? category;
  final List<Offer>? offers;
  final String? priceRange; // Add priceRange field
  final String creatorUsername;
  final String creatorEmail;

  Post({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    required this.offers,
    required this.priceRange, // Add priceRange field
    required this.creatorUsername,
    required this.creatorEmail,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      offers: json['offers'] != null
          ? (json['offers'] as List<dynamic>)
              .map((offer) => Offer.fromJson(offer))
              .toList()
          : null,
      priceRange: json['price_range'], // Add priceRange field
      creatorUsername: json['creator_username'] ?? 'Unknown User',
      creatorEmail: json['creator_email'] ?? '',
    );
  }
}

class Offer {
  final String? id;
  final String? content;
  final double price;
  final String workerEmail;

  Offer({
    required this.id,
    required this.content,
    required this.price,
    required this.workerEmail,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      price: json['price'],
      workerEmail: json['worker_email'],
    );
  }
}
