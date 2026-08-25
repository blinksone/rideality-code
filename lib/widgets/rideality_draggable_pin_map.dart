import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/maps_config.dart';
import '../theme/app_colors.dart';

/// Map with a fixed center pin — drag the map to move the pickup point.
class RidealityDraggablePinMap extends StatefulWidget {
  const RidealityDraggablePinMap({
    super.key,
    required this.center,
    this.onCenterSettled,
    this.myLocationEnabled = true,
    this.pinColor = AppColors.secondary,
  });

  final LatLng center;
  final ValueChanged<LatLng>? onCenterSettled;
  final bool myLocationEnabled;
  final Color pinColor;

  @override
  State<RidealityDraggablePinMap> createState() =>
      RidealityDraggablePinMapState();
}

class RidealityDraggablePinMapState extends State<RidealityDraggablePinMap> {
  GoogleMapController? _controller;
  LatLng _pendingCenter = const LatLng(
    MapsConfig.defaultLat,
    MapsConfig.defaultLng,
  );
  bool _mapReady = false;
  bool _programmaticMove = false;

  @override
  void initState() {
    super.initState();
    _pendingCenter = widget.center;
  }

  @override
  void didUpdateWidget(covariant RidealityDraggablePinMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _pendingCenter = widget.center;
      unawaited(_animateTo(widget.center));
    }
  }

  @override
  void dispose() {
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
