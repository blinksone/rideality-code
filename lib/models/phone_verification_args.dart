import 'api_models.dart';

enum OnboardingIntent { passenger, driver, login }

class PhoneVerificationArgs {
  const PhoneVerificationArgs({
    required this.phone,
    required this.displayPhone,
    required this.regionCode,
    this.devBypassCode,
    this.intent = OnboardingIntent.passenger,
  });

  final String phone;
  final String displayPhone;
  final String regionCode;
  final String? devBypassCode;
  final OnboardingIntent intent;
}

/// Routes after OTP based on onboarding flags + user intent.
String nextRouteAfterOtp(
  OnboardingStatus onboarding, {
  required bool isNewUser,
  OnboardingIntent intent = OnboardingIntent.passenger,
  String? activeMode,
  String? userStatus,
}) {
  if (intent == OnboardingIntent.login) {
    return nextRouteAfterLogin(
      onboarding,
      isNewUser: isNewUser,
      activeMode: activeMode,
      userStatus: userStatus,
    );
  }
  if (intent == OnboardingIntent.driver) {
    return nextDriverRoute(onboarding, isNewUser: isNewUser);
  }
  return nextPassengerRoute(onboarding, isNewUser: isNewUser);
}

/// Login: resume wherever the account left off.
String nextRouteAfterLogin(
  OnboardingStatus onboarding, {
  required bool isNewUser,
  String? activeMode,
  String? userStatus,
}) {
  final mode = (activeMode ?? '').toLowerCase();
  final status = (userStatus ?? '').toUpperCase();

  // Brand-new account that only verified phone → passenger signup.
  if (isNewUser ||
      !onboarding.personalInfo ||
      onboarding.pendingSteps.contains('personal_info') ||
      status == 'PHONE_VERIFIED') {
    if (mode == 'driver' || onboarding.isDriver) {
      return '/become-driver';
    }
    return '/personal-info';
  }

  // Driver path incomplete.
  if (mode == 'driver' || onboarding.isDriver) {
    if (!onboarding.vehicleInfo ||
        onboarding.pendingSteps.contains('vehicle_info')) {
      return '/vehicle-details';
    }
    if (!onboarding.documentsUploaded ||
        onboarding.pendingSteps.contains('documents_uploaded')) {
      return '/documents';
    }
    if (onboarding.canDrive || onboarding.driverApproved) {
      return '/driver-home';
    }
    return '/under-review';
  }

  // Passenger incomplete profile.
  if (status == 'PROFILE_INCOMPLETE' ||
      !onboarding.profileComplete ||
      !onboarding.locationsSaved ||
      onboarding.pendingSteps.contains('locations_saved')) {
    return '/complete-profile';
  }

  return '/home';
}

String nextPassengerRoute(
  OnboardingStatus onboarding, {
  required bool isNewUser,
}) {
  if (isNewUser ||
      !onboarding.personalInfo ||
      onboarding.pendingSteps.contains('personal_info')) {
    return '/personal-info';
  }
  if (!onboarding.profileComplete ||
      !onboarding.locationsSaved ||
      onboarding.pendingSteps.contains('locations_saved')) {
    return '/complete-profile';
  }
  return '/home';
}

String nextDriverRoute(
  OnboardingStatus onboarding, {
  bool isNewUser = false,
}) {
  if (isNewUser ||
      !onboarding.personalInfo ||
      !onboarding.isDriver ||
      onboarding.pendingSteps.contains('personal_info')) {
    return '/become-driver';
  }
  if (!onboarding.vehicleInfo ||
      onboarding.pendingSteps.contains('vehicle_info')) {
    return '/vehicle-details';
  }
  if (!onboarding.documentsUploaded ||
      onboarding.pendingSteps.contains('documents_uploaded')) {
    return '/documents';
  }
  if (onboarding.canDrive || onboarding.driverApproved) {
    return '/driver-home';
  }
  return '/under-review';
}
