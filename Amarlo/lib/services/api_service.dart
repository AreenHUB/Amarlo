import 'package:http/http.dart' as http;
import 'dart:convert';
import '/models/user.dart';
import '/models/service.dart';
import '/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fourthapp/models/review.dart';

class ApiService {
  static Future<User?> getWorker(String workerId) async {
    final response = await http
        .get(Uri.parse('http://10.0.2.2:8000/api/v1/users/$workerId'));
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return User.fromJson(jsonData);
    } else {
      print("Error fetching worker: ${response.statusCode}");
      return null;
    }
  }

  static Future<User?> getWorkerByEmail(String email) async {
    final response = await http
        .get(Uri.parse('http://10.0.2.2:8000/api/v1/users?email=$email'));
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return User.fromJson(jsonData);
    } else {
      print("Error fetching worker: ${response.statusCode}");
      return null;
    }
  }

  static Future<List<Service>> getWorkerServices() async {
    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      print("Error fetching worker services: Access token is null");
      return [];
    }

    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/v1/services/worker/my-services'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List;
      return jsonData
          .map((serviceData) => Service.fromJson(serviceData))
          .toList();
    } else {
      print("Error fetching worker services: ${response.statusCode}");
      return [];
    }
  }

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<User?> updateUserIntroduction({
    required String workerId,
    required String introduction,
  }) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return null;

    final response = await http.put(
      Uri.parse('http://10.0.2.2:8000/api/v1/users/$workerId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'introduction': introduction}),
    );

    if (response.statusCode == 200) {
      final updatedUserData = jsonDecode(response.body);
      print('Updated User Data: $updatedUserData'); // Debug print statement
      return User.fromJson(updatedUserData);
    } else {
      print('Error updating introduction: ${response.statusCode}');
      print('Response body: ${response.body}');
      return null;
    }
  }

  static Future<User?> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updatedData,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('User ID is required to update profile.');
    }

    final accessToken = await _getAccessToken();
    if (accessToken == null) return null;

    final response = await http.put(
      Uri.parse('http://10.0.2.2:8000/api/v1/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(updatedData),
    );

    if (response.statusCode == 200) {
      final updatedUserData = jsonDecode(response.body);
      return User.fromJson(updatedUserData);
    } else {
      print('Error updating profile: ${response.statusCode}');
      print('Response body: ${response.body}');
      return null;
    }
  }

  static Future<List<Service>> getWorkerServicesByEmail(String email) async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/v1/services?worker_email=$email'),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      List<Service> services =
          body.map((dynamic item) => Service.fromJson(item)).toList();
      return services;
    } else {
      throw Exception('Failed to load services');
    }
  }

  static Future<List<Service>> getAllServices() async {
    final response =
        await http.get(Uri.parse('http://10.0.2.2:8000/api/v1/services'));
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List;
      return jsonData
          .map((serviceData) => Service.fromJson(serviceData))
          .toList();
    } else {
      print("Error fetching all services: ${response.statusCode}");
      return [];
    }
  }

  static Future<User?> getNormalUserProfileByEmail(String email) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      print("Error: Access Token is null.");
      return null;
    }

    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/v1/users?email=$email'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  static Future<User?> updateNormalUserProfileByEmail({
    required String email,
    required Map<String, dynamic> updatedData,
  }) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return null;

    print("Updating user with email: $email");

    final userResponse = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/v1/users?email=$email'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (userResponse.statusCode != 200) {
      print(
          "Error fetching user by email: ${userResponse.statusCode} - ${userResponse.body}");
      throw Exception('Failed to resolve user ID by email');
    }

    final userJson = jsonDecode(userResponse.body) as Map<String, dynamic>;
    final userId = userJson['_id'] ?? userJson['id'];

    if (userId == null) {
      throw Exception('User ID not found');
    }

    final response = await http.put(
      Uri.parse('http://10.0.2.2:8000/api/v1/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(updatedData),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      print("Error: ${response.statusCode} - ${response.body}");
      throw Exception('Failed to update user profile');
    }
  }

  static Future<List<Review>> getReviewsForWorker(String workerEmail) async {
    final response = await http
        .get(Uri.parse('http://10.0.2.2:8000/users/$workerEmail/reviews'));

    if (response.statusCode == 200) {
      final List<dynamic> reviewData = jsonDecode(response.body);
      return reviewData
          .map((reviewJson) => Review.fromJson(reviewJson))
          .toList();
    } else {
      throw Exception('Failed to load reviews');
    }
  }

  // Add the addReview method
  static Future<void> addReview(String workerEmail, Review review) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      throw Exception("Access token not found. Please log in again.");
    }

    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/users/$workerEmail/reviews'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'rating': review.rating,
        'comment': review.comment,
      }),
    );

    if (response.statusCode == 201) {
      print('Review added successfully!');
    } else {
      throw Exception('Failed to add review: ${response.statusCode}');
    }
  }

  static Future<void> updateReview(String reviewId, Review review) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      throw Exception("Access token not found. Please log in again.");
    }

    final response = await http.put(
      Uri.parse('http://10.0.2.2:8000/reviews/$reviewId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'rating': review.rating,
        'comment': review.comment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update review: ${response.body}');
    }
  }

  static Future<void> deleteReview(String reviewId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      throw Exception("Access token not found. Please log in again.");
    }

    final response = await http.delete(
      Uri.parse('http://10.0.2.2:8000/reviews/$reviewId'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete review: ${response.body}');
    }
  }
}
