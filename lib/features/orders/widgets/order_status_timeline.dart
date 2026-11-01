import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../models/order.dart';

enum _StepState { done, current, upcoming }

/// Vertical progress tracker showing where an order is.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({super.key, required this.status});

  final OrderStatus status;

  static final List<OrderStatus> _steps = OrderStatus.values
      .where((OrderStatus step) => step != OrderStatus.cancelled)
      .toList(growable: false);

  static _StepState _stateFor(int index, int current) {
    if (index < current) return _StepState.done;
    if (index == current) {
      return index == _steps.length - 1 ? _StepState.done : _StepState.current;
    }
    return _StepState.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) return const _CancelledBanner();

    final int current = _steps.indexOf(status);
    return Column(
      children: <Widget>[
        for (int i = 0; i < _steps.length; i++)
          _TimelineStep(
            status: _steps[i],
            state: _stateFor(i, current),
            isLast: i == _steps.length - 1,
          ),
      ],
    );
  }
}

String _describe(OrderStatus status) {
  return switch (status) {
    OrderStatus.placed => 'We received your order',
    OrderStatus.confirmed => 'Design and final price confirmed',
    OrderStatus.inProduction => 'A factory is making your order',
    OrderStatus.qualityCheck => 'We check the quality',
    OrderStatus.outForDelivery => 'On its way to you',
    OrderStatus.delivered => 'Delivered to you',
    OrderStatus.cancelled => 'This order was cancelled',
  };
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.cancel_outlined, color: AppColors.error),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'This order was cancelled',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.status,
    required this.state,
    required this.isLast,
  });

  final OrderStatus status;
  final _StepState state;
  final bool isLast;

  Widget _indicator() {
    switch (state) {
      case _StepState.done:
        return const CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: const Center(
            child: CircleAvatar(radius: 5, backgroundColor: AppColors.primary),
          ),
        );
      case _StepState.upcoming:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool upcoming = state == _StepState.upcoming;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Column(
              children: <Widget>[
                _indicator(),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: state == _StepState.done
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    status.label,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: upcoming ? FontWeight.w400 : FontWeight.w600,
                      color: upcoming ? AppColors.textMuted : null,
                    ),
                  ),
                  Text(
                    _describe(status),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
