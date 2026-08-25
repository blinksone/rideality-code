import '../core/api/api_config.dart';
import 'trip_models.dart';

double _jsonDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int _jsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double? _jsonDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Fleet company for a geo city. Submit [fleetRegionId] as `regionId`.
class FleetCompanyOption {
  const FleetCompanyOption({
    required this.id,
    required this.legalName,
    required this.regionId,
    this.regionName,
    this.regionCode,
    this.fleetRegionId,
    this.fleetRegionName,
    this.phone,
    this.email,
    this.address,
    this.logoUrl,
    this.driverCount,
    this.ratingAvg,
    this.ratingCount,
    this.reviews = const [],
  });

  final String id;
  final String legalName;
  /// Country region id from GET /auth/regions.
  final String regionId;
  final String? regionName;
  final String? regionCode;
  /// Ops city (`FleetRegion`). POST /onboarding/driver `regionId`.
  final String? fleetRegionId;
  final String? fleetRegionName;
  final String? phone;
  final String? email;
  final String? address;
  /// Relative path e.g. `/uploads/...` — resolve with [ApiConfig.resolveMediaUrl].
  final String? logoUrl;
  final int? driverCount;
  final double? ratingAvg;
  final int? ratingCount;
  final List<FleetCompanyReview> reviews;

  String? get resolvedLogoUrl => ApiConfig.resolveMediaUrl(logoUrl);

