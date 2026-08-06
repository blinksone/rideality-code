import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../services/image_picker_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/network_avatar.dart';
import '../passenger/welcome_screen.dart';

/// Full-screen profile editor (Menu → Profile).
///
/// Wired to:
/// - `GET /users/me` load
/// - `PATCH /users/me` save (fullName, email, dateOfBirth, gender)
/// - `POST /users/me/photo` photo upload
class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key, this.initialProfile});

  static const routeName = '/update-profile';

  /// Optional bootstrap profile (avoids a flash of empty fields).
  final UserProfile? initialProfile;

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  static const Color _pageBg = Color(0xFFFAFAFA);
  static const Color _brandBlue = Color(0xFF2954E5);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  UserProfile? _me;
  DateTime? _dob;
  String? _gender;
  String? _photoUrl;
  PickedImageFile? _localPhoto;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    if (widget.initialProfile != null) {
      _applyProfile(widget.initialProfile!);
      _loading = false;
    }
    _load();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  void _applyProfile(UserProfile me) {
    _me = me;
    _nameController.text = me.fullName ?? '';
    _emailController.text = me.email ?? '';
    _photoUrl = me.photoUrl;
    _gender = UserProfile.normalizeGender(me.gender);
    _dob = _parseDob(me.dateOfBirth);
  }

  DateTime? _parseDob(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final t = raw.trim();
    // ISO or `YYYY-MM-DD` (take date part only if datetime).
    final datePart = t.contains('T') ? t.split('T').first : t;
    return DateTime.tryParse(datePart);
  }

  String _fmtDob(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _displayDob(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool _isValidEmail(String value) {
    if (value.isEmpty) return true;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _load() async {
    try {
      final me = await UserApiService.instance.getMe();
      if (!mounted) return;
      setState(() {
        _applyProfile(me);
        _loading = false;
        _error = null;
        _authFailed = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_me == null) {
          _error = e.isAuthFailure
              ? 'Your session expired. Please sign in again.'
              : e.message;
          _authFailed = e.isAuthFailure;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_me == null) {
          _error = 'Could not load profile';
          _authFailed = false;
        }
      });
    }
  }

  Future<void> _onErrorAction() async {
    if (_authFailed) {
      await TokenStorage.instance.clear();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        WelcomeScreen.routeName,
        (_) => false,
      );
      return;
    }
    final has = await TokenStorage.instance.hasSession;
    if (!mounted) return;
    if (!has) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        WelcomeScreen.routeName,
        (_) => false,
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _authFailed = false;
    });
    await _load();
  }

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto || _saving) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: _brandBlue),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.photo_camera_outlined, color: _brandBlue),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final picked = source == ImageSource.camera
        ? await ImagePickerService.instance.pickFromCamera()
        : await ImagePickerService.instance.pickFromGallery();
    if (picked == null || !mounted) return;

    setState(() {
      _localPhoto = picked;
      _uploadingPhoto = true;
    });
    try {
      // POST /users/me/photo — then service re-reads GET /users/me.
      final url = await UserApiService.instance.uploadPhoto(picked.file.path);
      if (!mounted) return;
      final refreshed = await UserApiService.instance.getMe();
      if (!mounted) return;
      setState(() {
        _applyProfile(refreshed);
        if (url.isNotEmpty) _photoUrl = url;
        _localPhoto = picked; // keep local preview until network has it
        _uploadingPhoto = false;
      });
      _toast('Photo updated');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _localPhoto = null;
      });
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _localPhoto = null;
      });
      _toast('Could not upload photo');
    }
  }

  Future<void> _pickDob() async {
    if (_saving) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 16),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _brandBlue,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_saving || _uploadingPhoto) return;

    final name = _nameController.text.trim();
    if (name.length < 2) {
      _toast('Full name is required (min 2 characters)');
      return;
    }
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _toast('Enter a valid email address');
      return;
    }

    setState(() => _saving = true);
    try {
      // PATCH /users/me — service reloads GET /users/me afterwards.
      final updated = await UserApiService.instance.updateProfile(
        fullName: name,
        email: email,
        dateOfBirth: _dob != null ? _fmtDob(_dob!) : null,
        gender: _gender,
      );
      if (!mounted) return;
      _applyProfile(updated);
      _toast('Profile updated');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Could not save profile');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  ThemeData _fieldTheme(BuildContext context) {
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
      ),
    );
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final phone = _me?.phone ?? '';
    final verified = _me?.isPhoneVerified ?? phone.isNotEmpty;
    final busy = _saving || _uploadingPhoto;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _brandBlue),
                      )
                    : _error != null && _me == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _authFailed
                                        ? Icons.lock_outline_rounded
                                        : Icons.error_outline_rounded,
                                    size: 40,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextButton(
                                    onPressed: _onErrorAction,
                                    child: Text(
                                      _authFailed ? 'Sign in again' : 'Retry',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Theme(
                            data: _fieldTheme(context),
                            child: Form(
                              key: _formKey,
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(22, 8, 22, 28),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 8),
                                    Center(
                                      child: _PhotoEditor(
                                        name: _nameController.text.isNotEmpty
                                            ? _nameController.text
                                            : (_me?.fullName ?? 'Driver'),
                                        networkUrl: _photoUrl,
                                        localPath: _localPhoto?.file.path,
                                        uploading: _uploadingPhoto,
                                        onTap: busy ? null : _pickPhoto,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            phone.isEmpty
                                                ? 'Phone not available'
                                                : phone,
                                            style: tt.bodyMedium?.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (verified) ...[
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.successSoft,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Verified',
                                              style: tt.labelSmall?.copyWith(
                                                color: const Color(0xFF15803D),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 28),
                                    AppTextField(
                                      label: 'Full name',
                                      controller: _nameController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      prefixIcon: Icons.person_outline_rounded,
                                      required: true,
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      label: 'Email',
                                      controller: _emailController,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      prefixIcon: Icons.mail_outline_rounded,
                                      hintText: 'Optional',
                                    ),
                                    const SizedBox(height: 16),
                                    InkWell(
                                      onTap: busy ? null : _pickDob,
                                      borderRadius: BorderRadius.circular(16),
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: 'Date of birth',
                                          prefixIcon: const Icon(
                                            Icons.cake_outlined,
                                          ),
                                          floatingLabelBehavior: _dob != null
                                              ? FloatingLabelBehavior.always
                                              : FloatingLabelBehavior.auto,
                                        ),
                                        child: Text(
                                          _dob == null
                                              ? 'Optional'
                                              : _displayDob(_dob!),
                                          style: tt.bodyLarge?.copyWith(
                                            color: _dob == null
                                                ? AppColors.onSurfaceVariant
                                                : AppColors.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Gender',
                                        prefixIcon: Icon(
                                          Icons.people_outline_rounded,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String?>(
                                          isExpanded: true,
                                          isDense: true,
                                          value: _gender,
                                          hint: Text(
                                            'Optional',
                                            style: tt.bodyLarge?.copyWith(
                                              color:
                                                  AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'male',
                                              child: Text('Male'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'female',
                                              child: Text('Female'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'other',
                                              child: Text('Other'),
                                            ),
                                          ],
                                          onChanged: busy
                                              ? null
                                              : (v) => setState(
                                                    () => _gender =
                                                        UserProfile
                                                            .normalizeGender(
                                                                v),
                                                  ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Theme(
                                      data: Theme.of(context).copyWith(
                                        elevatedButtonTheme:
                                            ElevatedButtonThemeData(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _brandBlue,
                                            foregroundColor: Colors.white,
                                            minimumSize:
                                                const Size.fromHeight(54),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: AppButton(
                                        label: 'Save changes',
                                        isLoading: _saving,
                                        borderRadius: 28,
                                        onPressed: busy ? null : _save,
                                      ),
                                    ),
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'Update profile',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor({
    required this.name,
    this.networkUrl,
    this.localPath,
    this.uploading = false,
    this.onTap,
  });

  final String name;
  final String? networkUrl;
  final String? localPath;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    final hasLocal = localPath != null && localPath!.isNotEmpty;
    final remote = NetworkAvatar.safeUrl(networkUrl);

    Widget photo;
    if (hasLocal) {
      photo = ClipOval(
        child: Image.file(
          File(localPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      photo = NetworkAvatar(
        name: name,
        photoUrl: remote,
        radius: size / 2,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppColors.ambientShadow,
              ),
              child: photo,
            ),
            if (uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2954E5),
                  shape: BoxShape.circle,
                  boxShadow: AppColors.ambientShadow,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
