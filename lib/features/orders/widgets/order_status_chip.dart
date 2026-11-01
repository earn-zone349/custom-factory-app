import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/order.dart';

/// Small colored label showing an order's status.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  /// Background and text color for the current status.
  (Color, Color) get _colors {
    return switch (status) {
      OrderStatus.delivered => (AppColors.primary, Colors.white),
      OrderStatus.cancelled => (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
        ),
      OrderStatus.placed ||
      OrderStatus.confirmed ||
      OrderStatus.inProduction ||
      OrderStatus.qualityCheck ||
      OrderStatus.outForDelivery =>
        (AppColors.primaryLight, AppColors.primaryDark),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = _colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
