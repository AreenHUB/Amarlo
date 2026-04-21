// lib/models/app_models.dart
import '../core/constants.dart';

// ══════════════════════════════════════════════
//  User
// ══════════════════════════════════════════════
class User {
  final String id;
  final String username;
  final String email;
  final String userType;
  final String? speciality;
  final String? imageUrl;
  final String? introduction;
  final String? facebook;
  final String? instagram;
  final String? telegram;
  final String? number;
  final String? city;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.userType,
    this.speciality,
    this.imageUrl,
    this.introduction,
    this.facebook,
    this.instagram,
    this.telegram,
    this.number,
    this.city,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id:           j['id']       ?? j['_id'] ?? '',
        username:     j['username'] ?? '',
        email:        j['email']    ?? '',
        userType:     j['userType'] ?? '',
        speciality:   j['speciality'],
        // ← تطبيق fixImageUrl لضمان الـ host الصحيح
        imageUrl:     AppConstants.fixImageUrl(j['image_url']),
        introduction: j['introduction'],
        facebook:     j['facebook'],
        instagram:    j['instagram'],
        telegram:     j['telegram'],
        number:       j['number'],
        city:         j['city'],
      );

  User copyWith({
    String? username, String? imageUrl, String? introduction,
    String? facebook, String? instagram, String? telegram,
    String? number, String? city, String? speciality,
  }) =>
      User(
        id: id, email: email, userType: userType,
        username:     username     ?? this.username,
        speciality:   speciality   ?? this.speciality,
        imageUrl:     imageUrl     ?? this.imageUrl,
        introduction: introduction ?? this.introduction,
        facebook:     facebook     ?? this.facebook,
        instagram:    instagram    ?? this.instagram,
        telegram:     telegram     ?? this.telegram,
        number:       number       ?? this.number,
        city:         city         ?? this.city,
      );
}

// ══════════════════════════════════════════════
//  Service
// ══════════════════════════════════════════════
class Service {
  final String id;
  final String name;
  final String location;
  final double price;
  final String workerEmail;
  final String workerUsername;
  final String? imageUrl;
  final String description;
  final String? category;

  const Service({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.workerEmail,
    required this.workerUsername,
    this.imageUrl,
    required this.description,
    this.category,
  });

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id:             j['id']             ?? j['_id'] ?? '',
        name:           j['name']           ?? '',
        location:       j['location']       ?? '',
        price:          (j['price'] as num).toDouble(),
        workerEmail:    j['worker_email']   ?? '',
        workerUsername: j['worker_username'] ?? '',
        // ← تطبيق fixImageUrl
        imageUrl:       AppConstants.fixImageUrl(j['image_url']),
        description:    j['description']    ?? '',
        category:       j['category'],
      );
}

// ══════════════════════════════════════════════
//  Post & Offer
// ══════════════════════════════════════════════
class PostOffer {
  final String id;
  final String content;
  final double price;
  final String workerEmail;
  final String workerUsername;
  final String status;
  final String createdAt;

  const PostOffer({
    required this.id, required this.content, required this.price,
    required this.workerEmail, required this.workerUsername,
    required this.status, required this.createdAt,
  });

  factory PostOffer.fromJson(Map<String, dynamic> j) => PostOffer(
        id:             j['_id']            ?? '',
        content:        j['content']        ?? '',
        price:          (j['price'] as num).toDouble(),
        workerEmail:    j['worker_email']   ?? '',
        workerUsername: j['worker_username'] ?? '',
        status:         j['status']         ?? 'pending',
        createdAt:      j['created_at']     ?? '',
      );
}

class Post {
  final String id;
  final String title;
  final String description;
  final String priceRange;
  final String? category;
  final String creatorUsername;
  final String creatorEmail;
  final List<PostOffer> offers;
  final String? createdAt;

  const Post({
    required this.id, required this.title, required this.description,
    required this.priceRange, this.category,
    required this.creatorUsername, required this.creatorEmail,
    this.offers = const [], this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id:              j['id'] ?? j['_id'] ?? '',
        title:           j['title']           ?? '',
        description:     j['description']     ?? '',
        priceRange:      j['price_range']     ?? '',
        category:        j['category'],
        creatorUsername: j['creator_username'] ?? '',
        creatorEmail:    j['creator_email']   ?? '',
        offers: (j['offers'] as List? ?? [])
            .map((o) => PostOffer.fromJson(o as Map<String, dynamic>))
            .toList(),
        createdAt: j['created_at'],
      );
}

// ══════════════════════════════════════════════
//  Service Request
// ══════════════════════════════════════════════
class ServiceRequest {
  final String id;
  final String serviceId;
  final String serviceName;
  final String userEmail;
  final String userName;
  final String workerEmail;
  final String status;
  final String createdAt;
  final String? deadline;
  final bool safeAreaActive;

