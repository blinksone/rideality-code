import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/maps_config.dart';
import '../core/vehicle_catalog.dart';
import '../models/trip_models.dart';
import '../theme/app_colors.dart';

/// Google Maps trip view — pickup, dropoff, route, animated Redis supply pins.
class RidealityTripMap extends StatefulWidget {
  const RidealityTripMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.live,
    this.routePoints = const [],
    this.supplyPins = const [],
    this.showBack = false,
    this.onBack,
    this.compact = false,
    this.etaMinutes,
    this.myLocationEnabled = false,
    this.interactive = true,
    this.bottomGradient = true,
    this.showEmptySupplyBanner = false,
  });

  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? live;

  /// Road path between pickup and dropoff.
  final List<LatLng> routePoints;

  /// Anonymous Redis supply pins (`GET /trips/nearby-supply`).
  final List<NearbySupplyPin> supplyPins;

  final bool showBack;
  final VoidCallback? onBack;
  final bool compact;
  final int? etaMinutes;
  final bool myLocationEnabled;
  final bool interactive;
  final bool bottomGradient;

  /// When true and [supplyPins] is empty, show "No cars nearby".
  final bool showEmptySupplyBanner;

  @override
  State<RidealityTripMap> createState() => _RidealityTripMapState();
}

class _AnimPin {
  _AnimPin({
    required this.id,
    required this.from,
    required this.to,
    this.etaMin,
    this.product,
  });

  final String id;
  LatLng from;
  LatLng to;
  int? etaMin;
  String? product;

  LatLng at(double t) {
    final u = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * u,
      from.longitude + (to.longitude - from.longitude) * u,
    );
  }
}

