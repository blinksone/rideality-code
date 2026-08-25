import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/maps_config.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../models/place_models.dart';
import '../../services/driver_location_tracker.dart';
import '../../services/places_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/rideality_draggable_pin_map.dart';
import 'cargo_details_screen.dart';
import 'pickup_location_screen.dart';
import 'ride_confirm_screen.dart';

/// Yango-style pickup + destination — draggable map pin + location sheet.
class RidesDestinationScreen extends StatefulWidget {
  const RidesDestinationScreen({
    super.key,
    required this.places,
    this.canBook = true,
    this.initialDestination,
    this.vehicleType = 'sedan',
  });

  static const routeName = '/rides';

  final List<SavedPlace> places;
  final bool canBook;
  final String? initialDestination;
  final String vehicleType;

  @override
  State<RidesDestinationScreen> createState() => _RidesDestinationScreenState();
}

class RidesDestinationArgs {
  const RidesDestinationArgs({
    required this.places,
    this.canBook = true,
    this.initialDestination,
    this.vehicleType = 'sedan',
  });

  final List<SavedPlace> places;
  final bool canBook;
  final String? initialDestination;
  final String vehicleType;
}

class _RidesDestinationScreenState extends State<RidesDestinationScreen> {
  final _mapKey = GlobalKey<RidealityDraggablePinMapState>();
  final _placesApi = PlacesApiService.instance;

  LatLng _pickupCenter = const LatLng(
    MapsConfig.defaultLat,
    MapsConfig.defaultLng,
  );
  SelectedLocation? _pickup;
  SelectedLocation? _dropoff;

