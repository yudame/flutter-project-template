/// Abstract analytics service interface.
///
/// Implement this interface for your analytics provider (Firebase, Mixpanel, etc.)
/// or use [NoopAnalyticsService] for testing and debug builds.
abstract class AnalyticsService {
  /// Log a custom event with optional parameters.
  ///
  /// Use event names from [AnalyticsEvents] for type safety.
  /// Use parameter names from [AnalyticsParams] for consistency.
  ///
  /// ```dart
  /// await analytics.logEvent(AnalyticsEvents.buttonTapped, {
  ///   AnalyticsParams.buttonName: 'submit',
  /// });
  /// ```
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]);

  /// Set the user ID for attribution.
  ///
  /// Call after user authentication. Pass null to clear on logout.
  ///
  /// ```dart
  /// // After login
  /// await analytics.setUserId(user.id);
  ///
  /// // After logout
  /// await analytics.setUserId(null);
  /// ```
  Future<void> setUserId(String? userId);

  /// Set a user property for segmentation.
  ///
  /// Use for properties that don't change often (plan type, account age, etc.)
  ///
  /// ```dart
  /// await analytics.setUserProperty('plan_type', 'premium');
  /// ```
  Future<void> setUserProperty(String name, String value);

  /// Log a screen view event.
  ///
  /// Usually called automatically by [AnalyticsRouteObserver].
  /// Call manually for screens not in the router (dialogs, bottom sheets).
  ///
  /// ```dart
  /// await analytics.logScreenView('settings', 'SettingsPage');
  /// ```
  Future<void> logScreenView(String screenName, [String? screenClass]);

  /// Enable or disable analytics collection.
  ///
  /// Use for GDPR compliance - disable collection if user doesn't consent.
  ///
  /// ```dart
  /// await analytics.setAnalyticsCollectionEnabled(userConsented);
  /// ```
  Future<void> setAnalyticsCollectionEnabled(bool enabled);
}
