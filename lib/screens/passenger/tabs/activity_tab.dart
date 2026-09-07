import 'package:flutter/material.dart';

import '../../../models/api_models.dart';
import '../../../models/trip_models.dart';
import '../../../theme/app_colors.dart';
import '../../shared/active_ride_screen.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({
    super.key,
    required this.rides,
    required this.onRefresh,
  });

  final List<RideSummary> rides;
  final Future<void> Function() onRefresh;

  Future<void> _openRide(BuildContext context, RideSummary ride) async {
    if (!ride.isActive || ride.id.isEmpty) return;
    await Navigator.of(context).pushNamed(
      ActiveRideScreen.routeName,
      arguments: ActiveRideArgs(
        tripId: ride.id,
        role: SessionRole.rider,
      ),
    );
    await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Activity',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: onRefresh,
              child: rides.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.45,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceTint,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.route_rounded,
                                  size: 36,
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No rides yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your trip history will show up here.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: rides.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ride = rides[index];
                        return _RideCard(
                          ride: ride,
                          onTap: ride.isActive
                              ? () => _openRide(context, ride)
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, this.onTap});

  final RideSummary ride;
  final VoidCallback? onTap;

  Color get _statusColor {
    final s = ride.status.toLowerCase();
    if (s.contains('complete') || s == 'completed') return AppColors.success;
    if (s.contains('cancel')) return AppColors.error;
    if (s.contains('progress') || s.contains('active')) {
      return AppColors.secondary;
    }
    return AppColors.amber;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.ambientShadow,
            border: ride.isActive
                ? Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      ride.statusLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                            fontSize: 11,
                          ),
                    ),
                  ),
                  if (ride.vehicleTypeLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        ride.vehicleTypeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                  if (ride.isActive) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Tap to open',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const Spacer(),
                  if (ride.fare != null)
                    Text(
                      '${ride.currency} ${ride.fare!.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _routeLine(
                context,
                Icons.radio_button_checked,
                AppColors.secondary,
                ride.pickupAddress ?? 'Pickup',
              ),
              Padding(
                padding: const EdgeInsets.only(left: 11),
                child: Container(
                  width: 2,
                  height: 16,
                  color: AppColors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              _routeLine(
                context,
                Icons.location_on_rounded,
                AppColors.error,
                ride.dropoffAddress ?? 'Destination',
              ),
              if (ride.createdAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  _formatRideDate(ride.createdAt!),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ISO → local readable, e.g. `25 Aug 2026 · 3:04 PM`.
  static String _formatRideDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final d = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h24 = d.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year} · $h12:$minute $ampm';
  }

  Widget _routeLine(
    BuildContext context,
    IconData icon,
    Color color,
    String text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
