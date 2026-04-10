import 'package:flutter/material.dart';
import 'package:fourthapp/models/user.dart';
import 'dart:convert';

class ProfileCard extends StatelessWidget {
  final User user;

  const ProfileCard({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40.0,
            backgroundImage: user.imageBase64 != null
                ? MemoryImage(user.imageBase64!)
                : AssetImage('images/OIG4.jpg'),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '${user.userType} - ${user.speciality}',
                  style: TextStyle(
                    fontSize: 16.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