  const ServiceRequest({
    required this.id, required this.serviceId, required this.serviceName,
    required this.userEmail, required this.userName, required this.workerEmail,
    required this.status, required this.createdAt,
    this.deadline, this.safeAreaActive = false,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> j) => ServiceRequest(
        id:             j['id']           ?? j['_id'] ?? '',
        serviceId:      j['service_id']   ?? '',
        serviceName:    j['service_name'] ?? '',
        userEmail:      j['user_email']   ?? '',
        userName:       j['user_name']    ?? '',
        workerEmail:    j['worker_email'] ?? '',
        status:         j['status']       ?? 'pending',
        createdAt:      j['created_at']   ?? '',
        deadline:       j['deadline'],
        safeAreaActive: j['safe_area_active'] ?? false,
      );

  ServiceRequest copyWith({String? status, String? deadline}) =>
      ServiceRequest(
        id: id, serviceId: serviceId, serviceName: serviceName,
        userEmail: userEmail, userName: userName, workerEmail: workerEmail,
        createdAt: createdAt, safeAreaActive: safeAreaActive,
        status:   status   ?? this.status,
        deadline: deadline ?? this.deadline,
      );
}

// ══════════════════════════════════════════════
//  Review
// ══════════════════════════════════════════════
class Review {
  final String? id;
  final String reviewerUsername;
  final String reviewerEmail;
  final int rating;
  final String? comment;

  const Review({
    this.id, required this.reviewerUsername,
    required this.reviewerEmail, required this.rating, this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id:               j['id'] ?? j['_id'],
        reviewerUsername: j['reviewer_username'] ?? 'Unknown',
        reviewerEmail:    j['reviewer_email']    ?? '',
        rating:           j['rating'] as int,
        comment:          j['comment'],
      );
}

// ══════════════════════════════════════════════
//  Conversation / Message
// ══════════════════════════════════════════════
class Conversation {
  final String otherEmail;
  final String otherUsername;
  final String? otherUserImageUrl;
  final String lastMessage;
  final String? timestamp;
  final int unreadCount;

  const Conversation({
    required this.otherEmail, required this.otherUsername,
    this.otherUserImageUrl, required this.lastMessage,
    this.timestamp, this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        otherEmail:        j['other_email']       ?? '',
        otherUsername:     j['other_username']    ?? '',
        // ← تطبيق fixImageUrl
        otherUserImageUrl: AppConstants.fixImageUrl(j['other_user_image_url']),
        lastMessage:       j['last_message']      ?? '',
        timestamp:         j['timestamp'],
        unreadCount:       j['unread_count']      ?? 0,
      );
}

class ChatMessage {
  final String id;
  final String senderEmail;
  final String senderUsername;
  final String recipientEmail;
  final String message;
  final String timestamp;
  final bool read;

  const ChatMessage({
    required this.id, required this.senderEmail, required this.senderUsername,
    required this.recipientEmail, required this.message,
    required this.timestamp, this.read = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id:               j['_id']              ?? '',
        senderEmail:      j['sender_email']     ?? '',
        senderUsername:   j['sender_username']  ?? '',
        recipientEmail:   j['recipient_email']  ?? '',
        message:          j['message']          ?? '',
        timestamp:        j['timestamp']        ?? '',
        read:             j['read']             ?? false,
      );
}

// ══════════════════════════════════════════════
//  Paged response
// ══════════════════════════════════════════════
class Paged<T> {
  final List<T> items;
  final int total;
  final int page;
  final int size;
  final int pages;

  const Paged({
    required this.items, required this.total,
    required this.page, required this.size, required this.pages,
  });

  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      Paged(
        items: (j['items'] as List)
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList(),
        total: j['total'] ?? 0,
        page:  j['page']  ?? 1,
        size:  j['size']  ?? 20,
        pages: j['pages'] ?? 1,
      );
}
