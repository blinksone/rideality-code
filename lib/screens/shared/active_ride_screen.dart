import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/active_trip_store.dart';
import '../../models/trip_models.dart';
import '../../services/realtime_socket_service.dart';
import '../../services/trips_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/rideality_trip_map.dart';
import '../driver/cargo_proof_screen.dart';

/// Live trip tracking for rider or driver (status FSM + location animation).
class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({
    super.key,
    required this.tripId,
    required this.role,
    this.initialTrip,
  });

  static const routeName = '/active-ride';

  final String tripId;
  final SessionRole role;
  final Trip? initialTrip;

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _trips = TripsApiService.instance;
  final _socket = RealtimeSocketService.instance;

  Trip? _trip;
  String? _error;
  bool _busy = false;
  RideLocationUpdate? _loc;

  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.role == SessionRole.driver) {
        await _socket.connectAsDriver(rideId: widget.tripId);
      } else {
        await _socket.connectAsRider(rideId: widget.tripId);
        _socket.joinRide(widget.tripId);
      }
      await ActiveTripStore.instance.save(
        rideId: widget.tripId,
        role: widget.role,
      );

      final trip = await _trips.getTrip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _error = null;
      });
      if (trip.status.isTerminal) {
        await ActiveTripStore.instance.clear();
      }

      _subs.add(_socket.statusChanges.listen((e) {
        if (e.rideId != widget.tripId || !mounted) return;
        setState(() {
          _trip = (_trip ?? trip).copyWith(
            status: e.status,
            driverUserId: e.driverUserId,
            passengerUserId: e.passengerUserId,
          );
        });
        if (e.status.isTerminal) {
          _socket.leaveRide(widget.tripId);
          unawaited(ActiveTripStore.instance.clear());
        }
      }));

      _subs.add(_socket.locationUpdates.listen((e) {
        if (e.rideId != widget.tripId || !mounted) return;
        setState(() => _loc = e);
      }));

      _subs.add(_socket.noDrivers.listen((id) {
        if (id != widget.tripId || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No drivers available nearby. Try again shortly.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }));

      _subs.add(_socket.connectionChanges.listen((ok) {
        if (!ok || !mounted) return;
        // Reconnection: re-hello with role + rideId (service sends hello on connect).
        unawaited(
          _socket.updateSession(rideId: widget.tripId, role: widget.role),
        );
        if (widget.role == SessionRole.rider) {
          _socket.joinRide(widget.tripId);
        }
      }));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _reportDriver() async {
    final driverId = _trip?.driverUserId;
    if (driverId == null || driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver is not assigned yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Report driver'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'What happened?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a reason'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await UserApiService.instance.reportUser(
        reportedUserId: driverId,
        reason: reason,
        rideId: widget.tripId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report sent to city fleet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final trip = await _trips.cancelTrip(widget.tripId, reason: 'user_cancel');
      await ActiveTripStore.instance.clear();
      _socket.leaveRide(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _advanceStatus() async {
    final trip = _trip;
    final next = trip?.status.nextDriverStatus;
    if (trip == null || next == null || _busy) return;

    // Cargo: captured proof before picked_up / completed (server enforces too).
    if (trip.isCargo &&
        (next == TripStatus.pickedUp || next == TripStatus.completed)) {
      final stage = next == TripStatus.pickedUp
          ? CargoProofStage.pickup
          : CargoProofStage.dropoff;
      final confirmationType = next == TripStatus.pickedUp
          ? CargoProofKind.photo
          : trip.dropoffProofType;
      final result = await Navigator.of(context).pushNamed(
        CargoProofScreen.routeName,
        arguments: CargoProofArgs(
          bookingId: trip.id,
          stage: stage,
          confirmationType: confirmationType,
        ),
      );
      if (!mounted) return;
      if (result is Trip) {
        setState(() => _trip = result);
        if (result.status.isTerminal) {
          _socket.leaveRide(widget.tripId);
          await ActiveTripStore.instance.clear();
          if (mounted) await _showEarningsSummary(result);
        }
      } else {
        // Refresh trip in case proof landed without advancement.
        try {
          final refreshed = await _trips.getTrip(trip.id);
          if (mounted) setState(() => _trip = refreshed);
          if (refreshed.status.isTerminal) {
            _socket.leaveRide(widget.tripId);
            await ActiveTripStore.instance.clear();
          }
        } catch (_) {}
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await _trips.updateStatus(trip.id, next);
      if (!mounted) return;
      setState(() {
        _trip = updated;
        _busy = false;
      });
      if (updated.status.isTerminal) {
        _socket.leaveRide(widget.tripId);
        await ActiveTripStore.instance.clear();
        if (mounted) await _showEarningsSummary(updated);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final code = (e.code ?? '').toUpperCase();
      // Idempotent: already at next / terminal from concurrent update.
      if (e.statusCode == 409 || code.contains('ALREADY')) {
        try {
          final refreshed = await _trips.getTrip(trip.id);
          if (!mounted) return;
          setState(() => _trip = refreshed);
          if (refreshed.status.isTerminal) {
            _socket.leaveRide(widget.tripId);
            await ActiveTripStore.instance.clear();
            if (mounted) await _showEarningsSummary(refreshed);
          }
        } catch (_) {}
        return;
      }
      if (code == 'CARGO_PICKUP_PROOF_REQUIRED' ||
          code.contains('PICKUP_PROOF')) {
        final result = await Navigator.of(context).pushNamed(
          CargoProofScreen.routeName,
          arguments: CargoProofArgs(
            bookingId: trip.id,
            stage: CargoProofStage.pickup,
            confirmationType: CargoProofKind.photo,
          ),
        );
        if (result is Trip && mounted) setState(() => _trip = result);
        return;
      }
      if (code == 'CARGO_DROPOFF_PROOF_REQUIRED' ||
          code.contains('DROPOFF_PROOF')) {
        final result = await Navigator.of(context).pushNamed(
          CargoProofScreen.routeName,
          arguments: CargoProofArgs(
            bookingId: trip.id,
            stage: CargoProofStage.dropoff,
            confirmationType: trip.dropoffProofType,
          ),
        );
        if (result is Trip && mounted) {
          setState(() => _trip = result);
          if (result.status.isTerminal) {
            await ActiveTripStore.instance.clear();
            if (mounted) await _showEarningsSummary(result);
          }
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showEarningsSummary(Trip trip) async {
    if (widget.role != SessionRole.driver) return;
    final fare = trip.fareEstimate ?? 0;
    final commission = fare * 0.15;
    final net = fare - commission;
    final currency = trip.currency.toUpperCase() == 'PKR' ? 'Rs' : trip.currency;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppColors.ambientShadow,
          ),
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
              const SizedBox(height: 18),
              Text(
                trip.isCargo ? 'Cargo delivered' : 'Trip complete',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated earn',
                style: tt.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$currency ${net.toStringAsFixed(0)}',
                style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Fare $currency ${fare.toStringAsFixed(0)} · platform ~$currency ${commission.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: tt.labelMedium,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Back to dashboard',
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  LatLng? _latLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final trip = _trip;
    final status = trip?.status ?? TripStatus.requested;
    final isDriver = widget.role == SessionRole.driver;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RidealityTripMap(
            pickup: _latLng(trip?.pickupLat, trip?.pickupLng),
            dropoff: _latLng(trip?.dropoffLat, trip?.dropoffLng),
            live: _loc != null ? LatLng(_loc!.lat, _loc!.lng) : null,
            compact: true,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Minimize',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerLowest,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: AppColors.ambientShadow,
                    ),
                    child: Text(
                      isDriver
                          ? (trip?.isCargo == true ? 'Cargo trip' : 'Driver trip')
                          : (trip?.isCargo == true ? 'Your cargo' : 'Your ride'),
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: AppColors.ambientShadow,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: _error != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            AppButton(
                              label: 'Retry',
                              onPressed: () {
                                setState(() => _error = null);
                                unawaited(_bootstrap());
                              },
                            ),
                          ],
                        )
                      : Column(
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
                            Text(
                              trip?.isCargo == true &&
                                      status == TripStatus.pickedUp
                                  ? 'In transit'
                                  : status.label,
                              style: tt.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              trip?.dropoffAddress ??
                                  trip?.pickupAddress ??
                                  'Ride ${widget.tripId}',
                              style: tt.bodyMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            if (trip?.isCargo == true &&
                                trip?.cargoWeightKg != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                [
                                  if (trip!.cargoSizeTier != null)
                                    trip.cargoSizeTier!.toUpperCase(),
                                  '${trip.cargoWeightKg!.toStringAsFixed(0)} kg',
                                  if (trip.cargoDescription != null &&
                                      trip.cargoDescription!.isNotEmpty)
                                    trip.cargoDescription!,
                                ].join(' · '),
                                style: tt.labelLarge?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (_loc?.etaSeconds != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'ETA ~ ${(_loc!.etaSeconds! / 60).ceil()} min',
                                style: tt.labelLarge?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _StatusSteps(status: status),
                            const SizedBox(height: 20),
                            if (isDriver &&
                                status.nextDriverActionLabelFor(
                                      trip?.bookingType ?? BookingType.ride,
                                    ) !=
                                    null &&
                                !status.isTerminal) ...[
                              if (trip?.needsCargoProofBeforeAdvance == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    trip!.needsPickupProof
                                        ? 'Take a photo to continue'
                                        : 'Confirm delivery (OTP or photo) to complete',
                                    textAlign: TextAlign.center,
                                    style: tt.labelMedium?.copyWith(
                                      color: AppColors.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              AppButton(
                                label: status.nextDriverActionLabelFor(
                                  trip?.bookingType ?? BookingType.ride,
                                )!,
                                isLoading: _busy,
                                onPressed: _advanceStatus,
                              ),
                            ],
                            if (!status.isTerminal) ...[
                              if (isDriver &&
                                  status.nextDriverActionLabelFor(
                                        trip?.bookingType ?? BookingType.ride,
                                      ) !=
                                      null)
                                const SizedBox(height: 10),
                              AppButton(
                                label: trip?.isCargo == true
                                    ? 'Cancel cargo'
                                    : 'Cancel ride',
                                variant: AppButtonVariant.ghost,
                                isLoading: _busy &&
                                    status.nextDriverActionLabel == null,
                                onPressed: _cancel,
                              ),
                            ],
                            // Passenger once-shown dropoff OTP
                            if (!isDriver &&
                                trip?.isCargo == true &&
                                trip?.dropoffOtp != null &&
                                trip!.dropoffOtp!.isNotEmpty &&
                                !status.isTerminal) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Give this code to the recipient',
                                      style: tt.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      trip.dropoffOtp!,
                                      style: tt.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (!isDriver &&
                                trip?.driverUserId != null &&
                                trip!.driverUserId!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              AppButton(
                                label: 'Report driver',
                                variant: AppButtonVariant.ghost,
                                onPressed: _reportDriver,
                              ),
                            ],
                            if (status.isTerminal) ...[
                              AppButton(
                                label: 'Done',
                                onPressed: () async {
                                  if (isDriver) {
                                    await _showEarningsSummary(
                                      trip ??
                                          Trip(
                                            id: widget.tripId,
                                            status: status,
                                          ),
                                    );
                                  } else {
                                    Navigator.of(context).maybePop();
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.status});

  final TripStatus status;

  static const _order = [
    TripStatus.requested,
    TripStatus.accepted,
    TripStatus.driverEnRoute,
    TripStatus.arrived,
    TripStatus.pickedUp,
    TripStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _order.indexOf(status);
    final current = idx < 0 ? 0 : idx;
    return Row(
      children: List.generate(_order.length, (i) {
        final done = i <= current && status != TripStatus.cancelled;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == _order.length - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: done ? AppColors.secondary : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

/// Route args for [ActiveRideScreen.routeName].
class ActiveRideArgs {
  const ActiveRideArgs({
    required this.tripId,
    required this.role,
    this.initialTrip,
  });

  final String tripId;
  final SessionRole role;
  final Trip? initialTrip;
}
