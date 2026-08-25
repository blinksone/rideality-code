import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../services/auth_api_service.dart';
import '../../services/driver_location_tracker.dart';
import '../../services/fleet_api_service.dart';
import '../../services/onboarding_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'vehicle_details_screen.dart';
import 'fleet_companies_in_city_screen.dart';
import 'fleet_company_detail_screen.dart';

class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key, this.countryRegionId});

  static const routeName = '/become-driver';

  /// Country id from GET /auth/regions (Pakistan), not a fleet city.
  final String? countryRegionId;

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dob;
  bool _loading = false;
  bool _acceptTerms = true;

  /// Country region id from phone/OTP (not shown — already chosen earlier).
  String? _regionId;
  bool _loadingDirectory = true;

  // Geo city (after region from phone screen)
  List<GeoCityOption> _cities = const [];
  GeoCityOption? _city;
  bool _loadingCities = false;

  FleetCompanyOption? _company;
  bool _openingCompanies = false;

  String? _directoryError;

  FleetDriverInvite? _invite;
  bool _inviteLocked = false;

  static const _labels = ['Phone', 'OTP', 'Identity', 'Vehicle', 'Docs'];

  @override
  void initState() {
    super.initState();
    _prefillName();
    _bootstrap();
  }

  Future<void> _prefillName() async {
    try {
      final me = await UserApiService.instance.getMe();
      if (!mounted) return;
      if (me.fullName != null && me.fullName!.isNotEmpty) {
        _nameController.text = me.fullName!;
      }
      if (me.email != null && me.email!.isNotEmpty) {
        _emailController.text = me.email!;
      }
    } catch (_) {}
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingDirectory = true;
      _directoryError = null;
    });
    try {
      // Country already chosen on phone/OTP — resolve id, then load cities.
      var countryId = widget.countryRegionId ??
          await TokenStorage.instance.countryRegionId;

      FleetDriverInvite? invite;
      try {
        final invites = await FleetApiService.instance.listMyInvites();
        invite = invites.isNotEmpty ? invites.first : null;
      } catch (_) {}

      if (invite?.countryRegionId != null &&
          invite!.countryRegionId!.isNotEmpty) {
        countryId = invite.countryRegionId;
      }

      if (countryId == null || countryId.isEmpty) {
        final regions = await AuthApiService.instance.listRegions();
        final code = await TokenStorage.instance.regionCode;
        Region? match;
        if (code != null && code.isNotEmpty) {
          for (final r in regions) {
            if (r.code.toUpperCase() == code.toUpperCase()) {
              match = r;
              break;
            }
          }
        }
        match ??= regions.where((r) => r.code == 'PK').firstOrNull ??
            (regions.isNotEmpty ? regions.first : null);
        countryId = match?.id;
      }

      if (countryId == null || countryId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _directoryError = 'Could not resolve your country. Go back and select it on the phone screen.';
          _loadingDirectory = false;
        });
        return;
      }

      setState(() {
        _regionId = countryId;
        _invite = invite;
        _inviteLocked = invite != null &&
            invite.companyId != null &&
            invite.fleetCityId != null;
        _loadingCities = true;
      });

      final cities = await FleetApiService.instance.listCities(
        regionId: countryId,
      );
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
        _loadingDirectory = false;
      });

      if (_inviteLocked &&
          invite != null &&
          invite.companyId != null &&
          invite.fleetCityId != null) {
        final inviteCityId = invite.fleetCityId;
        final cityMatch =
            cities.where((c) => c.id == inviteCityId).firstOrNull;
        if (cityMatch != null) {
          final company = await FleetApiService.instance.getCompanyPublic(
            companyId: invite.companyId!,
            cityId: cityMatch.id,
          );
          if (!mounted) return;
          setState(() {
            _city = cityMatch;
            _company = company;
          });
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _directoryError = e.message;
        _loadingDirectory = false;
        _loadingCities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _directoryError = 'Could not load cities for your country.';
        _loadingDirectory = false;
        _loadingCities = false;
      });
    }
  }

  void _onCityChanged(GeoCityOption? city) {
    setState(() {
      _city = city;
      _company = null;
    });
    if (city == null || _inviteLocked) return;
    // Move the user to the dedicated "companies in this city" step.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_openingCompanies) return;
      await _pickCompanyForCityInternal();
    });
  }

  bool get _canJoin =>
      _nameController.text.trim().length >= 2 &&
      _dob != null &&
      _isAdult(_dob!) &&
      _acceptTerms;

  void _pickCompanyForCity() {
    _pickCompanyForCityInternal();
  }

  Future<void> _pickCompanyForCityInternal() async {
    final city = _city;
    if (city == null || _inviteLocked) return;
    if (_openingCompanies) return;

    _openingCompanies = true;
    try {
      final result = await Navigator.of(context).push<
          FleetCompanySelectionResult>(
        MaterialPageRoute(
          builder: (_) => FleetCompaniesInCityScreen(
            cityId: city.id,
            joinEnabled: _canJoin,
            cityLabel: city.name,
          ),
        ),
      );

      if (!mounted) return;
      if (result != null) {
        setState(() => _company = result.company);
        if (result.joinNow) {
          // Re-run the normal continue flow (POST /onboarding/driver).
          await _continue();
        }
      }
    } finally {
      _openingCompanies = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isAdult(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth (must be 18+)',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  bool get _canContinue =>
      _regionId != null &&
      _city != null &&
      _company != null &&
      _nameController.text.trim().length >= 2 &&
      _dob != null &&
      _isAdult(_dob!) &&
      _acceptTerms;

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _toast('Full name is required');
      return;
    }
    if (_dob == null || !_isAdult(_dob!)) {
      _toast('Date of birth is required (18+)');
      return;
    }
    if (_regionId == null) {
      _toast('Country is missing. Go back and select it on the phone screen.');
      return;
    }
    if (_city == null) {
      _toast('Select your city');
      return;
    }
    if (_company == null) {
      _toast('Select your fleet company');
      return;
    }
    if (_company!.fleetRegionId == null || _company!.fleetRegionId!.isEmpty) {
      _toast('This company has no fleet region assigned. Try another.');
      return;
    }
    if (!_acceptTerms) {
      _toast('Please accept Terms & Privacy to continue');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_invite != null && _invite!.token.isNotEmpty) {
        try {
          await FleetApiService.instance.acceptInvite(_invite!.token);
        } on ApiException catch (e) {
          final m = e.message.toLowerCase();
          if (!m.contains('already') && e.statusCode != 409) rethrow;
        }
      }

      SavedLocationInput? location;
      try {
        final pos = await DriverLocationTracker.instance.currentPosition();
        if (pos != null) {
          location = SavedLocationInput(
            label: 'home',
            address: _city!.name,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
        }
      } catch (_) {}
      location ??= SavedLocationInput(
        label: 'home',
        address: _city!.name,
        latitude: 0,
        longitude: 0,
      );

      await OnboardingApiService.instance.completeDriver(
        fullName: name,
        dateOfBirth: _fmt(_dob!),
        companyId: _company!.id,
        fleetRegionId: _company!.fleetRegionId!,
        email: _emailController.text.trim(),
        profession: 'driver',
        acceptTerms: true,
        acceptPrivacy: true,
        location: location,
      );
      await DashboardPrefs.instance.saveFleetAssignment(
        companyId: _company!.id,
        companyName: _company!.legalName,
        cityId: _city!.id,
        cityName: _city!.name,
      );
      // Onboarding is now actually completed on backend; no need to keep
      // the persisted "driver intent" for cold-start routing.
      await TokenStorage.instance.setPendingOnboardingIntent(null);
      if (!mounted) return;
      Navigator.of(context).pushNamed(VehicleDetailsScreen.routeName);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered as fleet staff') ||
          msg.contains('staff')) {
        _toast('This phone is already registered as fleet staff');
      } else {
        _toast(e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

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
                    const ProgressStepper(
                      currentStep: 3,
                      totalSteps: 5,
                      labels: _labels,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Driver identity',
                      style: tt.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join a city fleet. Your city team reviews documents before you can go online.',
                      style: tt.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (_invite != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.mail_outline_rounded,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Invited to ${_invite!.companyName ?? 'a fleet'}'
                                '${_invite!.fleetCityName != null ? ' · ${_invite!.fleetCityName}' : ''}. '
                                'Company and city are set for you.',
                                style: tt.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.apartment_rounded,
                                color: AppColors.secondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Select your city, then pick a fleet company.',
                                style: tt.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_loadingDirectory)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_directoryError != null)
                      Column(
                        children: [
                          Text(
                            _directoryError!,
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          TextButton(
                            onPressed: _bootstrap,
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    else ...[
                      // City (country already set on phone/OTP)
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          prefixIcon: Icon(Icons.location_city_rounded),
                        ),
                        child: _loadingCities
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<GeoCityOption>(
                                  isExpanded: true,
                                  isDense: true,
                                  value: _city,
                                  hint: const Text('Select city'),
                                  items: _cities
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _inviteLocked
                                      ? null
                                      : (v) => _onCityChanged(v),
                                ),
                              ),
                      ),
                      if (!_loadingCities && _cities.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'No fleets in this city yet',
                          style: tt.labelSmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Company (select via dedicated screen)
                      if (_city == null)
                        const SizedBox.shrink()
                      else if (_company != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.business_rounded,
                                  color: AppColors.secondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _company!.legalName,
                                      style: tt.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _RatingStars(avg: _company!.ratingAvg ?? 0),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(_company!.ratingAvg ?? 0).toStringAsFixed(1)} • ${_company!.ratingCount ?? 0}',
                                          style: tt.bodySmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_company!.driverCount ?? 0} drivers',
                                      style: tt.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (!_inviteLocked)
                                TextButton(
                                  onPressed: _pickCompanyForCity,
                                  child: const Text('Change'),
                                ),
                            ],
                          ),
                        )
                      else
                        AppButton(
                          label: 'Select fleet company',
                          icon: Icons.search_rounded,
                          onPressed: _pickCompanyForCity,
                          isLoading: false,
                          variant: AppButtonVariant.secondary,
                        ),
                    ],
                    const SizedBox(height: 24),
                    AppTextField(
                      label: 'Full name',
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      prefixIcon: Icons.person_outline_rounded,
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of birth *',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          _dob == null ? 'Select date (18+)' : _fmt(_dob!),
                          style: tt.bodyLarge?.copyWith(
                            color: _dob == null
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Email (optional)',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _acceptTerms,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.secondary,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text(
                        'I accept Terms of Service & Privacy Policy',
                        style: tt.labelLarge,
                      ),
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: AppButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                isLoading: _loading,
                onPressed: _canContinue ? _continue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.avg});

  final double avg;

  @override
  Widget build(BuildContext context) {
    final rounded = avg.clamp(0, 5).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rounded;
        return Icon(
          filled ? Icons.star : Icons.star_border_rounded,
          size: 16,
          color: filled ? AppColors.success : AppColors.onSurfaceVariant,
        );
      }),
    );
  }
}
