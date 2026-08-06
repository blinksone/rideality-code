import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
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
  final _latController = TextEditingController(text: '31.5204');
  final _lngController = TextEditingController(text: '74.3587');
  String _label = 'home';
  bool _loading = false;

  static const _labels = [
    ('home', Icons.home_rounded),
    ('work', Icons.work_rounded),
    ('university', Icons.school_rounded),
    ('custom', Icons.place_rounded),
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
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

  Future<void> _save() async {
    final address = _addressController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (address.isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address and coordinates are required')),
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
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Latitude',
                            controller: _latController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Longitude',
                            controller: _lngController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            required: true,
                          ),
                        ),
                      ],
                    ),
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
