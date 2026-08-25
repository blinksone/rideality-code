/// Google Maps Platform key for Rideality mobile apps.
///
/// **Security:** restrict this key in Google Cloud Console:
/// - Android: package `com.rideality.app` + your debug/release SHA-1
/// - iOS: bundle id `com.rideality.app`
/// - APIs: Maps SDK for Android/iOS only — **not** Places/Geocoding
///   (address search uses `/api/v1/places` on the Rideality backend)
///
/// Rotate the key if it was ever shared in chat or committed publicly.
abstract final class MapsConfig {
  static const String apiKey = 'AIzaSyBrqFXpS37FvujkuBpkddSn0LpGwxroqok';

  /// Default map center (Karachi) when no GPS fix is available yet.
  static const defaultLat = 24.8607;
  static const defaultLng = 67.0011;
}
