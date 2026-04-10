
class Review {
  final String? id;
  final String reviewerUsername;
  final int rating;
  final String? comment;
  final String reviewerEmail; // Add this line

  Review({
    this.id,
    required this.reviewerUsername,
    required this.rating,
    this.comment,
    required this.reviewerEmail, // Add this line
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['_id'] as String?,
      reviewerUsername: json['reviewer_username'] ?? "Unknown User",
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      reviewerEmail: json['reviewer_email'] as String, // Add this line
    );
  }
}
