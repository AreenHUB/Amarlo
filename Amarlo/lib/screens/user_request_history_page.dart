import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fourthapp/screens/request_provider.dart';
import 'package:fourthapp/models/request_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserRequestHistoryPage extends StatefulWidget {
  @override
  _UserRequestHistoryPageState createState() => _UserRequestHistoryPageState();
}

class _UserRequestHistoryPageState extends State<UserRequestHistoryPage> {
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _getUserEmail();
    _fetchCompletedRequests();
  }

  Future<void> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    setState(() {
      _userEmail = email;
    });
  }

  Future<void> _fetchCompletedRequests() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null || _userEmail == null) return;
    Provider.of<RequestProvider>(context, listen: false)
        .fetchCompletedUserRequests(_userEmail!, accessToken);
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Completed Requests'),
      ),
      body: requestProvider.completedUserRequests.isEmpty
          ? Center(child: Text('No completed requests yet.'))
          : ListView.builder(
              itemCount: requestProvider.completedUserRequests.length,
              itemBuilder: (context, index) {
                final request = requestProvider.completedUserRequests[index];
                return Card(
                  child: ListTile(
                    title: Text(request.serviceName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Worker: ${request.workerEmail}'),
                        Text('Status: ${request.status}'),
                        Text('Created: ${request.createdAt}'),
                        if (request.deadline != null)
                          Text('Deadline: ${request.deadline}')
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
