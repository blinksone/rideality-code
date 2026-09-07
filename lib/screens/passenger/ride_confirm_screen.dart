import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/storage/active_trip_store.dart';
import '../../core/storage/token_storage.dart';
import '../../core/vehicle_catalog.dart';
import '../../models/trip_models.dart';
import '../../services/realtime_socket_service.dart';
import '../../services/trips_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/rideality_pill.dart';
import '../../widgets/rideality_trip_map.dart';
import '../../widgets/route_canvas.dart';
import '../shared/active_ride_screen.dart';
import 'passenger_dashboard_screen.dart';

/// Ride options + confirm — fares from POST /trips/quote.
class RideConfirmScreen extends StatefulWidget {
  const RideConfirmScreen({
    super.key,
    required this.args,
  });

  static const routeName = '/ride-confirm';

  final RideConfirmArgs args;

  @override
  State<RideConfirmScreen> createState() => _RideConfirmScreenState();
}

class RideConfirmArgs {
  const RideConfirmArgs({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.canBook = true,
    this.initialVehicleId = 'economy',
  });

  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String pickupAddress;
  final String dropoffAddress;
  final bool canBook;
  final String initialVehicleId;
}

class _RideConfirmScreenState extends State<RideConfirmScreen> {
  static const _tabs = ['Transport', 'Taxi', 'Delivery'];
  static const _supplyPollInterval = Duration(seconds: 5);

