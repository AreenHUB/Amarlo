// lib/widgets/WorkerDashboardContainer.dart
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../screens/wrokerScreen/user_requests.dart';
import '../screens/wrokerScreen/worker_dashboard.dart';

class WorkerDashboardContainer extends StatefulWidget {
  final String workerId;
  /// Callback يُنادى عند أي تغيير في الخدمات → يُحدِّث Home فوراً
  final VoidCallback? onServicesChanged;

  const WorkerDashboardContainer({
    super.key,
    required this.workerId,
    this.onServicesChanged,
  });

  @override
  State<WorkerDashboardContainer> createState() =>
      _WorkerDashboardContainerState();
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
        title: const Text('My Dashboard'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.work_outline, size: 20), text: 'My Services'),
            Tab(icon: Icon(Icons.assignment_outlined, size: 20), text: 'Client Posts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ← تمرير callback للـ WorkerDashboard
          WorkerDashboard(onServicesChanged: widget.onServicesChanged),
          const UserRequestsScreen(),
        ],
      ),
    );
  }
}
