import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../services/driver_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'documents_upload_screen.dart';

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key, this.fromDashboard = false});

  static const routeName = '/vehicle-details';

  final bool fromDashboard;

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController(text: '2022');
  final _seatsController = TextEditingController(text: '4');
  String _vehicleType = 'sedan';
  bool _loading = false;

  static const _labels = ['Phone', 'OTP', 'Identity', 'Vehicle', 'Docs'];

  static const _types = [
    ('sedan', 'Sedan', Icons.directions_car_rounded),
    ('suv', 'SUV', Icons.airport_shuttle_rounded),
    ('lux', 'Luxury', Icons.diamond_outlined),
  ];

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_modelController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model and number plate are required')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await DriverApiService.instance.registerVehicle(
        vehicleType: _vehicleType,
        model: _modelController.text.trim(),
        numberPlate: _plateController.text.trim().toUpperCase(),
        color: _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        availableSeats: int.tryParse(_seatsController.text.trim()) ?? 4,
      );
      if (!mounted) return;
      if (widget.fromDashboard) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle saved')),
        );
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushNamed(DocumentsUploadScreen.routeName);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ThemeData _tintedFieldTheme(BuildContext context) {
    final base = Theme.of(context);
    final soft = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AppColors.surfaceTint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: soft,
        enabledBorder: soft,
        focusedBorder: soft,
        errorBorder: soft.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: soft.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),
    );
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
              child: Theme(
                data: _tintedFieldTheme(context),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!widget.fromDashboard)
                        const ProgressStepper(
                          currentStep: 4,
                          totalSteps: 5,
                          labels: _labels,
                        ),
                      if (!widget.fromDashboard) const SizedBox(height: 28),
                      Text(
                        widget.fromDashboard
                            ? 'Update vehicle'
                            : 'Your vehicle',
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Exact details help passengers find you at the curb.',
                        style: tt.bodyMedium?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      Text('Type', style: tt.labelLarge),
                      const SizedBox(height: 10),
                      Row(
                        children: _types.map((t) {
                          final selected = _vehicleType == t.$1;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: t.$1 == 'lux' ? 0 : 8),
                              child: Material(
                                color: selected
                                    ? AppColors.secondary
                                    : AppColors.surfaceTint,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _vehicleType = t.$1),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    child: Column(
                                      children: [
                                        Icon(
                                          t.$3,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.secondary,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          t.$2,
                                          style: tt.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? Colors.white
                                                : AppColors.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: 'Model',
                        controller: _modelController,
                        prefixIcon: Icons.directions_car_outlined,
                        required: true,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _plateController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9\-]'),
                          ),
                          LengthLimitingTextInputFormatter(12),
                          _UpperCaseFormatter(),
                        ],
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Number plate *',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Color',
                              controller: _colorController,
                              prefixIcon: Icons.palette_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: 'Year',
                              controller: _yearController,
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.calendar_today_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Available seats',
                        controller: _seatsController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.event_seat_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: AppButton(
                label: 'Save vehicle',
                icon: Icons.arrow_forward_rounded,
                isLoading: _loading,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