  int _tabIndex = 1; // Taxi
  String? _selectedVehicleType;
  String _paymentLabel = 'Wallet';
  bool _requesting = false;
  bool _quoteLoading = true;
  String? _quoteError;
  TripQuote? _quote;
  List<LatLng> _routePoints = const [];
  List<NearbySupplyPin> _supplyPins = const [];
  Timer? _supplyPollTimer;
  String? _cityId;
  bool _supplyPollInFlight = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicleType =
        VehicleCatalog.normalize(widget.args.initialVehicleId);
    unawaited(_loadWalletLabel());
    unawaited(_resolveCityId());
    unawaited(_loadQuote());
    unawaited(_loadRoute());
    _startSupplyPolling();
  }

  @override
  void dispose() {
    _supplyPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveCityId() async {
    final id = await DashboardPrefs.instance.fleetCityId;
    if (!mounted) return;
    _cityId = id;
  }

  String get _selectedProduct =>
      VehicleCatalog.normalize(_selectedVehicleType);

  void _startSupplyPolling() {
    _supplyPollTimer?.cancel();
    unawaited(_pollNearbySupply());
    _supplyPollTimer = Timer.periodic(
      _supplyPollInterval,
      (_) => unawaited(_pollNearbySupply()),
    );
  }

  Future<void> _pollNearbySupply() async {
    if (_supplyPollInFlight || !mounted) return;
    _supplyPollInFlight = true;
    final a = widget.args;
    try {
      final pins = await TripsApiService.instance.getNearbySupply(
        latitude: a.pickupLat,
        longitude: a.pickupLng,
        product: _selectedProduct,
        cityId: _cityId,
      );
      if (!mounted) return;
      setState(() => _supplyPins = pins);
    } catch (_) {
      // Soft-fail: empty pins is normal; quote still works.
    } finally {
      _supplyPollInFlight = false;
    }
  }

  String? get _liveBookingType {
    return switch (_tabIndex) {
      1 => 'ride',
      2 => 'cargo',
      _ => null,
    };
  }

  List<TripQuoteOption> get _options => _quote?.options ?? const [];

  TripQuoteOption? get _selected {
    final id = _selectedVehicleType;
    if (id == null) return null;
    for (final o in _options) {
      if (o.vehicleType == id) return o;
    }
    return _options.where((o) => o.available).firstOrNull;
  }

  Future<void> _loadWalletLabel() async {
    try {
      final wallet = await UserApiService.instance.getWallet();
      if (!mounted) return;
      if (wallet.balance > 0) {
        setState(() => _paymentLabel = 'Wallet');
      }
    } catch (_) {
      // Payment chip is cosmetic until checkout supports cash.
    }
  }

  List<LatLng> _pointsFromQuote(TripQuote quote) {
    if (quote.routePoints.length >= 2) {
      return quote.routePoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    }
    final encoded = quote.polyline;
    if (encoded != null && encoded.isNotEmpty) {
      return decodePolyline(encoded)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    }
    return const [];
  }

  List<LatLng> _straightFallbackRoute() {
    final a = widget.args;
    return [
      LatLng(a.pickupLat, a.pickupLng),
      LatLng(a.dropoffLat, a.dropoffLng),
    ];
  }

  Future<void> _loadRoute() async {
    final a = widget.args;
    try {
      final route = await TripsApiService.instance.getRoute(
        pickupLat: a.pickupLat,
        pickupLng: a.pickupLng,
        dropoffLat: a.dropoffLat,
        dropoffLng: a.dropoffLng,
      );
      if (!mounted) return;

      List<LatLng> points = const [];
      if (route.points.length >= 2) {
        points = route.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      } else if (route.encodedPolyline != null &&
          route.encodedPolyline!.isNotEmpty) {
        points = decodePolyline(route.encodedPolyline!)
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      }

      setState(() {
        _routePoints = points.length >= 2 ? points : _straightFallbackRoute();
      });
    } catch (_) {
      if (!mounted) return;
      if (_routePoints.length < 2) {
        setState(() => _routePoints = _straightFallbackRoute());
      }
    }
  }

  Future<void> _loadQuote() async {
    final bookingType = _liveBookingType;
    if (bookingType == null) {
      setState(() {
        _quoteLoading = false;
        _quoteError = null;
        _quote = null;
      });
      return;
    }

    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });

    final a = widget.args;
    try {
      final quote = await TripsApiService.instance.quoteTrip(
        pickupLat: a.pickupLat,
        pickupLng: a.pickupLng,
        dropoffLat: a.dropoffLat,
        dropoffLng: a.dropoffLng,
        pickupAddress: a.pickupAddress,
        dropoffAddress: a.dropoffAddress,
        bookingType: bookingType,
      );
      if (!mounted) return;
      final fromQuote = _pointsFromQuote(quote);
      setState(() {
        _quote = quote;
        _quoteLoading = false;
        _selectedVehicleType = _pickDefaultVehicle(quote.options);
        if (fromQuote.length >= 2) {
          _routePoints = fromQuote;
        }
      });
      if (fromQuote.length < 2) {
        unawaited(_loadRoute());
      }
      unawaited(_pollNearbySupply());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteLoading = false;
        _quoteError = e.message;
        _quote = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteLoading = false;
        _quoteError = e.toString();
        _quote = null;
      });
    }
  }

  String? _pickDefaultVehicle(List<TripQuoteOption> options) {
    final available = options.where((o) => o.available).toList();
    if (available.isEmpty) return null;

    final preferred = VehicleCatalog.normalize(widget.args.initialVehicleId);
    if (available.any((o) =>
        VehicleCatalog.normalize(o.vehicleType) == preferred)) {
      return available
          .firstWhere(
            (o) => VehicleCatalog.normalize(o.vehicleType) == preferred,
          )
          .vehicleType;
    }
    if (_selectedVehicleType != null &&
        available.any((o) =>
            VehicleCatalog.normalize(o.vehicleType) ==
            VehicleCatalog.normalize(_selectedVehicleType))) {
      return available
          .firstWhere(
            (o) =>
                VehicleCatalog.normalize(o.vehicleType) ==
                VehicleCatalog.normalize(_selectedVehicleType),
          )
          .vehicleType;
    }

    for (final o in available) {
      if ((o.badge ?? '').toLowerCase() == 'fastest') return o.vehicleType;
    }
    return available.first.vehicleType;
  }

  void _onTabChanged(int index) {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
    unawaited(_loadQuote());
  }

  String _primaryLine(String address) {
    final parts = address
        .split(RegExp(r'[,·|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return address;
    return parts.first;
  }

  String _secondaryLine(String address) {
    final parts = address
        .split(RegExp(r'[,·|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length <= 1) return 'Pickup / drop-off';
    return parts.sublist(1).join(', ');
  }

  VehicleGlyphKind _glyphFor(String vehicleType) {
    return switch (vehicleType.toLowerCase()) {
      'bike' => VehicleGlyphKind.bike,
      'rickshaw' => VehicleGlyphKind.rickshaw,
      'cargo' => VehicleGlyphKind.cargo,
      _ => VehicleGlyphKind.economy,
    };
  }

  Future<void> _requestRide() async {
    if (_requesting) return;
    if (!widget.args.canBook) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete your profile to book rides'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_liveBookingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_tabs[_tabIndex]} bookings are coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = _selected;
    if (selected == null || !selected.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an available ride option'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _requesting = true);
    final a = widget.args;
    try {
      await DashboardPrefs.instance.setLastDestination(a.dropoffAddress);

      final trip = await TripsApiService.instance.createTrip(
        pickupLat: a.pickupLat,
        pickupLng: a.pickupLng,
        dropoffLat: a.dropoffLat,
        dropoffLng: a.dropoffLng,
        pickupAddress: a.pickupAddress,
        dropoffAddress: a.dropoffAddress,
        vehicleType: selected.vehicleType,
        bookingType: _liveBookingType,
      );

      await RealtimeSocketService.instance.connectAsRider(rideId: trip.id);
      RealtimeSocketService.instance.joinRide(trip.id);
      await ActiveTripStore.instance.save(
        rideId: trip.id,
        role: SessionRole.rider,
        vehicleType: selected.vehicleType,
      );

      if (!mounted) return;
      // Remount home so the active-ride banner appears after minimize.
      Navigator.of(context).pushNamedAndRemoveUntil(
        PassengerDashboardScreen.routeName,
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNavigator.key.currentState?.pushNamed(
          ActiveRideScreen.routeName,
          arguments: ActiveRideArgs(
            tripId: trip.id,
            role: SessionRole.rider,
            initialTrip: trip,
          ),
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start trip: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cyclePayment() {
    setState(() {
      _paymentLabel = _paymentLabel == 'Wallet' ? 'Cash' : 'Wallet';
    });
  }

  Widget _buildOptionsList() {
    if (_liveBookingType == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 36,
              color: AppColors.accent.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              '${_tabs[_tabIndex]} options soon',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Switch to Taxi to request a ride now.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_quoteLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_quoteError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              _quoteError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadQuote, child: const Text('Retry quote')),
          ],
        ),
      );
    }

    if (_options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No ride options for this route',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: _options.map((o) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _VehicleCard(
            option: o,
            glyph: _glyphFor(o.vehicleType),
            selected: o.vehicleType == _selectedVehicleType,
            onTap: o.available
                ? () {
                    setState(() => _selectedVehicleType = o.vehicleType);
                    unawaited(_pollNearbySupply());
                  }
                : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final selected = _selected;
    final mapEta = _quote?.durationMin ?? selected?.etaMin ?? 6;

    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: Column(
        children: [
          Expanded(
            flex: 42,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RidealityTripMap(
                  pickup: LatLng(a.pickupLat, a.pickupLng),
                  dropoff: LatLng(a.dropoffLat, a.dropoffLng),
                  routePoints: _routePoints,
                  supplyPins: _supplyPins,
                  showEmptySupplyBanner: true,
                  etaMinutes: mapEta,
                  showBack: true,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 58,
            child: Material(
              color: AppColors.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        _TripSummaryCard(
                          pickupPrimary: _primaryLine(a.pickupAddress),
                          pickupSecondary: _secondaryLine(a.pickupAddress),
                          dropoffPrimary: _primaryLine(a.dropoffAddress),
                          dropoffSecondary: _secondaryLine(a.dropoffAddress),
                          onStops: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Multi-stop is coming soon'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _CategoryTabs(
                          tabs: _tabs,
                          index: _tabIndex,
                          onChanged: _onTabChanged,
                        ),
                        const SizedBox(height: 14),
                        _buildOptionsList(),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        12 + (bottomInset > 0 ? 0 : 4),
                      ),
                      child: Row(
                        children: [
                          RidealityPill(
                            onPressed: _cyclePayment,
                            variant: RidealityPillVariant.ghost,
                            icon: Icons.account_balance_wallet_outlined,
                            label: _paymentLabel,
                            trailing: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RidealityPill(
                              onPressed: (_requesting ||
                                      _quoteLoading ||
                                      selected == null ||
                                      !selected.available)
                                  ? null
                                  : _requestRide,
                              variant: RidealityPillVariant.primary,
                              expand: true,
                              isLoading: _requesting,
                              label: selected == null
                                  ? 'Request ride'
                                  : 'Request ${selected.label}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          RidealityPill(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Filters coming soon'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            variant: RidealityPillVariant.ghost,
                            icon: Icons.tune_rounded,
                          ),
                        ],
                      ),
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

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({
    required this.pickupPrimary,
    required this.pickupSecondary,
    required this.dropoffPrimary,
    required this.dropoffSecondary,
    required this.onStops,
  });

  final String pickupPrimary;
  final String pickupSecondary;
  final String dropoffPrimary;
  final String dropoffSecondary;
  final VoidCallback onStops;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _EndpointRow(
            isPickup: true,
            primary: pickupPrimary,
            secondary: pickupSecondary,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 14,
                color: AppColors.outlineVariant,
              ),
            ),
          ),
          _EndpointRow(
            isPickup: false,
            primary: dropoffPrimary,
            secondary: dropoffSecondary,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: RidealityChip(
              label: 'Stops',
              icon: Icons.add_rounded,
              onTap: onStops,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.isPickup,
    required this.primary,
    required this.secondary,
  });

  final bool isPickup;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: isPickup
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                )
              : const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 20 / 15,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 16 / 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final selected = i == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 8),
            child: Material(
              color: selected ? AppColors.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(RidealityPill.radius),
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(RidealityPill.radius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(RidealityPill.radius),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.35)
                          : AppColors.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: selected
                            ? AppColors.accent
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.option,
    required this.glyph,
    required this.selected,
    this.onTap,
  });

  final TripQuoteOption option;
  final VehicleGlyphKind glyph;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !option.available;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected && !disabled
                    ? AppColors.accent
                    : AppColors.outlineVariant,
                width: selected && !disabled ? 1.8 : 1,
              ),
              boxShadow: selected && !disabled
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: VehicleGlyph(
                      kind: glyph,
                      size: 34,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.etaLabel,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              option.label,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          if (option.badge != null &&
                              option.badge!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            RidealityChip(
                              label: option.badge!,
                              selected: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  option.fareLabel,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
