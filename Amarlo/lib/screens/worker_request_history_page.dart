import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fourthapp/screens/request_provider.dart';
import 'package:fourthapp/models/request_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkerRequestHistoryPage extends StatefulWidget {
  @override
  _WorkerRequestHistoryPageState createState() =>
      _WorkerRequestHistoryPageState();
}

class _WorkerRequestHistoryPageState extends State<WorkerRequestHistoryPage> {
  String? _workerEmail;

  @override
  void initState() {
    super.initState();
    _getWorkerEmail();
    _fetchCompletedRequests();
  }

  Future<void> _getWorkerEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    setState(() {
      _workerEmail = email;
    });
  }

  Future<void> _fetchCompletedRequests() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null || _workerEmail == null) return;
    Provider.of<RequestProvider>(context, listen: false)
        .fetchCompletedWorkerRequests(_workerEmail!, accessToken);
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
      body: requestProvider.completedWorkerRequests.isEmpty
          ? Center(child: Text('No completed requests yet.'))
          : ListView.builder(
              itemCount: requestProvider.completedWorkerRequests.length,
              itemBuilder: (context, index) {
                final request = requestProvider.completedWorkerRequests[index];
                return Card(
                  child: ListTile(
                    title: Text(request.serviceName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User: ${request.userName}'),
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
