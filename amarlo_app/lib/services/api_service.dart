// lib/services/api_service.dart
import 'dart:io';
import '../core/constants.dart';
import '../models/app_models.dart';
import 'http_client.dart';

class ApiService {
  // ══════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await api.post(
      AppConstants.loginUrl,
      {'email': email, 'password': password},
      auth: false,
    );
    return data as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    try { await api.post(AppConstants.logoutUrl, {}); } catch (_) {}
  }

  static Future<void> register({
    required String username,
    required String email,
    required String password,
    required String number,
    required String gender,
    required String city,
    required String userType,
    String? speciality,
    File? image,
  }) async {
    await api.multipartPost(
      AppConstants.registerUrl,
      fieldName: 'image',
      file: image,
      fields: {
        'username': username,
        'email':    email,
        'password': password,
        'number':   number,
        'gender':   gender,
        'city':     city,
        'userType': userType,
        if (speciality != null) 'speciality': speciality,
      },
      auth: false,
    );
  }

  static Future<User> getMe() async {
    final data = await api.get(AppConstants.meUrl);
    return User.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════
  //  SERVICES
  // ══════════════════════════════════════════════

  static Future<Paged<Service>> getServices({
    int page = 1, int size = 20,
    String? workerEmail, String? category,
    String? search, String? city,
    double? minPrice, double? maxPrice,
  }) async {
    final q = StringBuffer('${AppConstants.servicesUrl}?page=$page&size=$size');
    if (workerEmail != null) q.write('&worker_email=${Uri.encodeComponent(workerEmail)}');
    if (category != null)    q.write('&category=${Uri.encodeComponent(category)}');
    if (search != null)      q.write('&search=${Uri.encodeComponent(search)}');
    if (city != null)        q.write('&city=${Uri.encodeComponent(city)}');
    if (minPrice != null)    q.write('&min_price=$minPrice');
    if (maxPrice != null)    q.write('&max_price=$maxPrice');
    final data = await api.get(q.toString(), auth: false);
    return Paged.fromJson(data as Map<String, dynamic>, Service.fromJson);
  }

  static Future<List<Service>> getMyServices() async {
    final data = await api.get(AppConstants.workerServicesUrl);
    return (data as List).map((e) => Service.fromJson(e)).toList();
  }

  static Future<List<Service>> getWorkerServices() => getMyServices();

  static Future<List<String>> getCategories() async {
    final data = await api.get(AppConstants.categoriesUrl, auth: false);
    return (data as List).map((e) => e.toString()).toList();
  }

  static Future<Service> addService({
    required String name,
    required String location,
    required double price,
    required String description,
    String? category,
    required File image,
  }) async {
    final data = await api.multipartPost(
      AppConstants.servicesUrl,
      fieldName: 'image',
      file: image,
      fields: {
        'name': name, 'location': location,
        'price': '$price', 'description': description,
        if (category != null) 'category': category,
      },
    );
    return Service.fromJson(data as Map<String, dynamic>);
  }

  static Future<Service> updateService(
    String id, {
    String? name, String? location, double? price,
    String? description, String? category, File? image,
  }) async {
    final data = await api.multipartPut(
      AppConstants.serviceUrl(id),
      fieldName: 'image',
      file: image,
      fields: {
        if (name != null) 'name': name,
        if (location != null) 'location': location,
        if (price != null) 'price': '$price',
        if (description != null) 'description': description,
        if (category != null) 'category': category,
      },
    );
    return Service.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteService(String id) async {
    await api.delete(AppConstants.serviceUrl(id));
  }

  static Future<Map<String, dynamic>> requestService(String serviceId) async {
    final data = await api.post(AppConstants.serviceRequestUrl(serviceId), {});
    return (data as Map<String, dynamic>?) ?? {};
  }

  // ══════════════════════════════════════════════
  //  POSTS & OFFERS
  // ══════════════════════════════════════════════

  static Future<Paged<Post>> getMyPosts({int page = 1, int size = 100}) async {
    final data = await api.get('${AppConstants.postsUrl}?page=$page&size=$size');
    return Paged.fromJson(data as Map<String, dynamic>, Post.fromJson);
  }

  static Future<Paged<Post>> getPublicPosts({
    int page = 1, int size = 100,
    String? search, String? category,
  }) async {
    final q = StringBuffer('${AppConstants.publicPostsUrl}?page=$page&size=$size');
    if (search != null)   q.write('&search=${Uri.encodeComponent(search)}');
    if (category != null) q.write('&category=${Uri.encodeComponent(category)}');
    final data = await api.get(q.toString());
    return Paged.fromJson(data as Map<String, dynamic>, Post.fromJson);
  }

  static Future<List<Post>> getMyReceivedOffers() async {
    final data = await api.get(AppConstants.myOffersUrl);
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  static Future<Post> createPost({
    required String title, required String description,
    required String priceRange, String? category,
  }) async {
    final data = await api.post(AppConstants.postsUrl, {
      'title': title, 'description': description,
      'price_range': priceRange,
      if (category != null) 'category': category,
    });
    return Post.fromJson(data as Map<String, dynamic>);
  }

  static Future<Post> updatePost(String id, {
    String? title, String? description,
    String? priceRange, String? category,
  }) async {
    final data = await api.put(AppConstants.postUrl(id), {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priceRange != null) 'price_range': priceRange,
      if (category != null) 'category': category,
    });
    return Post.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deletePost(String id) async {
    await api.delete(AppConstants.postUrl(id));
  }

  static Future<void> addOffer(String postId, String content, double price) async {
    await api.post(AppConstants.postOffersUrl(postId),
        {'content': content, 'price': price});
  }

  static Future<void> respondToOffer(String postId, String offerId, bool accept) async {
    final action = accept ? 'accept' : 'reject';
    await api.put(AppConstants.postOfferActionUrl(postId, offerId, action), {});
  }

  // ══════════════════════════════════════════════
  //  SERVICE REQUESTS
  // ══════════════════════════════════════════════

  static Future<Paged<ServiceRequest>> getUserRequests(
    String userId, {int page = 1, int size = 100}) async {
    final data = await api.get(
        '${AppConstants.requestsUserUrl(userId)}?page=$page&size=$size');
    return Paged.fromJson(data as Map<String, dynamic>, ServiceRequest.fromJson);
  }

  static Future<List<ServiceRequest>> getUserCompletedRequests(String email) async {
    final data = await api.get(AppConstants.requestUserCompletedUrl(email));
    return (data as List).map((e) => ServiceRequest.fromJson(e)).toList();
  }

  static Future<Paged<ServiceRequest>> getWorkerRequests(
    String email, {int page = 1, int size = 100}) async {
    final data = await api.get(
        '${AppConstants.requestsWorkerUrl(email)}?page=$page&size=$size');
    return Paged.fromJson(data as Map<String, dynamic>, ServiceRequest.fromJson);
  }

  static Future<List<ServiceRequest>> getWorkerCompletedRequests(String email) async {
    final data = await api.get(AppConstants.requestWorkerCompletedUrl(email));
    return (data as List).map((e) => ServiceRequest.fromJson(e)).toList();
  }

  static Future<void> acceptRequest(String id, String deadline) async {
    await api.put(
      '${AppConstants.requestAcceptUrl(id)}?deadline=${Uri.encodeComponent(deadline)}',
      {},
    );
  }

  static Future<void> markReady(String id) async {
    await api.put(AppConstants.requestReadyUrl(id), {});
  }

  static Future<void> deleteRequest(String id) async {
    await api.delete(AppConstants.requestUrl(id));
  }

  // ══════════════════════════════════════════════
  //  USERS & REVIEWS
  // ══════════════════════════════════════════════

  static Future<User> getUser(String id) async {
    final data = await api.get(AppConstants.userUrl(id));
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User?> getUserByEmail(String email) async {
    final data = await api.get(AppConstants.userByEmailUrl(email));
    final list = data as List;
    if (list.isEmpty) return null;
    return User.fromJson(list.first as Map<String, dynamic>);
  }

  static Future<User> updateUser(
    String userId, {
    String? username, String? number, String? city,
    String? speciality, String? introduction,
    String? facebook, String? instagram, String? telegram,
    File? image,
  }) async {
    final data = await api.multipartPut(
      AppConstants.userUrl(userId),
      fieldName: 'image',
      file: image,
      fields: {
        if (username != null) 'username': username,
        if (number != null) 'number': number,
        if (city != null) 'city': city,
        if (speciality != null) 'speciality': speciality,
        if (introduction != null) 'introduction': introduction,
        if (facebook != null) 'facebook': facebook,
        if (instagram != null) 'instagram': instagram,
        if (telegram != null) 'telegram': telegram,
      },
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> updateProfile(String userId, {
    String? username, String? number, String? city,
    String? speciality, String? introduction,
    String? facebook, String? instagram, String? telegram,
    File? image,
  }) => updateUser(userId,
      username: username, number: number, city: city,
      speciality: speciality, introduction: introduction,
      facebook: facebook, instagram: instagram, telegram: telegram,
      image: image);

  static Future<List<Review>> getReviews(String workerEmail) async {
    final data = await api.get(AppConstants.reviewsUrl(workerEmail));
    return (data as List).map((e) => Review.fromJson(e)).toList();
  }

  static Future<void> addReview(String workerEmail, int rating, String? comment) async {
    await api.post(AppConstants.reviewsUrl(workerEmail), {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  static Future<void> updateReview(String reviewId, int rating, String? comment) async {
    await api.put(AppConstants.reviewUrl(reviewId), {
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  static Future<void> deleteReview(String reviewId) async {
    await api.delete(AppConstants.reviewUrl(reviewId));
  }

  // ══════════════════════════════════════════════
  //  CHAT
  // ══════════════════════════════════════════════

  static Future<List<dynamic>> getMessages(String s, String r) async {
    final data = await api.get(AppConstants.messagesUrl(s, r));
    return data as List;
  }

  static Future<List<Conversation>> getConversations(String email) async {
    final data = await api.get(AppConstants.conversationsUrl(email));
    return (data as List).map((e) => Conversation.fromJson(e)).toList();
  }

  static Future<void> markRead(String messageId) async {
    await api.put(AppConstants.markReadUrl(messageId), {});
  }

  static Future<Map<String, dynamic>> toggleBlock(String email) async {
    final data = await api.post(AppConstants.toggleBlockUrl(email), {});
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<bool> getBlockStatus(String email) async {
    final data = await api.get(AppConstants.blockStatusUrl(email));
    return (data as Map<String, dynamic>)['blocked'] == true;
  }

  static Future<bool> getUserPresence(String email) async {
    try {
      final data = await api.get(AppConstants.presenceUrl(email));
      return (data as Map<String, dynamic>)['online'] == true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════
  //  SAFE AREA
  // ══════════════════════════════════════════════

  static Future<void> uploadWork(String requestId, File file) async {
    await api.multipartPost(
      AppConstants.safeAreaUploadUrl(requestId),
      fieldName: 'file',
      file: file,
    );
  }

  static Future<Map<String, dynamic>> getPaymentStatus(String id) async {
    final data = await api.get(AppConstants.safeAreaPaymentStatusUrl(id));
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<void> sendPayment(String id, int amount) async {
    await api.post(AppConstants.safeAreaPaymentUrl(id), {'amount': amount});
  }

  static Future<Map<String, dynamic>> confirmDeal(String id) async {
    final data = await api.post(AppConstants.safeAreaConfirmUrl(id), {});
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> getWorkerBalance(String email) async {
    final data = await api.get(AppConstants.workerBalanceUrl(email));
    return (data as Map<String, dynamic>?) ?? {};
  }

  // ══════════════════════════════════════════════
  //  REPORTS
  // ══════════════════════════════════════════════

  static Future<void> submitReport(
    String reportedEmail, String reason, {String? details}) async {
    await api.post(AppConstants.reportsUrl, {
      'reported_email': reportedEmail,
      'reason': reason,
      if (details != null) 'details': details,
    });
  }

  static Future<List<dynamic>> getMyReports() async {
    final data = await api.get(AppConstants.myReportsUrl);
    return data as List;
  }
}