  factory FleetCompanyOption.fromJson(Map<String, dynamic> json) {
    final region = (json['region'] as Map?)?.cast<String, dynamic>() ?? {};
    return FleetCompanyOption(
      id: json['id']?.toString() ?? '',
      legalName: json['legalName']?.toString() ??
          json['name']?.toString() ??
          'Fleet',
      regionId: json['regionId']?.toString() ??
          region['id']?.toString() ??
          '',
      regionName: json['fleetRegionName']?.toString() ??
          region['name']?.toString(),
      regionCode: region['code']?.toString(),
      fleetRegionId: json['fleetRegionId']?.toString() ??
          json['fleet_region_id']?.toString(),
      fleetRegionName: json['fleetRegionName']?.toString() ??
          json['fleet_region_name']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      logoUrl: json['logoUrl']?.toString() ?? json['logo_url']?.toString(),
      driverCount: _jsonInt(
        json['driverCount'] ?? json['driver_count'],
      ),
      ratingAvg: _jsonDoubleOrNull(
        json['ratingAvg'] ?? json['rating_avg'],
      ),
      ratingCount: _jsonInt(
        json['ratingCount'] ?? json['rating_count'],
      ),
      reviews: (json['reviews'] is List)
          ? (json['reviews'] as List)
              .whereType<Map>()
              .map((e) => FleetCompanyReview.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FleetCompanyOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class FleetCompanyReview {
  const FleetCompanyReview({
    required this.id,
    required this.score,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
  });

  final String id;
  final int score;
  final String comment;
  final String reviewerName;
  final DateTime? createdAt;

  factory FleetCompanyReview.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString();
    return FleetCompanyReview(
      id: json['id']?.toString() ?? '',
      score: _jsonInt(json['score']),
      comment: json['comment']?.toString() ?? '',
      reviewerName: json['reviewerName']?.toString() ??
          json['reviewer']?.toString() ??
          '',
      createdAt: createdAtRaw == null || createdAtRaw.isEmpty
          ? null
          : DateTime.tryParse(createdAtRaw),
    );
  }
}

/// Geo city from GET /fleet/cities?regionId= — not submitted as `regionId`.
class GeoCityOption {
  const GeoCityOption({
    required this.id,
    required this.name,
    this.provinceId,
    this.provinceName,
  });

  final String id;
  final String name;
  final String? provinceId;
  final String? provinceName;

  String get label {
    if (provinceName == null || provinceName!.isEmpty) return name;
    return '$name · $provinceName';
  }

  factory GeoCityOption.fromJson(Map<String, dynamic> json) {
    final province = (json['province'] as Map?)?.cast<String, dynamic>() ?? {};
    return GeoCityOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      provinceId: json['provinceId']?.toString() ??
          json['province_id']?.toString() ??
          province['id']?.toString(),
      provinceName: province['name']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) => other is GeoCityOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class FleetDriverInvite {
  const FleetDriverInvite({
    required this.id,
    required this.token,
    required this.kind,
    required this.status,
    this.expiresAt,
    this.companyId,
    this.companyName,
    this.countryRegionId,
    this.fleetCityId,
    this.fleetCityName,
  });

  final String id;
  final String token;
  final String kind;
  final String status;
  final String? expiresAt;
  final String? companyId;
  final String? companyName;
  /// Country region on the company — not the city.
  final String? countryRegionId;
  /// City applied on accept, if the invite payload includes it.
  final String? fleetCityId;
  final String? fleetCityName;

  bool get isPendingDriver =>
      kind.toLowerCase() == 'driver' &&
      (status.toLowerCase() == 'pending' || status.toLowerCase() == 'sent');

  factory FleetDriverInvite.fromJson(Map<String, dynamic> json) {
    final company =
        (json['fleetCompany'] as Map?)?.cast<String, dynamic>() ??
            (json['company'] as Map?)?.cast<String, dynamic>() ??
            const {};
    final city = (json['fleetRegion'] as Map?)?.cast<String, dynamic>() ??
        (json['city'] as Map?)?.cast<String, dynamic>() ??
        (json['region'] as Map?)?.cast<String, dynamic>() ??
        const {};
    return FleetDriverInvite(
      id: json['id']?.toString() ?? '',
      token: json['token']?.toString() ?? json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString(),
      companyId: company['id']?.toString() ?? json['companyId']?.toString(),
      companyName: company['legalName']?.toString() ??
          company['name']?.toString(),
      countryRegionId: company['regionId']?.toString(),
      fleetCityId: json['fleetRegionId']?.toString() ??
          json['fleetCityId']?.toString() ??
          json['cityId']?.toString() ??
          city['id']?.toString(),
      fleetCityName: json['fleetCityName']?.toString() ??
          city['name']?.toString(),
    );
  }
}

class Region {
  const Region({
    required this.id,
    required this.code,
    required this.name,
    required this.currency,
    required this.phonePrefix,
  });

  final String id;
  final String code;
  final String name;
  final String currency;
  final String phonePrefix;

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      phonePrefix: json['phonePrefix']?.toString() ?? '',
    );
  }
}

class OnboardingStatus {
  const OnboardingStatus({
    required this.phoneVerified,
    required this.personalInfo,
    required this.roleSelected,
    required this.vehicleInfo,
    required this.documentsUploaded,
    required this.locationsSaved,
    required this.driverApproved,
    required this.profileComplete,
    required this.pendingSteps,
    required this.isDriver,
    this.documentsApproved = false,
    this.documentStatus,
    this.canBook = false,
    this.canDrive = false,
  });

  final bool phoneVerified;
  final bool personalInfo;
  final bool roleSelected;
  final bool vehicleInfo;
  /// Files were submitted — not the same as Documents checklist Done.
  final bool documentsUploaded;
  /// Documents row Done — use this, not [documentsUploaded].
  final bool documentsApproved;
  /// `missing` | `pending` | `approved` | `rejected` | `expired`
  final String? documentStatus;
  final bool locationsSaved;
  final bool driverApproved;
  final bool profileComplete;
  final List<String> pendingSteps;
  final bool isDriver;
  final bool canBook;
  final bool canDrive;

  String get documentStatusLabel {
    switch ((documentStatus ?? '').toLowerCase()) {
      case 'missing':
        return 'Upload required';
      case 'pending':
        return 'Waiting for review';
      case 'approved':
        return 'Approved';
      case 'rejected':
      case 'expired':
        return 'Reupload';
      default:
        if (documentsApproved) return 'Approved';
        if (documentsUploaded) return 'Waiting for review';
        return 'Upload required';
    }
  }

  bool get documentsNeedReupload {
    final s = (documentStatus ?? '').toLowerCase();
    return s == 'rejected' || s == 'expired';
  }

  bool get documentsPendingReview {
    final s = (documentStatus ?? '').toLowerCase();
    return s == 'pending' ||
        (documentsUploaded && !documentsApproved && !documentsNeedReupload);
  }

  /// Parse data from OTP user.onboarding, GET /onboarding/status, or nested payloads.
  factory OnboardingStatus.fromJson(
    Map<String, dynamic>? json, {
    Map<String, dynamic>? capabilities,
  }) {
    return OnboardingStatus.fromApiPayload(
      json == null ? null : {...json},
      capabilities: capabilities,
    );
  }

  factory OnboardingStatus.fromApiPayload(
    Map<String, dynamic>? data, {
    Map<String, dynamic>? capabilities,
  }) {
    data ??= const {};

    Map<String, dynamic> map;
    if (data['onboarding'] is Map) {
      map = (data['onboarding'] as Map).cast<String, dynamic>();
    } else {
      map = data;
    }

    final caps = capabilities ??
        (data['capabilities'] is Map
            ? (data['capabilities'] as Map).cast<String, dynamic>()
            : map['capabilities'] is Map
                ? (map['capabilities'] as Map).cast<String, dynamic>()
                : null);

    final pending = <String>[];
    void addPending(dynamic raw) {
      if (raw is List) {
        pending.addAll(raw.map((e) => e.toString()));
      } else if (raw is String && raw.isNotEmpty) {
        pending.add(raw);
      }
    }

    addPending(map['pending_steps']);
    addPending(data['pending_steps']);
    addPending(map['next_steps']);
    addPending(data['next_steps']);
    addPending(map['nextSteps']);
    addPending(data['nextSteps']);

    bool readBool(String snake, [String? camel]) {
      if (map[snake] == true || data![snake] == true) return true;
      if (camel != null && (map[camel] == true || data[camel] == true)) {
        return true;
      }
      if (map[snake] == false || data[snake] == false) return false;
      if (camel != null && (map[camel] == false || data[camel] == false)) {
        return false;
      }
      // Infer "done" only when pending list is present and key is known.
      if (pending.isNotEmpty) {
        return !pending.contains(snake);
      }
      return false;
    }

    final isDriver = map['is_driver'] == true ||
        data['is_driver'] == true ||
        map['isDriver'] == true ||
        pending.any(
          (s) =>
              s == 'vehicle_info' ||
              s == 'documents_uploaded' ||
              s == 'driver_approved',
        );

    final documentsUploaded = map['documents_uploaded'] == true ||
        data['documents_uploaded'] == true ||
        map['documentsUploaded'] == true ||
        data['documentsUploaded'] == true;
    final documentsApproved = map['documents_approved'] == true ||
        data['documents_approved'] == true ||
        map['documentsApproved'] == true ||
        data['documentsApproved'] == true;
    final documentStatus = (map['document_status'] ??
            data['document_status'] ??
            map['documentStatus'] ??
            data['documentStatus'])
        ?.toString();

    return OnboardingStatus(
      phoneVerified: readBool('phone_verified', 'phoneVerified'),
      personalInfo: readBool('personal_info', 'personalInfo'),
      roleSelected: readBool('role_selected', 'roleSelected'),
      vehicleInfo: map['vehicle_info'] == true || data['vehicle_info'] == true
          ? true
          : (pending.isNotEmpty
              ? !pending.contains('vehicle_info') && isDriver
              : false),
      documentsUploaded: documentsUploaded,
      documentsApproved: documentsApproved,
      documentStatus: documentStatus,
      locationsSaved: map['locations_saved'] == true ||
          data['locations_saved'] == true ||
          (pending.isNotEmpty &&
              !pending.contains('locations_saved') &&
              map['locations_saved'] != false),
      driverApproved: map['driver_approved'] == true ||
          data['driver_approved'] == true ||
          map['driverApproved'] == true ||
          data['driverApproved'] == true,
      profileComplete: map['profile_complete'] == true ||
          data['profile_complete'] == true,
      pendingSteps: pending.toSet().toList(),
      isDriver: isDriver,
      canBook: caps?['can_book'] == true,
      canDrive: caps?['can_drive'] == true,
    );
  }

  static const empty = OnboardingStatus(
    phoneVerified: false,
    personalInfo: false,
    roleSelected: false,
    vehicleInfo: false,
    documentsUploaded: false,
    documentsApproved: false,
    documentStatus: null,
    locationsSaved: false,
    driverApproved: false,
    profileComplete: false,
    pendingSteps: [],
    isDriver: false,
  );
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    this.email,
    this.status,
    this.activeMode,
    this.regionId,
    this.onboarding = OnboardingStatus.empty,
  });

