import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/maps_config.dart';
import '../theme/app_colors.dart';

/// Google Maps trip view — pickup, dropoff, and optional live driver pin.
class RidealityTripMap extends StatefulWidget {
  const RidealityTripMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.live,
    this.showBack = false,
    this.onBack,
    this.compact = false,
    this.etaMinutes,
    this.myLocationEnabled = false,
    this.interactive = true,
    this.bottomGradient = true,
  });

  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? live;
  final bool showBack;
  final VoidCallback? onBack;
  final bool compact;
  final int? etaMinutes;
  final bool myLocationEnabled;
  final bool interactive;
  final bool bottomGradient;

  @override
  State<RidealityTripMap> createState() => _RidealityTripMapState();
}

class _RidealityTripMapState extends State<RidealityTripMap> {
  GoogleMapController? _controller;
  bool _mapReady = false;

  static const _defaultTarget = LatLng(MapsConfig.defaultLat, MapsConfig.defaultLng);

  @override
  void didUpdateWidget(covariant RidealityTripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.dropoff != widget.dropoff ||
        oldWidget.live != widget.live) {
      unawaited(_fitCamera());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final pickup = widget.pickup;
    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Driver'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
    return markers;
  }

  List<LatLng> get _cameraPoints {
    return [
      if (widget.pickup != null) widget.pickup!,
      if (widget.dropoff != null) widget.dropoff!,
      if (widget.live != null) widget.live!,
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
    } catch (_) {
      // Bounds can fail on first layout; ignore and retry on next update.
    }
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points.skip(1)) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
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

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialTarget,
            zoom: widget.compact ? 13 : 14,
          ),
          markers: _markers,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      ],
    );
  }
}