  bool _loadingPickup = true;
  bool _reverseGeocoding = false;
  bool _requesting = false;
  Timer? _reverseDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapPickup());
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapPickup() async {
    setState(() => _loadingPickup = true);
    Position? pos;
    try {
      pos = await DriverLocationTracker.instance.currentPosition();
    } catch (_) {}

    final lat = pos?.latitude ??
        widget.places
            .where((p) => p.isHome && p.latitude != 0)
            .map((p) => p.latitude)
            .firstOrNull ??
        MapsConfig.defaultLat;
    final lng = pos?.longitude ??
        widget.places
            .where((p) => p.isHome && p.longitude != 0)
            .map((p) => p.longitude)
            .firstOrNull ??
        MapsConfig.defaultLng;

    if (!mounted) return;
    setState(() {
      _pickupCenter = LatLng(lat, lng);
      _loadingPickup = false;
    });

    await _reverseGeocodePin(LatLng(lat, lng));
    if (widget.initialDestination != null &&
        widget.initialDestination!.trim().isNotEmpty) {
      // Pre-fill destination label; coords come from sheet if user re-opens.
      setState(() {
        _dropoff = SelectedLocation(
          name: widget.initialDestination!.trim(),
          address: widget.initialDestination!.trim(),
          latitude: lat + 0.012,
          longitude: lng + 0.008,
        );
      });
    }
  }

  void _onPinSettled(LatLng center) {
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_reverseGeocodePin(center));
    });
  }

  Future<void> _reverseGeocodePin(LatLng center) async {
    if (!mounted) return;
    setState(() {
      _reverseGeocoding = true;
      _pickupCenter = center;
    });
    try {
      final loc = await _placesApi.reverseGeocode(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted) return;
      setState(() {
        _pickup = loc;
        _reverseGeocoding = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _pickup = SelectedLocation(
          name: 'Selected point',
          address:
              '${center.latitude.toStringAsFixed(5)}, '
              '${center.longitude.toStringAsFixed(5)}',
          latitude: center.latitude,
          longitude: center.longitude,
        );
        _reverseGeocoding = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reverseGeocoding = false);
    }
  }

  Future<void> _openPickupSheet() async {
    final result = await PickupLocationScreen.show(
      context,
      title: 'Choose pickup',
      latitude: _pickupCenter.latitude,
      longitude: _pickupCenter.longitude,
      savedPlaces: widget.places,
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickup = result;
      _pickupCenter = LatLng(result.latitude, result.longitude);
    });
    await _mapKey.currentState?.moveTo(_pickupCenter);
  }

  Future<void> _openDropoffSheet() async {
    final result = await PickupLocationScreen.show(
      context,
      title: 'Choose destination',
      latitude: _pickupCenter.latitude,
      longitude: _pickupCenter.longitude,
      savedPlaces: widget.places,
    );
    if (result == null || !mounted) return;
    setState(() => _dropoff = result);
  }

  String get _pickupLabel {
    if (_loadingPickup) return 'Getting your location…';
    if (_reverseGeocoding) return 'Updating address…';
    final p = _pickup;
    if (p == null) return 'Move pin or search';
    return p.displayLine;
  }

  String get _dropoffLabel {
    final d = _dropoff;
    if (d == null) return 'Where to?';
    return d.displayLine;
  }

  Future<void> _confirm() async {
    if (_requesting) return;

    final pickup = _pickup;
    if (pickup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a pickup location'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final drop = _dropoff;
    if (drop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a destination'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!widget.canBook) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete your profile to book rides'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _requesting = true);
    try {
      await DashboardPrefs.instance.setLastDestination(drop.address);

      if (!mounted) return;
      setState(() => _requesting = false);

      if (widget.vehicleType == 'cargo') {
        await Navigator.of(context).pushNamed(
          CargoDetailsScreen.routeName,
          arguments: CargoDetailsArgs(
            pickupLat: pickup.latitude,
            pickupLng: pickup.longitude,
            dropoffLat: drop.latitude,
            dropoffLng: drop.longitude,
            pickupAddress: pickup.address.isNotEmpty
                ? pickup.address
                : pickup.name,
            dropoffAddress:
                drop.address.isNotEmpty ? drop.address : drop.name,
            canBook: widget.canBook,
          ),
        );
      } else {
        await Navigator.of(context).pushNamed(
          RideConfirmScreen.routeName,
          arguments: RideConfirmArgs(
            pickupLat: pickup.latitude,
            pickupLng: pickup.longitude,
            dropoffLat: drop.latitude,
            dropoffLng: drop.longitude,
            pickupAddress: pickup.address.isNotEmpty
                ? pickup.address
                : pickup.name,
            dropoffAddress:
                drop.address.isNotEmpty ? drop.address : drop.name,
            canBook: widget.canBook,
            initialVehicleId: widget.vehicleType == 'sedan' ||
                    widget.vehicleType == 'economy'
                ? 'economy'
                : widget.vehicleType,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not continue: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_loadingPickup)
            RidealityDraggablePinMap(
              key: _mapKey,
              center: _pickupCenter,
              onCenterSettled: _onPinSettled,
            )
          else
            const ColoredBox(
              color: AppColors.surfaceContainerLow,
              child: Center(child: CircularProgressIndicator()),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerLowest
                              .withValues(alpha: 0.92),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Rides',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_requesting)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Material(
                    color: AppColors.surfaceContainerLowest,
                    elevation: 0,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.ambientShadow,
                        color: AppColors.surfaceContainerLowest,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _EndpointRow(
                            kindLabel: 'Pickup',
                            value: _pickupLabel,
                            leading: _pinIcon(AppColors.secondary),
                            onTap: _openPickupSheet,
                            trailing: _reverseGeocoding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                          ),
                          const Divider(height: 1, indent: 56, endIndent: 16),
                          _EndpointRow(
                            kindLabel: 'Destination',
                            value: _dropoffLabel,
                            leading: _pinIcon(AppColors.accent),
                            onTap: _openDropoffSheet,
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FilledButton(
                      onPressed: _requesting ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _requesting ? 'Requesting…' : 'Continue',
                        style: tt.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinIcon(Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.location_on_rounded, size: 16, color: color),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.kindLabel,
    required this.leading,
    required this.value,
    this.onTap,
    this.trailing,
  });

  final String kindLabel;
  final Widget leading;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kindLabel,
                    style: tt.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullX<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
