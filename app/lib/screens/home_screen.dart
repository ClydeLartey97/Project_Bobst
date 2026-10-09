import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../services/api_client.dart';
import 'developer_screen.dart';
import 'floors_screen.dart';
import 'overview_screen.dart';

/// Owns the data and the tab bar; both tabs render the same status.
///
/// The tab bar is Apple's native UITabBar (Liquid Glass) on iOS 26+, and a
/// platform-appropriate bar everywhere else.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BobstStatus? _status;
  Object? _error;
  Timer? _timer;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await widget.api.fetchStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final native = PlatformInfo.isIOS26OrHigher();
    return AdaptiveScaffold(
      extendBody: true,
      minimizeBehavior: TabBarMinimizeBehavior.never,
      body: Material(type: MaterialType.transparency, child: _buildBody()),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        // Apple's standard tint rather than the app's violet theme colour.
        selectedItemColor: CupertinoColors.systemBlue,
        items: [
          AdaptiveNavigationDestination(
            icon: native ? 'building.columns' : Icons.account_balance_outlined,
            selectedIcon: native
                ? 'building.columns.fill'
                : Icons.account_balance,
            label: 'Overview',
          ),
          AdaptiveNavigationDestination(
            icon: native ? 'square.stack.3d.up' : Icons.layers_outlined,
            selectedIcon: native ? 'square.stack.3d.up.fill' : Icons.layers,
            label: 'Floors',
          ),
          AdaptiveNavigationDestination(
            icon: native ? 'hammer' : Icons.build_outlined,
            selectedIcon: native ? 'hammer.fill' : Icons.build,
            label: 'Developer',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final status = _status;

    if (status == null && _error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            const Text("Couldn't reach the server."),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return switch (_tab) {
      0 => OverviewScreen(status: status, onRefresh: _load),
      1 => FloorsScreen(status: status, onRefresh: _load),
      _ => DeveloperScreen(api: widget.api, status: status, onChanged: _load),
    };
  }
}