  final String id;
  final String phone;
  final String? email;
  final String? status;
  final String? activeMode;
  final String? regionId;
  final OnboardingStatus onboarding;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final onboardingRaw = json['onboarding'];
    return AuthUser(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      status: json['status']?.toString(),
      activeMode: json['activeMode']?.toString(),
      regionId: json['regionId']?.toString(),
      onboarding: onboardingRaw is Map
          ? OnboardingStatus.fromApiPayload(
              onboardingRaw.cast<String, dynamic>(),
            )
          : OnboardingStatus.fromApiPayload(json),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.sessionId,
    required this.isNewUser,
    required this.user,
    this.devBypassCode,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String sessionId;
  final bool isNewUser;
  final AuthUser user;
  final String? devBypassCode;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      sessionId: json['sessionId']?.toString() ?? '',
      isNewUser: json['isNewUser'] == true,
      user: AuthUser.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class OtpSendResult {
  const OtpSendResult({
    required this.phone,
    required this.regionCode,
    required this.message,
    this.devBypassCode,
    this.otpCode,
  });

  final String phone;
  final String regionCode;
  final String message;
  final String? devBypassCode;
  final String? otpCode;

  factory OtpSendResult.fromJson(Map<String, dynamic> json) {
    return OtpSendResult(
      phone: json['phone']?.toString() ?? '',
      regionCode: json['regionCode']?.toString() ?? '',
      message: json['message']?.toString() ?? 'OTP sent',
      devBypassCode:
          json['devBypassCode']?.toString() ?? json['devCode']?.toString(),
      otpCode: json['otpCode']?.toString() ?? json['code']?.toString(),
    );
  }

  String? get resolvedDevCode => devBypassCode ?? otpCode;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    this.email,
    this.status,
    this.activeMode,
    this.fullName,
    this.photoUrl,
    this.dateOfBirth,
    this.gender,
    this.onboarding = OnboardingStatus.empty,
    this.canBook = false,
    this.canDrive = false,
  });

