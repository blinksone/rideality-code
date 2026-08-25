import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/trip_models.dart';
import '../../services/realtime_socket_service.dart';
import '../../services/trips_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/rideality_pill.dart';
import '../../widgets/route_canvas.dart';
import '../shared/active_ride_screen.dart';

/// Cargo booking confirm — one continuous panel, shared Rideality controls.
class CargoDetailsScreen extends StatefulWidget {
  const CargoDetailsScreen({
    super.key,
    required this.args,
  });

  static const routeName = '/cargo-details';

  final CargoDetailsArgs args;

  @override
  State<CargoDetailsScreen> createState() => _CargoDetailsScreenState();
}

class CargoDetailsArgs {
  const CargoDetailsArgs({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.canBook = true,
    this.etaMinutes = 14,
  });

  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String pickupAddress;
  final String dropoffAddress;
  final bool canBook;
  final int etaMinutes;
}

enum _CargoSize { xs, small, medium }

class _CargoDetailsScreenState extends State<CargoDetailsScreen> {
  _CargoSize _size = _CargoSize.small;
  bool _loadingHelp = false;
  String _paymentLabel = 'Cash';
  bool _requesting = false;

  int get _baseFare {
    switch (_size) {
      case _CargoSize.xs:
        return 1190;
      case _CargoSize.small:
        return 1679;
      case _CargoSize.medium:
        return 2140;
    }
  }

  int get _listFare {
    switch (_size) {
      case _CargoSize.xs:
        return 1390;
      case _CargoSize.small:
        return 1953;
      case _CargoSize.medium:
        return 2490;
    }
  }

