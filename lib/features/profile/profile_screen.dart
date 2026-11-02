import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/constants/app_spacing.dart';
import '../admin/admin_access.dart';
import '../admin/admin_dashboard_screen.dart';
import '../factory_portal/factory_access.dart';
import '../factory_portal/factory_portal_screen.dart';

/// Profile tab. Account details arrive with the real login; for now it is
/// the entry point to the admin panel.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openFactoryPanel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FactoryPortalScreen()),
    );
  }

  void _openAdminPanel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.person_rounded,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppConfig.appName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Account details come with login',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (AdminAccess.isEnabled) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Admin panel'),
                subtitle: const Text('Manage orders'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openAdminPanel(context),
              ),
            ),
          ],
          if (FactoryAccess.isEnabled) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.factory_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Factory panel'),
                subtitle: const Text('View and update factory orders'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openFactoryPanel(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