  final String id;
  final String phone;
  final String? email;
  final String? status;
  final String? activeMode;
  final String? fullName;
  final String? photoUrl;
  final String? dateOfBirth;
  final String? gender;
  final OnboardingStatus onboarding;
  final bool canBook;
  final bool canDrive;

  /// Phone is OTP-verified when non-empty (auth path), or onboarding flags it.
  bool get isPhoneVerified =>
      phone.trim().isNotEmpty || onboarding.phoneVerified;

  /// Normalize backend gender values for dropdowns / PATCH body.
  static String? normalizeGender(String? raw) {
    if (raw == null) return null;
    final g = raw.trim().toLowerCase();
    if (g.isEmpty) return null;
    if (g == 'm' || g == 'male') return 'male';
    if (g == 'f' || g == 'female') return 'female';
    if (g == 'o' || g == 'other' || g == 'prefer_not_to_say') return 'other';
    return null;
  }

  UserProfile copyWith({
    String? id,
    String? phone,
    String? email,
    String? status,
    String? activeMode,
    String? fullName,
    String? photoUrl,
    String? dateOfBirth,
    String? gender,
    OnboardingStatus? onboarding,
    bool? canBook,
    bool? canDrive,
  }) {
    return UserProfile(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      activeMode: activeMode ?? this.activeMode,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      onboarding: onboarding ?? this.onboarding,
      canBook: canBook ?? this.canBook,
      canDrive: canDrive ?? this.canDrive,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final caps = (json['capabilities'] as Map?)?.cast<String, dynamic>() ?? {};
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    return UserProfile(
      id: json['id']?.toString() ??
          user['id']?.toString() ??
          profile['id']?.toString() ??
          '',
      phone: json['phone']?.toString() ??
          user['phone']?.toString() ??
          profile['phone']?.toString() ??
          '',
      email: profile['email']?.toString() ??
          json['email']?.toString() ??
          user['email']?.toString(),
      status: json['status']?.toString() ?? user['status']?.toString(),
      activeMode:
          json['activeMode']?.toString() ?? user['activeMode']?.toString(),
      fullName: profile['fullName']?.toString() ??
          json['fullName']?.toString() ??
          user['fullName']?.toString(),
      photoUrl: ApiConfig.resolveMediaUrl(
        profile['photoUrl']?.toString() ??
            json['photoUrl']?.toString() ??
            user['photoUrl']?.toString() ??
            profile['photo']?.toString(),
      ),
      dateOfBirth: profile['dateOfBirth']?.toString() ??
          profile['dob']?.toString() ??
          json['dateOfBirth']?.toString() ??
          json['dob']?.toString(),
      gender: normalizeGender(
        profile['gender']?.toString() ??
            json['gender']?.toString() ??
            user['gender']?.toString(),
      ),
      onboarding: OnboardingStatus.fromApiPayload(json),
      canBook: caps['can_book'] == true || caps['canBook'] == true,
      canDrive: caps['can_drive'] == true || caps['canDrive'] == true,
    );
  }
}

class DriverDocument {
  const DriverDocument({
    required this.id,
    required this.type,
    required this.status,
    this.submittedAt,
    this.rejectionReason,
  });

