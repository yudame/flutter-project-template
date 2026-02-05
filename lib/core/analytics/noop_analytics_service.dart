import 'analytics_service.dart';

/// Analytics service that does nothing.
///
/// Use for:
/// - Tests (no side effects)
/// - Debug builds (no noise in analytics dashboard)
/// - Users who opt out of tracking
/// - Before analytics provider is configured
///
/// This is the default implementation registered in DI.
/// Replace with [FirebaseAnalyticsService] or your preferred provider
/// when ready for production analytics.
class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent(
    String name, [
    Map<String, dynamic>? parameters,
  ]) async {
    // Do nothing
  }

  @override
  Future<void> setUserId(String? userId) async {
    // Do nothing
  }

  @override
  Future<void> setUserProperty(String name, String value) async {
    // Do nothing
  }

  @override
  Future<void> logScreenView(
    String screenName, [
    String? screenClass,
  ]) async {
    // Do nothing
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    // Do nothing
  }
}
