import '../core/api/api_config.dart';

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
    this.canBook = false,
    this.canDrive = false,
  });

  final bool phoneVerified;
  final bool personalInfo;
  final bool roleSelected;
  final bool vehicleInfo;
  final bool documentsUploaded;
  final bool locationsSaved;
  final bool driverApproved;
  final bool profileComplete;
  final List<String> pendingSteps;
  final bool isDriver;
  final bool canBook;
  final bool canDrive;

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

    return OnboardingStatus(
      phoneVerified: readBool('phone_verified', 'phoneVerified'),
      personalInfo: readBool('personal_info', 'personalInfo'),
      roleSelected: readBool('role_selected', 'roleSelected'),
      vehicleInfo: map['vehicle_info'] == true || data['vehicle_info'] == true
          ? true
          : (pending.isNotEmpty
              ? !pending.contains('vehicle_info') && isDriver
              : false),
      documentsUploaded:
          map['documents_uploaded'] == true || data['documents_uploaded'] == true
              ? true
              : (pending.isNotEmpty
                  ? !pending.contains('documents_uploaded') && isDriver
                  : false),
      locationsSaved: map['locations_saved'] == true ||
          data['locations_saved'] == true ||
          (pending.isNotEmpty && !pending.contains('locations_saved') && map['locations_saved'] != false),
      driverApproved: map['driver_approved'] == true ||
          data['driver_approved'] == true,
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

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      submittedAt: json['submittedAt']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
    );
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

  bool get isApproved {
    final s = onboardingStatus.toLowerCase();
    return s == 'approved' || s == 'active';
  }

  factory DriverView.fromJson(Map<String, dynamic> json) {
    final vehicle = (json['vehicle'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile = (json['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    return DriverView(
      onboardingStatus: json['onboardingStatus']?.toString() ??
          json['status']?.toString() ??
          'draft',
      licenseNumber: json['licenseNumber']?.toString(),
      licenseExpiry: json['licenseExpiry']?.toString(),
      vehicleType: vehicle['vehicleType']?.toString() ??
          json['vehicleType']?.toString(),
      vehicleModel:
          vehicle['model']?.toString() ?? json['vehicleModel']?.toString(),
      numberPlate: vehicle['numberPlate']?.toString() ??
          json['numberPlate']?.toString(),
      isOnline: json['isOnline'] == true,
      totalRides: (json['totalRides'] as num?)?.toInt() ?? 0,
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      activeHours: (json['activeHours'] as num?)?.toDouble() ?? 0,
      incentiveTier: json['incentiveTier']?.toString() ?? 'basic',
      driverType: json['driverType']?.toString(),
      ratingAvg: (profile['ratingAvg'] as num?)?.toDouble() ??
          (json['ratingAvg'] as num?)?.toDouble(),
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
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
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
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
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
    final pickup = (json['pickup'] as Map?)?.cast<String, dynamic>() ?? {};
    final dropoff = (json['dropoff'] as Map?)?.cast<String, dynamic>() ??
        (json['destination'] as Map?)?.cast<String, dynamic>() ??
        {};
    final fareMap = (json['fare'] as Map?)?.cast<String, dynamic>() ?? {};
    return RideSummary(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      pickupAddress: pickup['address']?.toString() ??
          json['pickupAddress']?.toString(),
      dropoffAddress: dropoff['address']?.toString() ??
          json['dropoffAddress']?.toString() ??
          json['destinationAddress']?.toString(),
      fare: (fareMap['total'] as num?)?.toDouble() ??
          (json['totalFare'] as num?)?.toDouble() ??
          (json['fare'] is num ? (json['fare'] as num).toDouble() : null),
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
      ratingAvg: (profile['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (profile['ratingCount'] as num?)?.toInt() ?? 0,
      loyaltyTier: loyalty['tier']?.toString() ??
          json['loyaltyTier']?.toString() ??
          'basic',
      loyaltyPoints: (loyalty['points'] as num?)?.toInt() ??
          (json['loyaltyPoints'] as num?)?.toInt() ??
          0,
      totalRides: (stats['totalRides'] as num?)?.toInt() ?? 0,
      totalSpend: (stats['totalSpend'] as num?)?.toDouble() ?? 0,
      wallet: walletMap.isEmpty
          ? WalletInfo.empty
          : WalletInfo.fromJson(walletMap),
      savedPlaces: places,
      promoOptIn: preferences['promoOptIn'] != false,
    );
  }

  static const empty = PassengerView(fullName: '');
}