  final String id;
  final String type;
  final String status;
  final String? submittedAt;
  final String? rejectionReason;

  bool get isRejected {
    final s = status.toLowerCase().trim();
    return s == 'rejected' ||
        s == 'declined' ||
        s == 'denied' ||
        s == 'failed' ||
        s == 'needs_resubmission' ||
        s == 'resubmit' ||
        s == 'correction_required' ||
        s == 'reupload_required';
  }

  bool get isApproved {
    final s = status.toLowerCase().trim();
    return s == 'approved' || s == 'active' || s == 'verified';
  }

  bool get isPending {
    final s = status.toLowerCase().trim();
    return s == 'pending' ||
        s == 'pending_review' ||
        s == 'under_review' ||
        s == 'submitted';
  }

  /// True when fleet sent feedback and the driver should upload again.
  bool get needsResubmission =>
      isRejected ||
      (rejectionReason != null &&
          rejectionReason!.trim().isNotEmpty &&
          !isApproved);

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status'] ??
        json['reviewStatus'] ??
        json['verificationStatus'] ??
        json['state'] ??
        json['review_status'];
    return DriverDocument(
      id: json['id']?.toString() ?? '',
      type: (json['type'] ?? json['documentType'] ?? json['document_type'])
              ?.toString()
              .toLowerCase()
              .trim() ??
          '',
      status: statusRaw?.toString().toLowerCase().trim() ?? 'pending',
      submittedAt: json['submittedAt']?.toString() ??
          json['submitted_at']?.toString(),
      rejectionReason: json['rejectionReason']?.toString() ??
          json['rejectedReason']?.toString() ??
          json['rejectReason']?.toString() ??
          json['reason']?.toString() ??
          json['notes']?.toString() ??
          json['feedback']?.toString(),
    );
  }

