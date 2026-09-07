import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/maps_config.dart';
import '../core/vehicle_catalog.dart';
import '../models/trip_models.dart';
import '../theme/app_colors.dart';

/// Map with a fixed center pin — drag the map to move the pickup point.
class RidealityDraggablePinMap extends StatefulWidget {
  const RidealityDraggablePinMap({
    super.key,
    required this.center,
    this.onCenterSettled,
    this.myLocationEnabled = true,
    this.pinColor = AppColors.secondary,
    this.supplyPins = const [],
  });

  final LatLng center;
  final ValueChanged<LatLng>? onCenterSettled;
  final bool myLocationEnabled;
  final Color pinColor;

  /// Redis supply pins (anonymous).
  final List<NearbySupplyPin> supplyPins;

  @override
  State<RidealityDraggablePinMap> createState() =>
      RidealityDraggablePinMapState();
}

class RidealityDraggablePinMapState extends State<RidealityDraggablePinMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  LatLng _pendingCenter = const LatLng(
    MapsConfig.defaultLat,
    MapsConfig.defaultLng,
  );
  bool _mapReady = false;
  bool _programmaticMove = false;
  late final AnimationController _pinAnim;
  List<_SupplyAnim> _pins = const [];
  int _pinSeq = 0;

  @override
  void initState() {
    super.initState();
    _pendingCenter = widget.center;
    _pinAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _applySupply(widget.supplyPins, animate: false);
  }

  @override
  void didUpdateWidget(covariant RidealityDraggablePinMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _pendingCenter = widget.center;
      unawaited(_animateTo(widget.center));
    }
    if (!_sameSupply(oldWidget.supplyPins, widget.supplyPins)) {
      _applySupply(widget.supplyPins, animate: true);
    }
  }

  bool _sameSupply(List<NearbySupplyPin> a, List<NearbySupplyPin> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }

  void _applySupply(List<NearbySupplyPin> next, {required bool animate}) {
    final t = _pinAnim.value;
    final current = [
      for (final p in _pins)
        _SupplyAnim(id: p.id, from: p.at(t), to: p.at(t), product: p.product),
    ];
    final remaining = List<_SupplyAnim>.from(current);
    final matched = <_SupplyAnim>[];

    for (final target in next) {
      final product = VehicleCatalog.normalize(target.product);
      final dest = LatLng(target.latitude, target.longitude);
      _SupplyAnim? best;
      var bestDist = double.infinity;
      for (final c in remaining) {
        final dLat = c.from.latitude - dest.latitude;
        final dLng = c.from.longitude - dest.longitude;
        final d = dLat * dLat + dLng * dLng;
        if (d < bestDist) {
          bestDist = d;
          best = c;
        }
      }
      if (best != null && bestDist < 0.0008) {
        remaining.remove(best);
        matched.add(
          _SupplyAnim(
            id: best.id,
            from: best.from,
            to: dest,
            product: product,
          ),
        );
      } else {
        matched.add(
          _SupplyAnim(
            id: 's${_pinSeq++}',
            from: dest,
            to: dest,
            product: product,
          ),
        );
      }
    }
    _pins = matched;
    if (animate &&
        matched.any((p) =>
            p.from.latitude != p.to.latitude ||
            p.from.longitude != p.to.longitude)) {
      _pinAnim.forward(from: 0);
    } else {
      _pinAnim.value = 1;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pinAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// Move camera to [target] after a sheet selection or GPS fix.
  Future<void> moveTo(LatLng target, {double zoom = 16}) async {
    _pendingCenter = target;
    await _animateTo(target, zoom: zoom);
  }

  Future<void> _animateTo(LatLng target, {double zoom = 16}) async {
    if (!_mapReady || _controller == null) return;
    _programmaticMove = true;
    await _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  void _onCameraIdle() {
    if (_programmaticMove) {
      _programmaticMove = false;
      return;
    }
    widget.onCenterSettled?.call(_pendingCenter);
  }

  Set<Marker> get _supplyMarkers {
    final t = _pinAnim.value;
    return {
      for (final p in _pins)
        Marker(
          markerId: MarkerId('supply_${p.id}'),
          position: p.at(t),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            switch (VehicleCatalog.normalize(p.product)) {
              VehicleCatalog.bike => BitmapDescriptor.hueRed,
              VehicleCatalog.rickshaw => BitmapDescriptor.hueOrange,
              VehicleCatalog.ac => BitmapDescriptor.hueAzure,
              VehicleCatalog.cargo => BitmapDescriptor.hueViolet,
              _ => BitmapDescriptor.hueRose,
            },
          ),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.center,
            zoom: 16,
          ),
          markers: _supplyMarkers,
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
            _mapReady = true;
          },
          onCameraMove: (position) {
            _pendingCenter = position.target;
          },
          onCameraIdle: _onCameraIdle,
        ),
        IgnorePointer(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Icon(
                Icons.location_on_rounded,
                size: 44,
                color: widget.pinColor,
                shadows: const [
                  Shadow(
                    color: Color(0x44000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupplyAnim {
  _SupplyAnim({
    required this.id,
    required this.from,
    required this.to,
    this.product,
  });

  final String id;
  final LatLng from;
  final LatLng to;
  final String? product;

  LatLng at(double t) {
    final u = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * u,
      from.longitude + (to.longitude - from.longitude) * u,
    );
  }
}
