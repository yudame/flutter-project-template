import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/connectivity/connectivity_bloc.dart';
import '../../core/connectivity/connectivity_state.dart';

/// A banner that displays connectivity status to the user.
///
/// Shows different messages for poor connectivity and offline states.
/// Automatically hides when online.
class ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const ConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      builder: (context, state) {
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: state is ConnectivityOnline ? 0 : null,
              child: state.when(
                online: () => const SizedBox.shrink(),
                poor: () => _buildBanner(
                  context,
                  'Poor connection',
                  'Some features may be slow',
                  Colors.orange,
                  Icons.signal_wifi_statusbar_connected_no_internet_4,
                ),
                offline: () => _buildBanner(
                  context,
                  'No connection',
                  'Changes will sync when online',
                  Colors.red,
                  Icons.wifi_off,
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  Widget _buildBanner(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
