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
  final String? linkedin;
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
    this.linkedin,
    this.number,
    this.city,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id:           j['id']       ?? j['_id'] ?? '',
        username:     j['username'] ?? '',
        email:        j['email']    ?? '',
        userType:     j['userType'] ?? '',
        speciality:   j['speciality'],
        imageUrl:     AppConstants.fixImageUrl(j['image_url']),
        introduction: j['introduction'],
        facebook:     j['facebook'],
        instagram:    j['instagram'],
        telegram:     j['telegram'],
        linkedin:     j['linkedin'],
        number:       j['number'],
        city:         j['city'],
      );

  User copyWith({
    String? username, String? imageUrl, String? introduction,
    String? facebook, String? instagram, String? telegram, String? linkedin,
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
        linkedin:     linkedin     ?? this.linkedin,
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
  final String deliveryType;

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
    this.deliveryType = 'online',
  });

  bool get isOnline => deliveryType == 'online';

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id:             j['id']             ?? j['_id'] ?? '',
        name:           j['name']           ?? '',
        location:       j['location']       ?? '',
        price:          (j['price'] as num).toDouble(),
        workerEmail:    j['worker_email']   ?? '',
        workerUsername: j['worker_username'] ?? '',
        imageUrl:       AppConstants.fixImageUrl(j['image_url']),
        description:    j['description']    ?? '',
        category:       j['category'],
        deliveryType:   j['delivery_type']  ?? 'online',
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
  final String? expiresAt;
  final bool safeAreaEnabled;
  final String status; // "open" | "closed"

  const Post({
    required this.id, required this.title, required this.description,
    required this.priceRange, this.category,
    required this.creatorUsername, required this.creatorEmail,
    this.offers = const [], this.createdAt, this.expiresAt,
    this.safeAreaEnabled = false, this.status = 'open',
  });

  /// أيام متبقية حتى انتهاء الصلاحية (null إذا لا يوجد TTL)
  int? get daysLeft {
    if (expiresAt == null) return null;
    try {
      final exp  = DateTime.parse(expiresAt!).toLocal();
      final diff = exp.difference(DateTime.now()).inDays;
      return diff.clamp(0, 7);
    } catch (_) { return null; }
  }

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
        createdAt:       j['created_at'],
        expiresAt:       j['expires_at'],
        safeAreaEnabled: j['safe_area_enabled'] ?? false,
        status:          j['status'] ?? 'open',
      );
}

// ══════════════════════════════════════════════
//  Safe Area Session (Contract)
// ══════════════════════════════════════════════
class SafeAreaSession {
  final String id;
  final String contractRef;       // SA-YYYY-XXXXX
  final String initiatorEmail;
  final String initiatorUsername;
  final String participantEmail;
  final String participantUsername;
  final String title;
  final String description;
  final String deliverables;
  final double price;
  final String deadline;
  final String deliveryType;
  final String status; // pending_acceptance | active | rejected | expired
  final String? postRef;
  final String? offerRef;
  final String createdAt;
  final String? acceptedAt;
  final String? invitationExpiresAt;
  final bool workerConfirmed;
  final bool userConfirmed;

  const SafeAreaSession({
    required this.id,
    required this.contractRef,
    required this.initiatorEmail,
    required this.initiatorUsername,
    required this.participantEmail,
    required this.participantUsername,
    required this.title,
    required this.description,
    required this.deliverables,
    required this.price,
    required this.deadline,
    required this.deliveryType,
    required this.status,
    this.postRef,
    this.offerRef,
    required this.createdAt,
    this.acceptedAt,
    this.invitationExpiresAt,
    this.workerConfirmed = false,
    this.userConfirmed   = false,
  });

  bool get isPending  => status == 'pending_acceptance';
  bool get isActive   => status == 'active';
  bool get isExpired  => status == 'expired';
  bool get isRejected => status == 'rejected';

