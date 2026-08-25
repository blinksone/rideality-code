import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../models/trip_models.dart';
import '../../services/image_picker_service.dart';
import '../../services/trips_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/rideality_pill.dart';

enum CargoProofStage { pickup, dropoff }

/// Cargo proof capture before PICKED_UP (pickup) or COMPLETED (dropoff).
class CargoProofScreen extends StatefulWidget {
  const CargoProofScreen({
    super.key,
    required this.args,
  });

  static const routeName = '/cargo-proof';

  final CargoProofArgs args;

  @override
  State<CargoProofScreen> createState() => _CargoProofScreenState();
}

class CargoProofArgs {
  const CargoProofArgs({
    required this.bookingId,
    required this.stage,
    this.confirmationType = CargoProofKind.photo,
    this.title,
    this.subtitle,
  });

  final String bookingId;
  final CargoProofStage stage;
  final CargoProofKind confirmationType;
  final String? title;
  final String? subtitle;
}

class _CargoProofScreenState extends State<CargoProofScreen> {
  final _otpKey = GlobalKey<OtpInputState>();
  String? _photoPath;
  String? _photoUrl;
  String _otp = '';
  bool _busy = false;
  String? _error;

  bool get _isPickup => widget.args.stage == CargoProofStage.pickup;

  CargoProofKind get _kind {
    // Pickup defaults to photo; dropoff uses booking config (often OTP).
    if (_isPickup) {
      return widget.args.confirmationType == CargoProofKind.otp
          ? CargoProofKind.otp
          : widget.args.confirmationType == CargoProofKind.both
              ? CargoProofKind.both
              : CargoProofKind.photo;
    }
    return widget.args.confirmationType;
  }

  bool get _needsPhoto =>
      _kind == CargoProofKind.photo || _kind == CargoProofKind.both;

  bool get _needsOtp =>
      _kind == CargoProofKind.otp || _kind == CargoProofKind.both;

  bool get _canSubmit {
    if (_busy) return false;
    if (_needsPhoto &&
        (_photoPath == null || _photoPath!.isEmpty) &&
        (_photoUrl == null || _photoUrl!.isEmpty)) {
      return false;
    }
    if (_needsOtp && _otp.length < 4) return false;
    return true;
  }

  String get _blockReason {
    if (_needsPhoto && _photoPath == null && _photoUrl == null) {
      return 'Take a photo to continue';
    }
    if (_needsOtp && _otp.length < 4) {
      return 'Enter the confirmation code to continue';
    }
    return '';
  }

  Future<void> _capturePhoto() async {
    setState(() => _error = null);
    final picked = await ImagePickerService.instance.pickFromCamera();
    if (picked == null || !mounted) return;
    setState(() => _photoPath = picked.file.path);
  }

  Future<String?> _ensurePhotoUrl() async {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) return _photoUrl;
    final path = _photoPath;
    if (path == null || path.isEmpty) return null;
    final url = await UserApiService.instance.uploadPhoto(path);
    if (url.isEmpty) return null;
    _photoUrl = url;
    return url;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? photoUrl;
      if (_needsPhoto) {
        photoUrl = await _ensurePhotoUrl();
        if (photoUrl == null || photoUrl.isEmpty) {
          throw ApiException(
            'Could not upload proof photo. Try again.',
            statusCode: 0,
          );
        }
      }

      final otp = _needsOtp ? _otp : null;
      final Trip updated;
      if (_isPickup) {
        updated = await TripsApiService.instance.submitPickupProof(
          widget.args.bookingId,
          photoUrl: photoUrl,
          otp: otp,
        );
      } else {
        updated = await TripsApiService.instance.submitDropoffProof(
          widget.args.bookingId,
          photoUrl: photoUrl,
          otp: otp,
        );
      }

      // Advance only if proof didn't already move the FSM (idempotent).
      Trip result = updated;
      final desired =
          _isPickup ? TripStatus.pickedUp : TripStatus.completed;
      if (result.status != desired && result.status != TripStatus.completed) {
        try {
          result = await TripsApiService.instance.updateStatus(
            widget.args.bookingId,
            desired,
          );
        } on ApiException catch (e) {
          final code = (e.code ?? '').toUpperCase();
          // Already advanced / concurrent client — refresh authoritative state.
          if (e.statusCode == 409 ||
              code.contains('ALREADY') ||
              code.contains('INVALID_TRANSITION') ||
              code.contains('INVALID_STATUS')) {
            result = await TripsApiService.instance.getTrip(
              widget.args.bookingId,
            );
          } else {
            rethrow;
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final title = widget.args.title ??
        (_isPickup ? 'Confirm pickup' : 'Confirm delivery');
    final subtitle = widget.args.subtitle ??
        (_isPickup
            ? 'Photograph the package before starting transit.'
            : 'Verify with the recipient before completing.');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          title,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_needsPhoto) ...[
                    Text(
                      'Package photo',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Material(
                        color: AppColors.surfaceContainerLow,
                        borderRadius:
                            BorderRadius.circular(RidealityPill.radius),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _busy ? null : _capturePhoto,
                          child: _photoPath == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_camera_outlined,
                                      size: 40,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Tap to open camera',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      File(_photoPath!),
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      right: 10,
                                      bottom: 10,
                                      child: Material(
                                        color: AppColors.surfaceContainerLowest
                                            .withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          onTap: _busy ? null : _capturePhoto,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.refresh_rounded,
                                                    size: 18),
                                                SizedBox(width: 6),
                                                Text('Retake'),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (_needsOtp) ...[
                    Text(
                      _isPickup ? 'Sender code' : 'Recipient code',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ask the ${_isPickup ? 'sender' : 'recipient'} for the 4–6 digit code.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OtpInput(
                      key: _otpKey,
                      length: 6,
                      onChanged: (v) => setState(() => _otp = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: GoogleFonts.inter(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_canSubmit && !_busy)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _blockReason,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                  RidealityPill(
                    onPressed: _canSubmit ? _submit : null,
                    variant: RidealityPillVariant.primary,
                    expand: true,
                    isLoading: _busy,
                    label: _isPickup ? 'Confirm pickup' : 'Complete delivery',
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