  static int _statusRank(DriverDocument d) {
    if (d.needsResubmission) return 3;
    if (d.isPending) return 2;
    if (d.isApproved) return 1;
    return 0;
  }

  /// When API returns history, keep the row that needs action (rejected wins).
  static Map<String, DriverDocument> indexByType(Iterable<DriverDocument> docs) {
    final map = <String, DriverDocument>{};
    for (final d in docs) {
      final key = d.type;
      if (key.isEmpty) continue;
      final prev = map[key];
      if (prev == null || _statusRank(d) > _statusRank(prev)) {
        map[key] = d;
      }
    }
    return map;
  }
}

class DriverView {
  const DriverView({
    required this.onboardingStatus,
    this.licenseNumber,
    this.licenseExpiry,
    this.vehicleType,
    this.vehicleModel,
    this.numberPlate,
    this.isOnline = false,
    this.totalRides = 0,
    this.totalDistanceKm = 0,
    this.activeHours = 0,
    this.incentiveTier = 'basic',
    this.driverType,
    this.ratingAvg,
    this.serviceModes = const [DriverServiceMode.rides],
    this.cargoCapacityKg,
    this.fleetCompanyId,
    this.rejectionReason,
  });

  final String onboardingStatus;
  final String? licenseNumber;
  final String? licenseExpiry;
  final String? vehicleType;
  final String? vehicleModel;
  final String? numberPlate;
  final bool isOnline;
  final int totalRides;
  final double totalDistanceKm;
  final double activeHours;
  final String incentiveTier;
  final String? driverType;
  final double? ratingAvg;
  final List<DriverServiceMode> serviceModes;
  final double? cargoCapacityKg;
  final String? fleetCompanyId;
  final String? rejectionReason;

  bool get isApproved {
    final s = onboardingStatus.toLowerCase();
    return s == 'approved' || s == 'active';
  }

  bool get isRejected {
    final s = onboardingStatus.toLowerCase();
    return s == 'rejected' || s == 'declined' || s == 'denied';
  }

  bool get isSuspended => onboardingStatus.toLowerCase() == 'suspended';

  bool get acceptsRides => serviceModes.contains(DriverServiceMode.rides);
  bool get acceptsCargo => serviceModes.contains(DriverServiceMode.cargo);

  DriverView copyWith({
    bool? isOnline,
    List<DriverServiceMode>? serviceModes,
    double? cargoCapacityKg,
    String? fleetCompanyId,
  }) {
    return DriverView(
      onboardingStatus: onboardingStatus,
      licenseNumber: licenseNumber,
      licenseExpiry: licenseExpiry,
      vehicleType: vehicleType,
      vehicleModel: vehicleModel,
      numberPlate: numberPlate,
      isOnline: isOnline ?? this.isOnline,
      totalRides: totalRides,
      totalDistanceKm: totalDistanceKm,
      activeHours: activeHours,
      incentiveTier: incentiveTier,
      driverType: driverType,
      ratingAvg: ratingAvg,
      serviceModes: serviceModes ?? this.serviceModes,
      cargoCapacityKg: cargoCapacityKg ?? this.cargoCapacityKg,
      fleetCompanyId: fleetCompanyId ?? this.fleetCompanyId,
      rejectionReason: rejectionReason,
    );
  }

