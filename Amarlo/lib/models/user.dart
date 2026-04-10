import 'dart:convert';
import 'dart:typed_data';

class User {
  final String id;
  final String username;
  final String email;
  final String userType;
  final String speciality; // Now editable
  final Uint8List? imageBase64;
  final String? introduction;
  final String? facebook;
  final String? instagram;
  final String? telegram;
  final String? number; // Now editable
  final String? city; // Now editable

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.userType,
    required this.speciality,
    this.imageBase64,
    this.introduction,
    this.facebook,
    this.instagram,
    this.telegram,
    this.number,
    this.city,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json["_id"] ?? '',
      username: json["username"] ?? '',
      email: json["email"] ?? '',
      userType: json["userType"] ?? '',
      speciality: json["speciality"] ?? '',
      imageBase64: json["imageBase64"] != null
          ? base64Decode(json["imageBase64"])
          : null,
      introduction: json["introduction"],
      facebook: json["facebook"],
      instagram: json["instagram"],
      telegram: json["telegram"],
      number: json["number"], // Parse 'number'
      city: json["city"], // Parse 'city'
    );
  }
}
