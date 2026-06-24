import 'package:flutter/material.dart';

// Home sau login: shortcut theo role + widget (doanh thu hôm nay, open orders, low-stock).
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(child: Text('TODO: widgets + shortcuts theo role')),
    );
  }
}