  factory DriverView.fromJson(Map<String, dynamic> json) {
    if (json['driver'] is Map) {
      json = {
        ...json,
        ...(json['driver'] as Map).cast<String, dynamic>(),
      };
    }
    final vehicle = (json['vehicle'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile = (json['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final prefs = (json['preferences'] as Map?)?.cast<String, dynamic>() ?? {};

    double? capacity;
    final capRaw = json['cargoCapacityKg'] ??
        json['cargo_capacity_kg'] ??
        vehicle['cargoCapacityKg'] ??
        vehicle['cargo_capacity_kg'] ??
        vehicle['capacityKg'];
    if (capRaw is num) {
      capacity = capRaw.toDouble();
    } else if (capRaw != null) {
      capacity = double.tryParse(capRaw.toString());
    }

    final review = (json['review'] as Map?)?.cast<String, dynamic>() ??
        (json['verification'] as Map?)?.cast<String, dynamic>() ??
        {};
    final reason = json['rejectionReason']?.toString() ??
        json['rejectedReason']?.toString() ??
        json['rejectReason']?.toString() ??
        json['reviewNotes']?.toString() ??
        json['notes']?.toString() ??
        json['reason']?.toString() ??
        review['rejectionReason']?.toString() ??
        review['reason']?.toString() ??
        review['notes']?.toString();

    return DriverView(
      onboardingStatus: (json['onboardingStatus']?.toString() ??
              json['status']?.toString() ??
              'draft')
          .toLowerCase(),
      licenseNumber: json['licenseNumber']?.toString(),
      licenseExpiry: json['licenseExpiry']?.toString(),
      vehicleType: vehicle['vehicleType']?.toString() ??
          json['vehicleType']?.toString(),
      vehicleModel:
          vehicle['model']?.toString() ?? json['vehicleModel']?.toString(),
      numberPlate: vehicle['numberPlate']?.toString() ??
          json['numberPlate']?.toString(),
      isOnline: json['isOnline'] == true,
      totalRides: _jsonInt(json['totalRides']),
      totalDistanceKm: _jsonDouble(json['totalDistanceKm']),
      activeHours: _jsonDouble(json['activeHours']),
      incentiveTier: json['incentiveTier']?.toString() ?? 'basic',
      driverType: json['driverType']?.toString(),
      ratingAvg: _jsonDoubleOrNull(profile['ratingAvg']) ??
          _jsonDoubleOrNull(json['ratingAvg']),
      serviceModes: DriverServiceMode.parseList(
        json['serviceModes'] ??
            json['service_modes'] ??
            prefs['serviceModes'] ??
            json['modes'],
      ),
      cargoCapacityKg: capacity,
      fleetCompanyId: json['fleetCompanyId']?.toString() ??
          json['fleet_company_id']?.toString() ??
          (json['fleetCompany'] is Map
              ? (json['fleetCompany'] as Map)['id']?.toString()
              : null),
      rejectionReason: (reason != null && reason.trim().isNotEmpty)
          ? reason.trim()
          : null,
    );
  }

  static const empty = DriverView(onboardingStatus: 'draft');
}

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;
  final bool isDefault;

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'place',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] == true,
    );
  }

  bool get isHome => label.toLowerCase() == 'home';
  bool get isWork => label.toLowerCase() == 'work';
}

class WalletInfo {
  const WalletInfo({
    required this.id,
    required this.balance,
    required this.currency,
    required this.status,
  });

  final String id;
  final double balance;
  final String currency;
  final String status;

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      id: json['id']?.toString() ?? '',
      balance: _jsonDouble(json['balance']),
      currency: json['currency']?.toString() ?? 'PKR',
      status: json['status']?.toString() ?? 'active',
    );
  }

  static const empty = WalletInfo(
    id: '',
    balance: 0,
    currency: 'PKR',
    status: 'active',
  );
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = 'PKR',
    this.createdAt,
    this.description,
  });

  final String id;
  final String type;
  final double amount;
  final String currency;
  final String? createdAt;
  final String? description;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'transaction',
      amount: _jsonDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'PKR',
      createdAt: json['createdAt']?.toString(),
      description: json['description']?.toString() ?? json['note']?.toString(),
    );
  }
}

class RideSummary {
  const RideSummary({
    required this.id,
    required this.status,
    this.pickupAddress,
    this.dropoffAddress,
    this.fare,
    this.currency = 'PKR',
    this.createdAt,
    this.vehicleType,
  });

  final String id;
  final String status;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? fare;
  final String currency;
  final String? createdAt;
  final String? vehicleType;

