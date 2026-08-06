import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../services/driver_api_service.dart';
import '../../theme/app_colors.dart';
import '../../core/api/api_config.dart';
import '../../widgets/app_button.dart';
import '../passenger/notifications_screen.dart';
import 'under_review_screen.dart';

/// Online mode — map + ride request offers.
/// When [embedded] is true, renders inside the driver dashboard (no route push).
class DriverOnlineMapScreen extends StatefulWidget {
  const DriverOnlineMapScreen({
    super.key,
    required this.driver,
    required this.me,
    required this.wallet,
    this.canDrive = true,
    this.embedded = false,
    this.onDriverUpdated,
    this.onOpenDashboard,
  });

  final DriverView driver;
  final UserProfile me;
  final WalletInfo wallet;

  /// When false, go-online navigates to verification instead.
  final bool canDrive;

  /// Hosted inside [DriverDashboardScreen] instead of a pushed route.
  final bool embedded;

  /// Notifies parent of availability / driver view changes.
  final ValueChanged<DriverView>? onDriverUpdated;

  /// Map header — open dashboard menu (embedded) or pop.
  final VoidCallback? onOpenDashboard;

  @override
  State<DriverOnlineMapScreen> createState() => _DriverOnlineMapScreenState();
}

class _DriverOnlineMapScreenState extends State<DriverOnlineMapScreen> {
  late DriverView _driver;
  _RideOffer? _offer;
  Timer? _offerTimer;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _driver = widget.driver;
    _scheduleOffer();
  }

  @override
  void didUpdateWidget(covariant DriverOnlineMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver.isOnline != widget.driver.isOnline ||
        oldWidget.wallet.balance != widget.wallet.balance) {
      _driver = widget.driver;
      if (_driver.isOnline) {
        _scheduleOffer();
      } else {
        _offerTimer?.cancel();
        _offer = null;
      }
    }
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    super.dispose();
  }

  void _scheduleOffer() {
    _offerTimer?.cancel();
    if (!_driver.isOnline) {
      setState(() => _offer = null);
      return;
    }
    _offerTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_driver.isOnline) return;
      setState(() => _offer ??= _RideOffer.demo());
    });
  }

  Future<void> _toggleOnline() async {
    if (_toggling) return;
    final goOnline = !_driver.isOnline;
    if (goOnline && !widget.canDrive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish verification before going online.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamed(UnderReviewScreen.routeName);
      return;
    }

    setState(() => _toggling = true);
    try {
      final updated = await DriverApiService.instance.setAvailability(
        isOnline: goOnline,
      );
      if (!mounted) return;
      setState(() {
        _driver = updated;
        _toggling = false;
        if (!goOnline) _offer = null;
      });
      if (goOnline) {
        _scheduleOffer();
      } else {
        _offerTimer?.cancel();
      }
      widget.onDriverUpdated?.call(updated);
      if (!widget.embedded && !goOnline) {
        Navigator.of(context).pop(updated);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _toggling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _decline() {
    setState(() => _offer = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request declined'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _offerTimer?.cancel();
    _offerTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || !_driver.isOnline) return;
      setState(() => _offer = _RideOffer.demo(variant: 1));
    });
  }

  void _accept() {
    final o = _offer;
    setState(() => _offer = null);
    if (o == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ride accepted · heading to ${o.pickup}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _earningsLabel {
    final bal = widget.wallet.balance;
    final currency = widget.wallet.currency;
    final symbol = currency.toUpperCase() == 'PKR' ? 'Rs.' : currency;
    return '$symbol ${bal.toStringAsFixed(0)} today';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.me.fullName ?? 'Driver';
    final photo = widget.me.photoUrl;
    final tt = Theme.of(context).textTheme;

    final content = Stack(
      fit: StackFit.expand,
      children: [
        const _DriverMapBackdrop(),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    _ProfileAvatarButton(
                      name: name,
                      photoUrl: photo,
                      onTap: () {
                        if (widget.embedded) {
                          widget.onOpenDashboard?.call();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: AppColors.ambientShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _earningsLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CircleBtn(
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          NotificationsScreen.routeName,
                        );
                      },
                      child: FutureBuilder<int>(
                        future: NotificationInbox.instance.unreadCount(),
                        builder: (context, snap) {
                          final n = snap.data ?? 0;
                          return Badge(
                            isLabelVisible: n > 0,
                            smallSize: 8,
                            backgroundColor: const Color(0xFFE53935),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.onSurface,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Material(
                  color: _driver.isOnline
                      ? AppColors.successSoft
                      : AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _toggling ? null : _toggleOnline,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_toggling)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          else
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _driver.isOnline
                                    ? AppColors.success
                                    : AppColors.onSurfaceVariant,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _driver.isOnline
                                ? "YOU'RE ONLINE · TAP TO GO OFFLINE"
                                : "YOU'RE OFFLINE · TAP TO GO ONLINE",
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _driver.isOnline
                                  ? const Color(0xFF15803D)
                                  : AppColors.secondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 180,
          child: IgnorePointer(child: Center(child: _MapPins())),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _offer != null
              ? _RideRequestCard(
                  key: ValueKey(
                    '${_offer!.passengerName}_${_offer!.fareLabel}',
                  ),
                  offer: _offer!,
                  onAccept: _accept,
                  onDecline: _decline,
                )
              : _WaitingPanel(
                  name: name,
                  online: _driver.isOnline,
                  toggling: _toggling,
                  onToggleOnline: _toggleOnline,
                  onOpenReview: () {
                    Navigator.of(context).pushNamed(
                      UnderReviewScreen.routeName,
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.background, child: content);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: content,
    );
  }
}

class _RideOffer {
  const _RideOffer({
    required this.fareLabel,
    required this.vehicleClass,
    required this.etaMinutes,
    required this.passengerName,
    required this.rating,
    required this.pickup,
    required this.dropoff,
  });

  final String fareLabel;
  final String vehicleClass;
  final int etaMinutes;
  final String passengerName;
  final double rating;
  final String pickup;
  final String dropoff;

  factory _RideOffer.demo({int variant = 0}) {
    if (variant == 1) {
      return const _RideOffer(
        fareLabel: 'Rs. 480',
        vehicleClass: 'GO',
        etaMinutes: 5,
        passengerName: 'Hassan K.',
        rating: 4.6,
        pickup: 'Gulberg III',
        dropoff: 'Johar Town',
      );
    }
    return const _RideOffer(
      fareLabel: 'Rs. 650',
      vehicleClass: 'RIDEX',
      etaMinutes: 3,
      passengerName: 'Amara J.',
      rating: 4.8,
      pickup: 'Liberty Market',
      dropoff: 'DHA Phase 5',
    );
  }
}

/// Incoming ride request card + response countdown (15s).
class _RideRequestCard extends StatefulWidget {
  const _RideRequestCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  static const int respondSeconds = 15;
  static const int warningSeconds = 5;

  final _RideOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<_RideRequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _RideRequestCard.respondSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_finished) {
          _finished = true;
          widget.onDecline();
        }
      });
    _countdown.forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  void _accept() {
    if (_finished) return;
    _finished = true;
    _countdown.stop();
    widget.onAccept();
  }

  void _decline() {
    if (_finished) return;
    _finished = true;
    _countdown.stop();
    widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final offer = widget.offer;

    return AnimatedBuilder(
      animation: _countdown,
      builder: (context, child) {
        final remainingFraction = 1.0 - _countdown.value;
        final secondsLeft = (_RideRequestCard.respondSeconds * remainingFraction)
            .ceil()
            .clamp(0, _RideRequestCard.respondSeconds);
        final urgent = secondsLeft <= _RideRequestCard.warningSeconds;
        final progressColor = urgent ? AppColors.error : AppColors.secondary;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CustomPaint(
                          painter: _CountdownRingPainter(
                            progress: remainingFraction,
                            color: progressColor,
                          ),
                          child: Center(
                            child: Text(
                              '$secondsLeft',
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: progressColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              urgent ? 'Respond now' : 'New ride request',
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: remainingFraction,
                                minHeight: 4,
                                backgroundColor: AppColors.surfaceContainerLow,
                                color: progressColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            offer.fareLabel,
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              offer.vehicleClass,
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.secondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${offer.etaMinutes} min away',
                            style: tt.labelMedium?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.surfaceTint,
                              child: Icon(
                                Icons.person_rounded,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.passengerName,
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: AppColors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        offer.rating.toStringAsFixed(1),
                                        style: tt.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: AppColors.surfaceContainerLowest,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Chat opens after you accept'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RouteRow(
                        kind: 'PICKUP',
                        place: offer.pickup,
                        color: AppColors.secondary,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Container(
                          width: 2,
                          height: 16,
                          color: AppColors.outlineVariant,
                        ),
                      ),
                      _RouteRow(
                        kind: 'DROP-OFF',
                        place: offer.dropoff,
                        color: AppColors.onSurface,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Decline',
                              icon: Icons.close_rounded,
                              variant: AppButtonVariant.ghost,
                              borderRadius: 28,
                              onPressed: _decline,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppButton(
                              label: 'Accept',
                              icon: Icons.check_rounded,
                              borderRadius: 28,
                              onPressed: _accept,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 120,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final track = Paint()
      ..color = AppColors.surfaceContainerLow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.kind,
    required this.place,
    required this.color,
  });

  final String kind;
  final String place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind,
                style: tt.labelSmall?.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                place,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({
    required this.name,
    required this.online,
    required this.toggling,
    required this.onToggleOnline,
    required this.onOpenReview,
  });

  final String name;
  final bool online;
  final bool toggling;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenReview;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppColors.ambientShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                online ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                size: 36,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 12),
              Text(
                online
                    ? 'Looking for nearby requests…'
                    : 'You\'re offline',
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                online
                    ? 'Stay close to busy areas, $name.'
                    : 'Go online to start receiving ride requests.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: online ? 'Go offline' : 'Go online',
                variant: online
                    ? AppButtonVariant.ghost
                    : AppButtonVariant.primary,
                borderRadius: 28,
                isLoading: toggling,
                onPressed: onToggleOnline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top-left profile: surfaceTint fill + brand initial / photo.
/// Uses inline image load so hot-reload of shared avatar widgets cannot null-out.
class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({
    required this.name,
    required this.onTap,
    this.photoUrl,
  });

  final String name;
  final String? photoUrl;
  final VoidCallback onTap;

  String get _initial {
    final t = name.trim();
    return t.isNotEmpty ? t[0].toUpperCase() : '?';
  }

  String? get _safeUrl {
    final resolved = ApiConfig.resolveMediaUrl(photoUrl);
    if (resolved == null || resolved.isEmpty) return null;
    final uri = Uri.tryParse(resolved);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    final url = _safeUrl;
    final placeholder = Text(
      _initial,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
            fontSize: 18,
          ),
    );

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.surfaceTint,
          child: url == null
              ? placeholder
              : ClipOval(
                  child: Image.network(
                    url,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Center(child: placeholder),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            shape: BoxShape.circle,
            boxShadow: AppColors.ambientShadow,
          ),
          width: 48,
          height: 48,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MapPins extends StatelessWidget {
  const _MapPins();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(-48, 36),
          child: const _Pin(
            color: AppColors.surfaceTint,
            border: AppColors.secondary,
            child: Icon(Icons.person, size: 18, color: AppColors.secondary),
          ),
        ),
        const _Pin(
          color: AppColors.secondary,
          border: AppColors.secondary,
          child: Icon(
            Icons.directions_car_filled_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.color,
    required this.border,
    required this.child,
  });

  final Color color;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
        boxShadow: AppColors.ambientShadow,
      ),
      child: Center(child: child),
    );
  }
}

class _DriverMapBackdrop extends StatelessWidget {
  const _DriverMapBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _DriverMapPainter()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.15),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8EEF5),
    );

    final road = Paint()
      ..color = const Color(0xFFD5DDE8)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final park =
        Paint()..color = const Color(0xFFC8E6C9).withValues(alpha: 0.5);
    final water =
        Paint()..color = const Color(0xFFBBDEFB).withValues(alpha: 0.65);
    final block = Paint()..color = const Color(0xFFDCE5F0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.5,
          size.height * 0.08,
          size.width * 0.55,
          size.height * 0.22,
        ),
        const Radius.circular(40),
      ),
      water,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.06,
          size.height * 0.52,
          size.width * 0.3,
          size.height * 0.16,
        ),
        const Radius.circular(18),
      ),
      park,
    );

    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 4; c++) {
        if ((r + c).isEven) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                16 + c * (size.width / 3.6),
                48 + r * (size.height / 7),
                size.width / 5.2,
                size.height / 11,
              ).deflate(6),
              const Radius.circular(4),
            ),
            block,
          );
        }
      }
    }

    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.36),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.48, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