  int get _fare => _baseFare + (_loadingHelp ? 250 : 0);

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
    if (parts.length <= 1) return 'Karachi';
    return parts.sublist(1).join(', ');
  }

  void _showAbout(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              RidealityPill(
                onPressed: () => Navigator.pop(ctx),
                variant: RidealityPillVariant.primary,
                expand: true,
                label: 'Got it',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _bookCargo() async {
    if (_requesting) return;
    if (!widget.args.canBook) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete your profile to book cargo'),
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
        vehicleType: 'cargo',
        bookingType: 'cargo',
        cargoWeightKg: _weightForSize(_size),
        cargoDescription: _sizeDetailCopy(_size),
        cargoSizeTier: _sizeTierKey(_size),
        dropoffProofType: 'otp',
        loadingHelp: _loadingHelp,
      );

      // Dropoff OTP is returned once at create — keep on in-memory trip for rider UI.
      final tripWithOtp = trip;

      await RealtimeSocketService.instance.connectAsRider(rideId: trip.id);
      RealtimeSocketService.instance.joinRide(trip.id);

      if (!mounted) return;
      if (trip.dropoffOtp != null && trip.dropoffOtp!.isNotEmpty) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              title: Text(
                'Recipient code',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share this code with the recipient. The driver will enter it at delivery.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    trip.dropoffOtp!,
                    style: Theme.of(ctx).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ],
            );
          },
        );
      }

      if (!mounted) return;
      await Navigator.of(context).pushNamedAndRemoveUntil(
        ActiveRideScreen.routeName,
        (route) => route.settings.name == '/home' || route.isFirst,
        arguments: ActiveRideArgs(
          tripId: trip.id,
          role: SessionRole.rider,
          initialTrip: tripWithOtp,
        ),
      );
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
          content: Text('Could not book cargo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cyclePayment() {
    setState(() {
      _paymentLabel = _paymentLabel == 'Cash' ? 'Wallet' : 'Cash';
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.onSurface,
          ),
        ),
        title: Text(
          'Cargo Details',
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                // Single connected panel — continuous flow, intentional breaks
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.ambientShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // —— Service identity ————————
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const VehicleGlyph(
                              kind: VehicleGlyphKind.cargo,
                              size: 48,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Cargo',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                          height: 26 / 20,
                                          color: AppColors.onSurface,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _InfoIconButton(
                                        onPressed: () => _showAbout(
                                          'About deliveries',
                                          'Cargo moves larger items with a small truck or pickup. '
                                          'Size sets capacity and fare. You’ll see the final total '
                                          'before booking.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _secondaryLine(a.dropoffAddress).isNotEmpty
                                        ? '${_primaryLine(a.dropoffAddress)} · up to ${_sizeLabelCapacity(_size)}'
                                        : 'Up to ${_sizeLabelCapacity(_size)} · e.g. Suzuki Ravi',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      height: 18 / 13,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _sizeDetailCopy(_size),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 13,
                                      height: 18 / 13,
                                      color: AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const _PanelDivider(),

                      // —— Size (primary weight) —————
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Size',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Affects capacity and fare',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                for (final s in _CargoSize.values) ...[
                                  if (s != _CargoSize.xs)
                                    const SizedBox(width: 10),
                                  Expanded(
                                    child: _SizeOptionTile(
                                      size: s,
                                      selected: _size == s,
                                      onTap: () => setState(() => _size = s),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const _PanelDivider(),

                      // —— Loading help (binary toggle) —
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Loading help',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      _InfoIconButton(
                                        onPressed: () => _showAbout(
                                          'About loaders',
                                          'When loading help is on, the driver can assist with '
                                          'handling your cargo at pickup and drop-off. '
                                          'A small helper fee is added to the fare.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _loadingHelp
                                        ? 'Driver will assist · +Rs 250'
                                        : 'Driver assistance needed?',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      height: 16 / 12,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _loadingHelp,
                              activeThumbColor: AppColors.onAccent,
                              activeTrackColor: AppColors.accent,
                              onChanged: (v) =>
                                  setState(() => _loadingHelp = v),
                            ),
                          ],
                        ),
                      ),

                      const _PanelDivider(),

                      // —— Route (shared marker language)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _RouteEndpoint(
                              isPickup: true,
                              label: 'PICK UP',
                              address: a.pickupAddress,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: SizedBox(
                                height: 18,
                                child: CustomPaint(
                                  painter: _RouteDashPainter(),
                                  size: const Size(2, 18),
                                ),
                              ),
                            ),
                            _RouteEndpoint(
                              isPickup: false,
                              label:
                                  'DROP OFF · ${a.etaMinutes} MIN',
                              address: a.dropoffAddress,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // —— Footer: payment + price + CTA ——————
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(
                top: BorderSide(color: AppColors.outlineVariant, width: 1),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + (bottomInset > 0 ? bottomInset : 4),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RidealityPill(
                      onPressed: _cyclePayment,
                      variant: RidealityPillVariant.ghost,
                      icon: Icons.payments_outlined,
                      label: _paymentLabel,
                      trailing: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    _PriceBlock(fare: _fare, listFare: _listFare),
                  ],
                ),
                const SizedBox(height: 12),
                RidealityPill(
                  onPressed: _requesting ? null : _bookCargo,
                  variant: RidealityPillVariant.primary,
                  expand: true,
                  isLoading: _requesting,
                  label: 'Book Cargo',
                  subtitle: 'Arriving in 5–25 mins',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _sizeLabelCapacity(_CargoSize size) {
    switch (size) {
      case _CargoSize.xs:
        return '150 kg';
      case _CargoSize.small:
        return '300 kg';
      case _CargoSize.medium:
        return '600 kg';
    }
  }

  static double _weightForSize(_CargoSize size) {
    switch (size) {
      case _CargoSize.xs:
        return 50;
      case _CargoSize.small:
        return 150;
      case _CargoSize.medium:
        return 300;
    }
  }

  static String _sizeTierKey(_CargoSize size) {
    switch (size) {
      case _CargoSize.xs:
        return 'xs';
      case _CargoSize.small:
        return 'small';
      case _CargoSize.medium:
        return 'medium';
    }
  }

  static String _sizeDetailCopy(_CargoSize size) {
    switch (size) {
      case _CargoSize.xs:
        return 'Boxes & small furniture · e.g. hatchback boot.';
      case _CargoSize.small:
        return 'Appliances & room moves · e.g. Suzuki Ravi.';
      case _CargoSize.medium:
        return 'Bulk household loads · higher bed capacity.';
    }
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.surfaceContainer,
      indent: 18,
      endIndent: 18,
    );
  }
}

class _InfoIconButton extends StatelessWidget {
  const _InfoIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: const Icon(
        Icons.info_outline_rounded,
        size: 18,
        color: AppColors.onSurfaceVariant,
      ),
      tooltip: 'More info',
    );
  }
}

class _SizeOptionTile extends StatelessWidget {
  const _SizeOptionTile({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final _CargoSize size;
  final bool selected;
  final VoidCallback onTap;

  String get _label {
    switch (size) {
      case _CargoSize.xs:
        return 'XS';
      case _CargoSize.small:
        return 'Small';
      case _CargoSize.medium:
        return 'Medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RidealityPill.radius),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.outlineVariant,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(RidealityPill.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RidealityPill.radius),
          child: SizedBox(
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CargoSizeSilhouette(
                  size: size,
                  color: selected ? AppColors.onAccent : AppColors.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  _label,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: selected ? AppColors.onAccent : AppColors.onSurface,
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

class _CargoSizeSilhouette extends StatelessWidget {
  const _CargoSizeSilhouette({
    required this.size,
    required this.color,
  });

  final _CargoSize size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = switch (size) {
      _CargoSize.xs => 0.55,
      _CargoSize.small => 0.75,
      _CargoSize.medium => 1.0,
    };
    return SizedBox(
      width: 36,
      height: 28,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: scale,
          heightFactor: scale * 0.85 + 0.15,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1.8),
              color: color.withValues(alpha: 0.14),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteEndpoint extends StatelessWidget {
  const _RouteEndpoint({
    required this.isPickup,
    required this.label,
    required this.address,
  });

  final bool isPickup;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
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
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 14 / 11,
                  letterSpacing: 0.4,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 18 / 14,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentMuted.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 3.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(1, y), Offset(1, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.fare,
    required this.listFare,
  });

  final int fare;
  final int listFare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Rs ',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              '$fare',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                height: 1,
                letterSpacing: -0.6,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        if (listFare > fare) ...[
          const SizedBox(height: 2),
          Text(
            'Rs $listFare',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              height: 16 / 13,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
              decoration: TextDecoration.lineThrough,
              decorationColor:
                  AppColors.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}