  factory RideSummary.fromJson(Map<String, dynamic> json) {
    final pickup = (json['pickup'] is Map)
        ? (json['pickup'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final dropoffRaw = json['dropoff'] ?? json['destination'];
    final dropoff = dropoffRaw is Map
        ? dropoffRaw.cast<String, dynamic>()
        : const <String, dynamic>{};
    // API may send fare as a number or as { total, currency }.
    final fareRaw = json['fare'];
    final fareMap =
        fareRaw is Map ? fareRaw.cast<String, dynamic>() : const <String, dynamic>{};
    return RideSummary(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      pickupAddress: pickup['address']?.toString() ??
          json['pickupAddress']?.toString(),
      dropoffAddress: dropoff['address']?.toString() ??
          json['dropoffAddress']?.toString() ??
          json['destinationAddress']?.toString(),
      fare: _jsonDoubleOrNull(fareMap['total']) ??
          _jsonDoubleOrNull(json['totalFare']) ??
          _jsonDoubleOrNull(fareRaw),
      currency: fareMap['currency']?.toString() ??
          json['currency']?.toString() ??
          'PKR',
      createdAt: json['createdAt']?.toString() ?? json['startedAt']?.toString(),
      vehicleType: json['vehicleType']?.toString() ??
          (json['vehicle'] is Map
              ? (json['vehicle'] as Map)['vehicleType']?.toString()
              : null),
    );
  }
}

class PassengerView {
  const PassengerView({
    required this.fullName,
    this.photoUrl,
    this.email,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.loyaltyTier = 'basic',
    this.loyaltyPoints = 0,
    this.totalRides = 0,
    this.totalSpend = 0,
    this.wallet = WalletInfo.empty,
    this.savedPlaces = const [],
    this.promoOptIn = true,
  });

  final String fullName;
  final String? photoUrl;
  final String? email;
  final double ratingAvg;
  final int ratingCount;
  final String loyaltyTier;
  final int loyaltyPoints;
  final int totalRides;
  final double totalSpend;
  final WalletInfo wallet;
  final List<SavedPlace> savedPlaces;
  final bool promoOptIn;

  factory PassengerView.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final loyalty = (json['loyalty'] as Map?)?.cast<String, dynamic>() ?? {};
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final walletMap = (json['wallet'] as Map?)?.cast<String, dynamic>() ?? {};
    final preferences =
        (json['preferences'] as Map?)?.cast<String, dynamic>() ?? {};
    final places = <SavedPlace>[];
    final rawPlaces = json['savedPlaces'] ?? json['locations'];
    if (rawPlaces is List) {
      for (final item in rawPlaces) {
        if (item is Map) {
          places.add(SavedPlace.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return PassengerView(
      fullName: profile['fullName']?.toString() ??
          json['fullName']?.toString() ??
          '',
      photoUrl: ApiConfig.resolveMediaUrl(profile['photoUrl']?.toString()),
      email: profile['email']?.toString() ?? json['email']?.toString(),
      ratingAvg: _jsonDouble(
        profile['ratingAvg'] ?? json['ratingAvg'],
      ),
      ratingCount: _jsonInt(
        profile['ratingCount'] ?? json['ratingCount'],
      ),
      loyaltyTier: loyalty['tier']?.toString() ??
          json['loyaltyTier']?.toString() ??
          'basic',
      loyaltyPoints: _jsonInt(
        loyalty['points'] ?? json['loyaltyPoints'],
      ),
      totalRides: _jsonInt(stats['totalRides'] ?? json['totalRides']),
      totalSpend: _jsonDouble(stats['totalSpend'] ?? json['totalSpend']),
      wallet: walletMap.isEmpty
          ? WalletInfo.empty
          : WalletInfo.fromJson(walletMap),
      savedPlaces: places,
      promoOptIn: preferences['promoOptIn'] != false,
    );
  }

  static const empty = PassengerView(fullName: '');
}
