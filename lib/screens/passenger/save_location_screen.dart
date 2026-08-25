import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../services/driver_location_tracker.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'passenger_dashboard_screen.dart';

class SaveLocationScreen extends StatefulWidget {
  const SaveLocationScreen({super.key, this.fromDashboard = false});

  static const routeName = '/save-location';

  final bool fromDashboard;

  @override
  State<SaveLocationScreen> createState() => _SaveLocationScreenState();
}

class _SaveLocationScreenState extends State<SaveLocationScreen> {
  final _addressController = TextEditingController();
  String _label = 'home';
  bool _loading = false;
  bool _locating = false;
  double? _lat;
  double? _lng;

  static const _labels = [
    ('home', Icons.home_rounded),
    ('work', Icons.work_rounded),
    ('university', Icons.school_rounded),
    ('custom', Icons.place_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation(silent: true);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _goHome() {
    if (widget.fromDashboard) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      PassengerDashboardScreen.routeName,
      (route) => false,
    );
  }

  Future<void> _fetchCurrentLocation({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final pos = await DriverLocationTracker.instance.currentPosition();
      if (!mounted) return;
      if (pos == null) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turn on location and allow access to save this place.'),
            ),
          );
        }
        return;
      }
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_addressController.text.trim().isEmpty) {
          _addressController.text =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        }
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final address = _addressController.text.trim();
    final lat = _lat;
    final lng = _lng;

    if (address.isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an address and tap Use current location'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await UserApiService.instance.saveLocations(
        label: _label,
        address: address,
        latitude: lat,
        longitude: lng,
        isDefault: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place saved')),
      );
      _goHome();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skip() => _goHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RidealityAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.fromDashboard) ...[
                      const ProgressStepper(
                        currentStep: 4,
                        totalSteps: 4,
                        labels: ['Phone', 'OTP', 'Profile', 'Place'],
                      ),
                      const SizedBox(height: 28),
                    ] else
                      const SizedBox(height: 8),
                    Text(
                      widget.fromDashboard
                          ? 'Add a saved place'
                          : 'Save a frequent place',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add home or work to book faster.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _labels.map((item) {
                        final selected = _label == item.$1;
                        return ChoiceChip(
                          avatar: Icon(
                            item.$2,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : AppColors.secondary,
                          ),
                          label: Text(item.$1),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _label = item.$1),
                          selectedColor: AppColors.secondary,
                          labelStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                          backgroundColor: AppColors.surfaceContainerLow,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Address',
                      controller: _addressController,
                      required: true,
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: _lat == null
                          ? 'Use current location'
                          : 'Update current location',
                      icon: Icons.my_location_rounded,
                      variant: AppButtonVariant.secondary,
                      isLoading: _locating,
                      borderRadius: 14,
                      onPressed: _locating ? null : _fetchCurrentLocation,
                    ),
                    if (_lat != null && _lng != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Location set · ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Column(
                children: [
                  AppButton(
                    label: 'Save place',
                    icon: Icons.check_rounded,
                    isLoading: _loading,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: widget.fromDashboard ? 'Cancel' : 'Skip for now',
                    variant: AppButtonVariant.ghost,
                    borderRadius: 14,
                    onPressed: _skip,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