  /// أيام/ساعات متبقية للدعوة
  String get invitationTimeLeft {
    if (invitationExpiresAt == null) return '';
    try {
      final exp  = DateTime.parse(invitationExpiresAt!).toLocal();
      final diff = exp.difference(DateTime.now());
      if (diff.isNegative) return 'Expired';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
      return '${diff.inMinutes}m left';
    } catch (_) { return ''; }
  }

  factory SafeAreaSession.fromJson(Map<String, dynamic> j) => SafeAreaSession(
        id:                   j['id']                    ?? '',
        contractRef:          j['contract_ref']          ?? '',
        initiatorEmail:       j['initiator_email']       ?? '',
        initiatorUsername:    j['initiator_username']    ?? '',
        participantEmail:     j['participant_email']      ?? '',
        participantUsername:  j['participant_username']  ?? '',
        title:                j['title']                 ?? '',
        description:          j['description']           ?? '',
        deliverables:         j['deliverables']          ?? '',
        price:               (j['price'] as num?)?.toDouble() ?? 0,
        deadline:             j['deadline']              ?? '',
        deliveryType:         j['delivery_type']         ?? 'online',
        status:               j['status']                ?? 'pending_acceptance',
        postRef:              j['post_ref'],
        offerRef:             j['offer_ref'],
        createdAt:            j['created_at']            ?? '',
        acceptedAt:           j['accepted_at'],
        invitationExpiresAt:  j['invitation_expires_at'],
        workerConfirmed:      j['worker_confirmed']      ?? false,
        userConfirmed:        j['user_confirmed']        ?? false,
      );
}

// ══════════════════════════════════════════════
//  Service Request
// ══════════════════════════════════════════════
class ServiceRequest {
  final String id;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final double agreedPrice;
  final String userEmail;
  final String userName;
  final String workerEmail;
  final String workerUsername;
  final String status;
  final String createdAt;
  final String? deadline;
  final String? proposedDeadline;
  final String? deadlineStatus; // null | "pending_user_approval" | "confirmed" | "rejected"
  final int?    proposedPrice;
  final String? priceStatus;   // null | "pending_user_approval" | "confirmed" | "rejected"
  final bool safeAreaActive;
  final bool safeAreaEnabled;
  final String deliveryType;

  const ServiceRequest({
    required this.id, required this.serviceId, required this.serviceName,
    this.servicePrice = 0, this.agreedPrice = 0,
    required this.userEmail, required this.userName,
    required this.workerEmail, this.workerUsername = '',
    required this.status, required this.createdAt,
    this.deadline, this.proposedDeadline, this.deadlineStatus,
    this.proposedPrice, this.priceStatus,
    this.safeAreaActive = false, this.safeAreaEnabled = false,
    this.deliveryType = 'online',
  });

  bool get isOnline   => deliveryType == 'online';
  bool get isInPerson => deliveryType == 'in_person';
  bool get hasPendingDeadline => deadlineStatus == 'pending_user_approval';
  bool get hasPendingPrice    => priceStatus == 'pending_user_approval';

  factory ServiceRequest.fromJson(Map<String, dynamic> j) => ServiceRequest(
        id:               j['id']             ?? j['_id'] ?? '',
        serviceId:        j['service_id']     ?? '',
        serviceName:      j['service_name']   ?? '',
        servicePrice:     (j['service_price'] as num?)?.toDouble() ?? 0,
        agreedPrice:      (j['agreed_price']  as num?)?.toDouble() ?? 0,
        userEmail:        j['user_email']       ?? '',
        userName:         j['user_name']        ?? '',
        workerEmail:      j['worker_email']     ?? '',
        workerUsername:   j['worker_username']  ?? '',
        status:           j['status']           ?? 'pending',
        createdAt:        j['created_at']     ?? '',
        deadline:         j['deadline'],
        proposedDeadline: j['proposed_deadline'],
        deadlineStatus:   j['deadline_status'],
        proposedPrice:    (j['proposed_price'] as num?)?.toInt(),
        priceStatus:      j['price_status'],
        safeAreaActive:   j['safe_area_active']  ?? false,
        safeAreaEnabled:  j['safe_area_enabled'] ?? false,
        deliveryType:     j['delivery_type']  ?? 'online',
      );

