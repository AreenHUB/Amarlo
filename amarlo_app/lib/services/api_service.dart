// lib/services/api_service.dart
//
// كل طلبات الـ API في مكان واحد.
// يستخدم HttpClient الموحّد مع معالجة الأخطاء.

import 'dart:io';

import '../core/constants.dart';
import '../models/app_models.dart';
import 'http_client.dart';

class ApiService {
  ApiService._();

  // ══════════════════════════════════════════════
  //  Auth
  // ══════════════════════════════════════════════

  static Future<Map<String, dynamic>> login(String email, String password) async {
    return await api.post(
      AppConstants.loginUrl,
      {'email': email, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    await api.post(AppConstants.logoutUrl, {});
  }

  static Future<User> getMe() async {
    final data = await api.get(AppConstants.meUrl) as Map<String, dynamic>;
    return User.fromJson(data);
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
    final fields = {
      'username': username,
      'email': email,
      'password': password,
      'number': number,
      'gender': gender,
      'city': city,
      'userType': userType,
      if (speciality != null) 'speciality': speciality,
    };

    await api.multipartPost(
      AppConstants.registerUrl,
      fieldName: 'image',
      file: image,
      fields: fields,
      auth: false,
    );
  }

  // ══════════════════════════════════════════════
  //  Users
  // ══════════════════════════════════════════════

  static Future<User> getUser(String userId) async {
    final data = await api.get(AppConstants.userUrl(userId));
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserByEmail(String email) async {
    final data = await api.get(AppConstants.userByEmailUrl(email));
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> updateUser({
    required String userId,
    String? username,
    String? number,
    String? city,
    String? speciality,
    String? introduction,
    String? facebook,
    String? instagram,
    String? telegram,
    File? image,
  }) async {
    final fields = <String, String>{};
    if (username != null) fields['username'] = username;
    if (number != null) fields['number'] = number;
    if (city != null) fields['city'] = city;
    if (speciality != null) fields['speciality'] = speciality;
    if (introduction != null) fields['introduction'] = introduction;
    if (facebook != null) fields['facebook'] = facebook;
    if (instagram != null) fields['instagram'] = instagram;
    if (telegram != null) fields['telegram'] = telegram;

    final data = await api.multipartPut(
      AppConstants.userUrl(userId),
      file: image,
      fieldName: image != null ? 'image' : null,
      fields: fields,
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════
  //  Services
  // ══════════════════════════════════════════════

  static Future<Paged<Service>> getServices({
    String? workerEmail,
    String? category,
    String? city,
    double? minPrice,
    double? maxPrice,
    String? search,
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      if (workerEmail != null) 'worker_email': workerEmail,
      if (category != null) 'category': category,
      if (city != null) 'city': city,
      if (minPrice != null) 'min_price': '$minPrice',
      if (maxPrice != null) 'max_price': '$maxPrice',
      if (search != null) 'search': search,
    };
    final url = Uri.parse(AppConstants.servicesUrl)
        .replace(queryParameters: params)
        .toString();
    final data = await api.get(url, auth: false);
    return Paged.fromJson(data as Map<String, dynamic>, Service.fromJson);
  }

  static Future<List<Service>> getWorkerServices() async {
    final data = await api.get(AppConstants.workerServicesUrl) as List;
    return data.map((e) => Service.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<String>> getCategories() async {
    final data = await api.get(AppConstants.categoriesUrl, auth: false) as List;
    return data.cast<String>();
  }

  static Future<Service> addService({
    required String name,
    required String location,
    required double price,
    required String description,
    String? category,
    File? image,
  }) async {
    final fields = {
      'name': name,
      'location': location,
      'price': '$price',
      'description': description,
      if (category != null) 'category': category,
    };
    final data = await api.multipartPost(
      AppConstants.servicesUrl,
      fieldName: 'image',
      file: image,
      fields: fields,
    );
    return Service.fromJson(data as Map<String, dynamic>);
  }

  static Future<Service> updateService(
    String serviceId, {
    String? name,
    String? location,
    double? price,
    String? description,
    String? category,
    File? image,
  }) async {
    final fields = <String, String>{};
    if (name != null) fields['name'] = name;
    if (location != null) fields['location'] = location;
    if (price != null) fields['price'] = '$price';
    if (description != null) fields['description'] = description;
    if (category != null) fields['category'] = category;

    final data = await api.multipartPut(
      AppConstants.serviceUrl(serviceId),
      file: image,
      fieldName: image != null ? 'image' : null,
      fields: fields,
    );
    return Service.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteService(String serviceId) async {
    await api.delete(AppConstants.serviceUrl(serviceId));
  }

  // ══════════════════════════════════════════════
  //  Posts & Offers
  // ══════════════════════════════════════════════

  static Future<Paged<Post>> getMyPosts({int page = 1, int size = 20}) async {
    final url = Uri.parse(AppConstants.postsUrl)
        .replace(queryParameters: {'page': '$page', 'size': '$size'})
        .toString();
    final data = await api.get(url);
    return Paged.fromJson(data as Map<String, dynamic>, Post.fromJson);
  }

  static Future<Paged<Post>> getPublicPosts({
    String? category,
    String? search,
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      if (category != null) 'category': category,
      if (search != null) 'search': search,
    };
    final url = Uri.parse(AppConstants.publicPostsUrl)
        .replace(queryParameters: params)
        .toString();
    final data = await api.get(url);
    return Paged.fromJson(data as Map<String, dynamic>, Post.fromJson);
  }

  static Future<Post> createPost({
    required String title,
    required String description,
    required String priceRange,
    String? category,
  }) async {
    final data = await api.post(AppConstants.postsUrl, {
      'title': title,
      'description': description,
      'price_range': priceRange,
      if (category != null) 'category': category,
    });
    return Post.fromJson(data as Map<String, dynamic>);
  }

  static Future<Post> updatePost(String postId, {
    String? title,
    String? description,
    String? priceRange,
    String? category,
  }) async {
    final data = await api.put(AppConstants.postUrl(postId), {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priceRange != null) 'price_range': priceRange,
      if (category != null) 'category': category,
    });
    return Post.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deletePost(String postId) async {
    await api.delete(AppConstants.postUrl(postId));
  }

  static Future<void> addOffer(String postId, String content, double price) async {
    await api.post(
      AppConstants.postOffersUrl(postId),
      {'content': content, 'price': price},
    );
  }

  static Future<void> updateOffer(String postId, String offerId,
      String content, double price) async {
    await api.put(
      AppConstants.postOfferUrl(postId, offerId),
      {'content': content, 'price': price},
    );
  }

  static Future<void> deleteOffer(String postId, String offerId) async {
    await api.delete(AppConstants.postOfferUrl(postId, offerId));
  }

  static Future<void> respondToOffer(
      String postId, String offerId, String action) async {
    await api.put(AppConstants.postOfferActionUrl(postId, offerId, action), {});
  }

  static Future<List<Map<String, dynamic>>> getMyReceivedOffers() async {
    final data = await api.get(AppConstants.myOffersUrl) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════
  //  Service Requests
  // ══════════════════════════════════════════════

  static Future<Paged<ServiceRequest>> getUserRequests(String userId,
      {int page = 1, int size = 20}) async {
    final url = Uri.parse(AppConstants.requestsUserUrl(userId))
        .replace(queryParameters: {'page': '$page', 'size': '$size'})
        .toString();
    final data = await api.get(url);
    return Paged.fromJson(
        data as Map<String, dynamic>, ServiceRequest.fromJson);
  }

  static Future<Paged<ServiceRequest>> getWorkerRequests(String email,
      {int page = 1, int size = 20}) async {
    final url = Uri.parse(AppConstants.requestsWorkerUrl(email))
        .replace(queryParameters: {'page': '$page', 'size': '$size'})
        .toString();
    final data = await api.get(url);
    return Paged.fromJson(
        data as Map<String, dynamic>, ServiceRequest.fromJson);
  }

  static Future<List<ServiceRequest>> getUserCompletedRequests(
      String email) async {
    final data =
        await api.get(AppConstants.requestUserCompletedUrl(email)) as List;
    return data
        .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ServiceRequest>> getWorkerCompletedRequests(
      String email) async {
    final data =
        await api.get(AppConstants.requestWorkerCompletedUrl(email)) as List;
    return data
        .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> acceptRequest(String requestId, DateTime deadline) async {
    await api.put(
      '${AppConstants.requestAcceptUrl(requestId)}?deadline=${deadline.toIso8601String()}',
      {},
    );
  }

  static Future<void> markRequestReady(String requestId) async {
    await api.put(AppConstants.requestReadyUrl(requestId), {});
  }

  static Future<void> deleteRequest(String requestId) async {
    await api.delete(AppConstants.requestUrl(requestId));
  }

  // ══════════════════════════════════════════════
  //  Chat
  // ══════════════════════════════════════════════

  static Future<List<ChatMessage>> getMessages(
      String senderEmail, String recipientEmail) async {
    final data = await api.get(
      AppConstants.messagesUrl(senderEmail, recipientEmail),
    ) as List;
    return data
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Conversation>> getConversations(String email) async {
    final data =
        await api.get(AppConstants.conversationsUrl(email)) as List;
    return data
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markMessageRead(String messageId) async {
    await api.put(AppConstants.markReadUrl(messageId), {});
  }

  static Future<bool> toggleBlock(String targetEmail) async {
    final data = await api.post(AppConstants.toggleBlockUrl(targetEmail), {});
    return (data as Map<String, dynamic>)['blocked'] as bool;
  }

  static Future<bool> getBlockStatus(String targetEmail) async {
    final data = await api.get(AppConstants.blockStatusUrl(targetEmail));
    return (data as Map<String, dynamic>)['blocked'] as bool;
  }

  // ══════════════════════════════════════════════
  //  Safe Area
  // ══════════════════════════════════════════════

  static Future<void> uploadWork(String requestId, File file) async {
    await api.multipartPost(
      AppConstants.safeAreaUploadUrl(requestId),
      fieldName: 'file',
      file: file,
    );
  }

  static Future<void> sendPayment(String requestId, int amount) async {
    await api.post(
      AppConstants.safeAreaPaymentUrl(requestId),
      {'amount': amount},
    );
  }

  static Future<Map<String, dynamic>> getPaymentStatus(
      String requestId) async {
    return await api.get(AppConstants.safeAreaPaymentStatusUrl(requestId))
        as Map<String, dynamic>;
  }

  static Future<String> confirmDeal(String requestId) async {
    final data = await api.post(
      AppConstants.safeAreaConfirmUrl(requestId),
      {},
    );
    return (data as Map<String, dynamic>)['message'] as String;
  }

  static Future<double> getWorkerBalance(String email) async {
    final data = await api.get(AppConstants.workerBalanceUrl(email));
    return ((data as Map<String, dynamic>)['balance'] as num).toDouble();
  }

  // ══════════════════════════════════════════════
  //  Reviews
  // ══════════════════════════════════════════════

  static Future<List<Review>> getReviews(String workerEmail) async {
    final data = await api.get(AppConstants.reviewsUrl(workerEmail)) as List;
    return data
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addReview(
      String workerEmail, int rating, String? comment) async {
    await api.post(AppConstants.reviewsUrl(workerEmail), {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  static Future<void> updateReview(
      String reviewId, int rating, String? comment) async {
    await api.put(AppConstants.reviewUrl(reviewId), {
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  static Future<void> deleteReview(String reviewId) async {
    await api.delete(AppConstants.reviewUrl(reviewId));
  }

  // ══════════════════════════════════════════════
  //  Reports
  // ══════════════════════════════════════════════

  static Future<void> submitReport(String description) async {
    await api.post(AppConstants.reportsUrl(), {'description': description});
  }

  static Future<List<Map<String, dynamic>>> getMyReports() async {
    final data = await api.get(AppConstants.myReportsUrl()) as List;
    return data.cast<Map<String, dynamic>>();
  }
}