class _RidealityTripMapState extends State<RidealityTripMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  bool _mapReady = false;
  late final AnimationController _pinAnim;
  List<_AnimPin> _pins = const [];
  int _pinSeq = 0;

  static const _defaultTarget =
      LatLng(MapsConfig.defaultLat, MapsConfig.defaultLng);

  @override
  void initState() {
    super.initState();
    _pinAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _applySupplyTargets(widget.supplyPins, animate: false);
  }

  @override
  void didUpdateWidget(covariant RidealityTripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.dropoff != widget.dropoff ||
        oldWidget.live != widget.live ||
        !_sameRoute(oldWidget.routePoints, widget.routePoints)) {
      unawaited(_fitCamera());
    }
    if (!_sameSupply(oldWidget.supplyPins, widget.supplyPins)) {
      _applySupplyTargets(widget.supplyPins, animate: true);
    }
  }

  bool _sameRoute(List<LatLng> a, List<LatLng> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }

  bool _sameSupply(List<NearbySupplyPin> a, List<NearbySupplyPin> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude ||
          a[i].product != b[i].product ||
          a[i].etaMin != b[i].etaMin) {
        return false;
      }
    }
    return true;
  }

  void _applySupplyTargets(List<NearbySupplyPin> next, {required bool animate}) {
    final t = _pinAnim.value;
    final currentPos = <_AnimPin>[
      for (final p in _pins)
        _AnimPin(
          id: p.id,
          from: p.at(t),
          to: p.at(t),
          etaMin: p.etaMin,
          product: p.product,
        ),
    ];

    final remaining = List<_AnimPin>.from(currentPos);
    final matched = <_AnimPin>[];

    for (final target in next) {
      final product = VehicleCatalog.normalize(target.product);
      final dest = LatLng(target.latitude, target.longitude);
      _AnimPin? best;
      var bestDist = double.infinity;
      for (final c in remaining) {
        if (VehicleCatalog.normalize(c.product) != product) continue;
        final d = _distSq(c.from, dest);
        if (d < bestDist) {
          bestDist = d;
          best = c;
        }
      }
      if (best != null && bestDist < 0.0008) {
        // ~1km² threshold — keep local id, tween toward jittered target.
        remaining.remove(best);
        matched.add(
          _AnimPin(
            id: best.id,
            from: best.from,
            to: dest,
            etaMin: target.etaMin,
            product: product,
          ),
        );
      } else {
        matched.add(
          _AnimPin(
            id: 's${_pinSeq++}',
            from: dest,
            to: dest,
            etaMin: target.etaMin,
            product: product,
          ),
        );
      }
    }

    _pins = matched;
    if (animate && matched.any((p) => p.from != p.to)) {
      _pinAnim.forward(from: 0);
    } else {
      _pinAnim.value = 1;
    }
    if (mounted) setState(() {});
  }

  double _distSq(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }

  @override
  void dispose() {
    _pinAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  double _hueForProduct(String? product) {
    final t = VehicleCatalog.normalize(product);
    return switch (t) {
      VehicleCatalog.bike => BitmapDescriptor.hueRed,
      VehicleCatalog.rickshaw => BitmapDescriptor.hueOrange,
      VehicleCatalog.ac => BitmapDescriptor.hueAzure,
      VehicleCatalog.cargo => BitmapDescriptor.hueViolet,
      _ => BitmapDescriptor.hueRose,
    };
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final pickup = widget.pickup;
    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    }
    final dropoff = widget.dropoff;
    if (dropoff != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }
    final live = widget.live;
    if (live != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('live'),
          position: live,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Driver'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    final t = _pinAnim.value;
    for (final p in _pins) {
      final pos = p.at(t);
      final eta = p.etaMin;
      markers.add(
        Marker(
          markerId: MarkerId('supply_${p.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _hueForProduct(p.product),
          ),
          infoWindow: InfoWindow(
            title: eta != null ? '$eta min' : 'Nearby',
          ),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
        ),
      );
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    final points = widget.routePoints;
    if (points.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('trip_route_under'),
        points: points,
        color: AppColors.accent.withValues(alpha: 0.28),
        width: 10,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: -1,
      ),
      Polyline(
        polylineId: const PolylineId('trip_route'),
        points: points,
        color: AppColors.accent,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  List<LatLng> get _cameraPoints {
    if (widget.routePoints.length >= 2) return widget.routePoints;
    return [
      if (widget.pickup != null) widget.pickup!,
      if (widget.dropoff != null) widget.dropoff!,
      if (widget.live != null) widget.live!,
      ..._pins.map((p) => p.to),
    ];
  }

  LatLng get _initialTarget {
    final points = _cameraPoints;
    if (points.isNotEmpty) return points.first;
    return _defaultTarget;
  }

  Future<void> _fitCamera() async {
    if (!_mapReady) return;
    final controller = _controller;
    if (controller == null) return;

    final points = _cameraPoints;
    try {
      if (points.length >= 2) {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(_boundsFromPoints(points), 72),
        );
      } else if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, widget.compact ? 14 : 15),
        );
      }
    } catch (_) {}
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points.skip(1)) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    const pad = 0.004;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eta = widget.etaMinutes;
    final emptySupply =
        widget.showEmptySupplyBanner && widget.supplyPins.isEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialTarget,
            zoom: widget.compact ? 13 : 14,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          liteModeEnabled: false,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
          onMapCreated: (controller) {
            _controller = controller;
            _mapReady = true;
            unawaited(_fitCamera());
          },
        ),
        if (widget.bottomGradient)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x220B1220),
                  Color(0x000B1220),
                  Color(0x660B1220),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        if (widget.showBack && widget.onBack != null)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onBack,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.onSurface,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (eta != null)
          Positioned(
            left: 0,
            right: 0,
            top: widget.compact ? 72 : 120,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppColors.ambientShadow,
                ),
                child: Text(
                  '$eta min',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                ),
              ),
            ),
          ),
        if (emptySupply)
          Positioned(
            left: 16,
            right: 16,
            bottom: widget.compact ? 16 : 28,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.ambientShadow,
                ),
                child: Text(
                  'No cars nearby',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
