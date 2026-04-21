// lib/widgets/requests_container.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/wrokerScreen/worker_request/WorkerRequestsPage.dart';
import '../screens/userScreen/UserRequestsPage.dart';

class RequestsContainer extends StatefulWidget {
  const RequestsContainer({super.key});

  @override
  State<RequestsContainer> createState() => _RequestsContainerState();
}

class _RequestsContainerState extends State<RequestsContainer>
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
        title: const Text('Requests'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'As Worker'),
            Tab(text: 'As Client'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const WorkerRequestsPage(),
          // userId يأتي من AuthProvider في الـ page نفسها
          const _UserRequestsWrapper(),
        ],
      ),
    );
  }
}

class _UserRequestsWrapper extends StatelessWidget {
  const _UserRequestsWrapper();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return UserRequestsPage(userId: auth.user?.id ?? '');
  }
}
