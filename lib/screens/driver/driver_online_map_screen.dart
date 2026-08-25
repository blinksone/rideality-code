import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_config.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../models/trip_models.dart';
import '../../services/driver_api_service.dart';
import '../../services/driver_location_tracker.dart';
import '../../services/realtime_socket_service.dart';
import '../../services/trips_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/rideality_trip_map.dart';
import '../passenger/notifications_screen.dart';
import '../shared/active_ride_screen.dart';
import 'under_review_screen.dart';

/// Online mode — map + live Socket.IO ride offers.
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
  final bool canDrive;
  final bool embedded;
  final ValueChanged<DriverView>? onDriverUpdated;
  final VoidCallback? onOpenDashboard;

  @override
  State<DriverOnlineMapScreen> createState() => _DriverOnlineMapScreenState();
}

class _DriverOnlineMapScreenState extends State<DriverOnlineMapScreen> {
  late DriverView _driver;
  late List<DriverServiceMode> _serviceModes;
  DispatchOffer? _offer;
  bool _toggling = false;
  bool _responding = false;
  bool _savingModes = false;
  StreamSubscription<DispatchOffer>? _offerSub;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<Position>? _posSub;

  double? _driverLat;
  double? _driverLng;

  final _socket = RealtimeSocketService.instance;
  final _location = DriverLocationTracker.instance;
  final _trips = TripsApiService.instance;

  @override
  void initState() {
    super.initState();
    _driver = widget.driver;
    _serviceModes = List<DriverServiceMode>.from(
      _driver.serviceModes.isEmpty
          ? const [DriverServiceMode.rides]
          : _driver.serviceModes,
    );
    if (_driver.isOnline) {
      unawaited(_goLiveStack());
    }
  }

  @override
  void didUpdateWidget(covariant DriverOnlineMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver.isOnline != widget.driver.isOnline ||
        oldWidget.wallet.balance != widget.wallet.balance ||
        oldWidget.driver.serviceModes != widget.driver.serviceModes) {
      _driver = widget.driver;
      if (widget.driver.serviceModes.isNotEmpty) {
        _serviceModes = List<DriverServiceMode>.from(widget.driver.serviceModes);
      }
      if (_driver.isOnline) {
        unawaited(_goLiveStack());
      } else {
        unawaited(_tearDownLive());
        setState(() => _offer = null);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_offerSub?.cancel());
    unawaited(_connSub?.cancel());
    unawaited(_posSub?.cancel());
    super.dispose();
  }

  String get _vehicleType {
    final raw = widget.driver.vehicleType;
    if (raw == null || raw.toString().isEmpty) return 'sedan';
    return raw.toString().toLowerCase();
  }

  List<String> get _modesApi => DriverServiceMode.toApiList(_serviceModes);

  Future<void> _startMapLocationWatch() async {
    await _posSub?.cancel();
    final pos = await _location.currentPosition();
    if (pos != null && mounted) {
      setState(() {
        _driverLat = pos.latitude;
        _driverLng = pos.longitude;
      });
    }
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((p) {
      if (!mounted) return;
      setState(() {
        _driverLat = p.latitude;
        _driverLng = p.longitude;
      });
    });
  }

  Future<void> _stopMapLocationWatch() async {
    await _posSub?.cancel();
    _posSub = null;
  }

