// lib/widgets/WorkerDashboardContainer.dart
import 'package:flutter/material.dart';
import '../screens/wrokerScreen/worker_dashboard.dart' as wd;
import '../screens/wrokerScreen/user_requests.dart';

class WorkerDashboardContainer extends StatefulWidget {
  final String workerId;
  const WorkerDashboardContainer({super.key, required this.workerId});

  @override
  State<WorkerDashboardContainer> createState() => _WorkerDashboardContainerState();
}

class _WorkerDashboardContainerState extends State<WorkerDashboardContainer>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: 'My Services'), Tab(text: 'Client Requests')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [wd.WorkerDashboard(), UserRequestsScreen()],
      ),
    );
  }
}
