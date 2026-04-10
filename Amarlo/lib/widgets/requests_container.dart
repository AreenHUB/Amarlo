import 'package:flutter/material.dart';
import 'package:fourthapp/screens/wrokerScreen/worker_request/WorkerRequestsPage.dart';
import 'package:fourthapp/screens/userScreen/UserRequestsPage.dart';

class RequestsContainer extends StatefulWidget {
  final String userId;

  RequestsContainer({required this.userId});

  @override
  _RequestsContainerState createState() => _RequestsContainerState();
}

class _RequestsContainerState extends State<RequestsContainer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Requests'),
        backgroundColor: Color.fromARGB(197, 104, 68, 56),
        foregroundColor: Color.fromARGB(255, 0, 0, 0),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Worker Requests'),
            Tab(text: 'User Requests'),
          ],
          indicatorColor: Color.fromARGB(183, 236, 236, 116),
          labelColor: Color.fromARGB(183, 236, 236, 116),
          dividerColor: Color.fromARGB(183, 255, 255, 255),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          WorkerRequestsPage(),
          UserRequestsPage(
            userId: widget.userId,
          ),
        ],
      ),
    );
  }
}