  ServiceRequest copyWith({String? status, String? deadline}) =>
      ServiceRequest(
        id: id, serviceId: serviceId, serviceName: serviceName,
        servicePrice: servicePrice, agreedPrice: agreedPrice,
        userEmail: userEmail, userName: userName,
        workerEmail: workerEmail, workerUsername: workerUsername,
        createdAt: createdAt, safeAreaActive: safeAreaActive,
        safeAreaEnabled: safeAreaEnabled, deliveryType: deliveryType,
        proposedDeadline: proposedDeadline, deadlineStatus: deadlineStatus,
        proposedPrice: proposedPrice, priceStatus: priceStatus,
        status:   status   ?? this.status,
        deadline: deadline ?? this.deadline,
      );
}

// ══════════════════════════════════════════════
//  Work Review — 3 محاور
// ══════════════════════════════════════════════
class Review {
  final String? id;
  final String reviewerUsername;
  final String reviewerEmail;
  final String revieweeEmail;
  final String requestId;
  final int qualityRating;
  final int punctualityRating;
  final int communicationRating;
  final double overallRating;
  final String? comment;
  final String? createdAt;

  const Review({
    this.id,
    required this.reviewerUsername,
    required this.reviewerEmail,
    required this.revieweeEmail,
    required this.requestId,
    required this.qualityRating,
    required this.punctualityRating,
    required this.communicationRating,
    required this.overallRating,
    this.comment,
    this.createdAt,
  });

  // للتوافق مع الكود القديم الذي يستخدم .rating
  int get rating => overallRating.round();

  factory Review.fromJson(Map<String, dynamic> j) {
    final q = (j['quality_rating'] as num?)?.toInt()     ?? (j['rating'] as num?)?.toInt() ?? 0;
    final p = (j['punctuality_rating'] as num?)?.toInt() ?? (j['rating'] as num?)?.toInt() ?? 0;
    final c = (j['communication_rating'] as num?)?.toInt() ?? (j['rating'] as num?)?.toInt() ?? 0;
    final overall = (j['overall_rating'] as num?)?.toDouble() ?? ((q + p + c) / 3);
    return Review(
      id:                   j['id'] ?? j['_id'],
      reviewerUsername:     j['reviewer_username'] ?? 'Unknown',
      reviewerEmail:        j['reviewer_email']    ?? '',
      revieweeEmail:        j['reviewee_email']    ?? j['worker_email'] ?? '',
      requestId:            j['request_id']        ?? '',
      qualityRating:        q,
      punctualityRating:    p,
      communicationRating:  c,
      overallRating:        overall,
      comment:              j['comment'],
      createdAt:            j['created_at'],
    );
  }
}

// ══════════════════════════════════════════════
//  Conduct Report
// ══════════════════════════════════════════════
const kConductReasons = [
  'Unprofessional language',
  'Harassment or threats',
  'Scam attempt',
  'Ghosted after agreement',
  'Misleading information',
  'Inappropriate content',
  'Other',
];

class ReviewEligibleRequest {
  final String requestId;
  final String serviceName;
  final String deliveryType;

  const ReviewEligibleRequest({
    required this.requestId,
    required this.serviceName,
    required this.deliveryType,
  });

  factory ReviewEligibleRequest.fromJson(Map<String, dynamic> j) =>
      ReviewEligibleRequest(
        requestId:    j['request_id']   ?? '',
        serviceName:  j['service_name'] ?? '',
        deliveryType: j['delivery_type'] ?? 'online',
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

  ChatMessage copyWith({bool? read}) => ChatMessage(
        id:             id,
        senderEmail:    senderEmail,
        senderUsername: senderUsername,
        recipientEmail: recipientEmail,
        message:        message,
        timestamp:      timestamp,
        read:           read ?? this.read,
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
