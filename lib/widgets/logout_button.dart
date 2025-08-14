// import 'package:flutter/material.dart';
// import 'package:onesignal_flutter/onesignal_flutter.dart';
// import '../services/auth_service.dart';

// class LogoutButton extends StatelessWidget {
//   const LogoutButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//       icon: const Icon(Icons.logout),
//       onPressed: () async {
//         // Unlink this device from the user for targeted pushes
//         OneSignal.logout();

//         await AuthService().logout();
//         if (context.mounted) {
//           Navigator.pushNamedAndRemoveUntil(
//               context, '/login', (route) => false);
//         }
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../services/auth_service.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Unlink this device from the user for targeted pushes
    OneSignal.logout();

    await AuthService().logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: const Icon(Icons.logout_rounded),
      tooltip: 'Logout',
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _handleLogout(context),
    );
  }
}
