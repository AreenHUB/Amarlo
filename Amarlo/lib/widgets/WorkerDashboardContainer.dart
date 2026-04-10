import 'package:flutter/material.dart';
import 'package:fourthapp/screens/wrokerScreen/worker_dashboard.dart' as worker;
import 'package:fourthapp/screens/wrokerScreen/user_requests.dart';

class WorkerDashboardContainer extends StatefulWidget {
  final String workerId;

  WorkerDashboardContainer({required this.workerId});

  @override
  _WorkerDashboardContainerState createState() =>
      _WorkerDashboardContainerState();
}

class _WorkerDashboardContainerState extends State<WorkerDashboardContainer>
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
        title: Text('Dashboard'),
        backgroundColor: Color.fromARGB(197, 104, 68, 56),
        foregroundColor: Color.fromARGB(255, 0, 0, 0),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Requests'),
          ],
          indicatorColor: Color.fromARGB(183, 236, 236, 116),
          labelColor: Color.fromARGB(183, 236, 236, 116),
          dividerColor: Color.fromARGB(183, 255, 255, 255),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          worker.WorkerDashboard(),
          UserRequestsScreen(),
        ],
      ),
    );
  }
}