  Future<void> _goLiveStack() async {
    await _offerSub?.cancel();
    await _connSub?.cancel();
    try {
      await _socket.connectAsDriver(
        vehicleType: _vehicleType,
        serviceModes: _modesApi,
      );
      try {
        await _location.start(
          vehicleType: _vehicleType,
          serviceModes: _modesApi,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission needed to receive nearby requests.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      unawaited(_startMapLocationWatch());
      _offerSub = _socket.dispatchOffers.listen((offer) {
        if (!mounted || !_driver.isOnline) return;
        setState(() => _offer = offer);
      });
      _connSub = _socket.connectionChanges.listen((ok) {
        if (ok && _driver.isOnline) {
          unawaited(
            _socket.connectAsDriver(
              vehicleType: _vehicleType,
              serviceModes: _modesApi,
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Realtime connect failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _tearDownLive() async {
    await _offerSub?.cancel();
    _offerSub = null;
    await _connSub?.cancel();
    _connSub = null;
    await _stopMapLocationWatch();
    await _location.stop();
  }

  Future<void> _setServiceModeSelection(List<DriverServiceMode> next) async {
    if (next.isEmpty || _savingModes) return;
    setState(() {
      _serviceModes = next;
      _savingModes = true;
    });
    try {
      final updated = await DriverApiService.instance.setServiceModes(next);
      if (!mounted) return;
      final modes = updated.serviceModes.isNotEmpty
          ? updated.serviceModes
          : next;
      setState(() {
        _driver = updated.copyWith(serviceModes: modes);
        _serviceModes = List<DriverServiceMode>.from(modes);
        _savingModes = false;
      });
      widget.onDriverUpdated?.call(_driver);
      _location.updateServiceModes(DriverServiceMode.toApiList(modes));
      if (_driver.isOnline) {
        await _socket.updateSession(
          vehicleType: _vehicleType,
          role: SessionRole.driver,
          serviceModes: DriverServiceMode.toApiList(modes),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _savingModes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingModes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update service modes: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleOnline() async {
    if (_toggling) return;
    final goOnline = !_driver.isOnline;
    if (goOnline && !widget.canDrive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish verification before going online. Waiting for your city fleet to approve you.'),
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
        modes: goOnline ? _serviceModes : null,
      );
      if (!mounted) return;
      setState(() {
        _driver = updated.copyWith(
          serviceModes: updated.serviceModes.isNotEmpty
              ? updated.serviceModes
              : _serviceModes,
        );
        if (updated.serviceModes.isNotEmpty) {
          _serviceModes = List<DriverServiceMode>.from(updated.serviceModes);
        }
        _toggling = false;
        if (!goOnline) _offer = null;
      });
      if (goOnline) {
        await _goLiveStack();
      } else {
        await _tearDownLive();
      }
      if (!mounted) return;
      widget.onDriverUpdated?.call(_driver);
      if (!widget.embedded && !goOnline) {
        Navigator.of(context).pop(_driver);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _toggling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _decline() async {
    final o = _offer;
    if (o == null || _responding) return;
    setState(() {
      _responding = true;
      _offer = null;
    });
    try {
      _socket.emitDispatchResponse(rideId: o.rideId, accepted: false);
      try {
        await _trips.dispatchResponse(o.rideId, accepted: false);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request declined'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  Future<void> _accept() async {
    final o = _offer;
    if (o == null || _responding) return;
    setState(() {
      _responding = true;
      _offer = null;
    });
    try {
      // Prefer socket. REST is fallback only (avoids double ack / double join).
      _socket.emitDispatchResponse(rideId: o.rideId, accepted: true);
      if (!_socket.isConnected) {
        try {
          await _trips.dispatchResponse(o.rideId, accepted: true);
          _socket.joinRide(o.rideId);
        } catch (_) {}
      }
      await _socket.updateSession(
        rideId: o.rideId,
        role: SessionRole.driver,
        vehicleType: _vehicleType,
        serviceModes: _modesApi,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            o.isCargo
                ? 'Cargo accepted · heading to pickup'
                : 'Ride accepted · heading to ${o.riderName ?? 'pickup'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Navigator.of(context).pushNamed(
        ActiveRideScreen.routeName,
        arguments: ActiveRideArgs(
          tripId: o.rideId,
          role: SessionRole.driver,
        ),
      );
    } finally {
      if (mounted) setState(() => _responding = false);
    }
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
        RidealityTripMap(
          live: _driverLat != null && _driverLng != null
              ? LatLng(_driverLat!, _driverLng!)
              : null,
          pickup: _offer != null
              ? LatLng(_offer!.pickupLat, _offer!.pickupLng)
              : null,
          myLocationEnabled: _driver.isOnline,
          bottomGradient: false,
        ),
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
                _ServiceModeSegment(
                  modes: _serviceModes,
                  enabled: !_savingModes && !_toggling,
                  onChanged: _setServiceModeSelection,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
        Align(
          alignment: Alignment.bottomCenter,
          child: _offer != null
              ? _RideRequestCard(
                  key: ValueKey(_offer!.rideId),
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
                    Navigator.of(context)
                        .pushNamed(UnderReviewScreen.routeName);
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

class _RideRequestCard extends StatefulWidget {
  const _RideRequestCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  static const int warningSeconds = 5;

  final DispatchOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<_RideRequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown;
  late final int _respondSeconds;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _respondSeconds = widget.offer.timeoutSeconds;
    _countdown = AnimationController(
      vsync: this,
      duration: Duration(seconds: _respondSeconds),
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
    final pickupLabel =
        '${offer.pickupLat.toStringAsFixed(4)}, ${offer.pickupLng.toStringAsFixed(4)}';

    return AnimatedBuilder(
      animation: _countdown,
      builder: (context, child) {
        final remainingFraction = 1.0 - _countdown.value;
        final secondsLeft = (_respondSeconds * remainingFraction)
            .ceil()
            .clamp(0, _respondSeconds);
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
                              urgent
                                  ? 'Respond now'
                                  : offer.isCargo
                                      ? 'New cargo request'
                                      : 'New ride request',
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
                        children: [
                          Text(
                            offer.fareLabel(),
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
                              color: offer.isCargo
                                  ? AppColors.accentSoft
                                  : AppColors.surfaceTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              offer.isCargo ? 'CARGO' : 'RIDE',
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: offer.isCargo
                                    ? AppColors.accent
                                    : AppColors.secondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (offer.isCargo) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (offer.cargoWeightKg != null)
                              _OfferMetaChip(
                                icon: Icons.scale_rounded,
                                label: offer.weightLabel,
                              ),
                            if (offer.cargoSizeTier != null &&
                                offer.cargoSizeTier!.isNotEmpty)
                              _OfferMetaChip(
                                icon: Icons.inventory_2_outlined,
                                label: offer.cargoSizeTier!.toUpperCase(),
                              ),
                            if (offer.cargoDescription != null &&
                                offer.cargoDescription!.isNotEmpty)
                              _OfferMetaChip(
                                icon: Icons.notes_rounded,
                                label: offer.cargoDescription!,
                              ),
                          ],
                        ),
                      ],
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
                          if (offer.dropoffDistanceMeters != null &&
                              offer.dropoffDistanceMeters! > 0) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Trip ${(offer.dropoffDistanceMeters! / 1000).toStringAsFixed(1)} km',
                              style: tt.labelMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: offer.isCargo
                                  ? AppColors.accentSoft
                                  : AppColors.surfaceTint,
                              child: Icon(
                                offer.isCargo
                                    ? Icons.local_shipping_rounded
                                    : Icons.person_rounded,
                                color: offer.isCargo
                                    ? AppColors.accent
                                    : AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.riderName ??
                                        (offer.isCargo
                                            ? 'Cargo shipper'
                                            : 'Passenger'),
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID ${offer.rideId}',
                                    style: tt.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RouteRow(
                        kind: 'PICKUP',
                        place: pickupLabel,
                        color: offer.isCargo
                            ? AppColors.accent
                            : AppColors.secondary,
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
                        place: offer.dropoffLabel ?? 'See trip details',
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

class _ServiceModeSegment extends StatelessWidget {
  const _ServiceModeSegment({
    required this.modes,
    required this.onChanged,
    this.enabled = true,
  });

  final List<DriverServiceMode> modes;
  final ValueChanged<List<DriverServiceMode>> onChanged;
  final bool enabled;

  int get _index {
    final rides = modes.contains(DriverServiceMode.rides);
    final cargo = modes.contains(DriverServiceMode.cargo);
    if (rides && cargo) return 2;
    if (cargo) return 1;
    return 0;
  }

  void _select(int i) {
    if (!enabled) return;
    switch (i) {
      case 1:
        onChanged(const [DriverServiceMode.cargo]);
      case 2:
        onChanged(const [DriverServiceMode.rides, DriverServiceMode.cargo]);
      default:
        onChanged(const [DriverServiceMode.rides]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = const ['Rides', 'Cargo', 'Both'];
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.ambientShadow,
        ),
        child: Row(
          children: List.generate(3, (i) {
            final selected = _index == i;
            return Expanded(
              child: Material(
                color: selected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled ? () => _select(i) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? AppColors.onAccent
                                : AppColors.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _OfferMetaChip extends StatelessWidget {
  const _OfferMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
            ),
          ),
        ],
      ),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                online ? 'Looking for nearby requests…' : "You're offline",
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                    online
                        ? 'Stay close to busy areas, $name.'
                        : 'Pick Rides, Cargo, or Both, then go online.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: online ? 'Go offline' : 'Go online',
                variant:
                    online ? AppButtonVariant.ghost : AppButtonVariant.primary,
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
