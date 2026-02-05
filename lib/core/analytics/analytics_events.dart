/// Centralized event names for analytics.
///
/// Using constants prevents typos and ensures consistency across the app.
/// Add new events here, not as inline strings.
///
/// ```dart
/// await analytics.logEvent(AnalyticsEvents.buttonTapped, {
///   AnalyticsParams.buttonName: 'save',
/// });
/// ```
class AnalyticsEvents {
  AnalyticsEvents._(); // Prevent instantiation

  // === Screen Views ===
  // Usually tracked automatically by AnalyticsRouteObserver

  /// Screen was viewed (usually automatic)
  static const screenView = 'screen_view';

  // === User Actions ===

  /// User tapped a button
  static const buttonTapped = 'button_tapped';

  /// User submitted a form
  static const formSubmitted = 'form_submitted';

  /// User performed a search
  static const searchPerformed = 'search_performed';

  /// User pulled to refresh
  static const pullToRefresh = 'pull_to_refresh';

  // === Feature Usage ===

  /// User used a specific feature
  static const featureUsed = 'feature_used';

  /// User toggled a setting
  static const settingChanged = 'setting_changed';

  // === CRUD Operations ===

  /// Item was created
  static const itemCreated = 'item_created';

  /// Item was updated
  static const itemUpdated = 'item_updated';

  /// Item was deleted
  static const itemDeleted = 'item_deleted';

  /// Item was viewed
  static const itemViewed = 'item_viewed';

  // === Authentication ===

  /// User completed login
  static const loginCompleted = 'login_completed';

  /// User completed signup
  static const signupCompleted = 'signup_completed';

  /// User logged out
  static const logoutCompleted = 'logout_completed';

  /// Password reset requested
  static const passwordResetRequested = 'password_reset_requested';

  // === Errors ===

  /// An error occurred
  static const errorOccurred = 'error_occurred';

  // === Connectivity ===

  /// App went offline
  static const wentOffline = 'went_offline';

  /// App came back online
  static const cameOnline = 'came_online';

  /// Offline queue was processed
  static const offlineQueueProcessed = 'offline_queue_processed';
}

/// Standard parameter names for analytics events.
///
/// Using constants ensures consistency across events.
///
/// ```dart
/// await analytics.logEvent(AnalyticsEvents.itemCreated, {
///   AnalyticsParams.itemId: item.id,
///   AnalyticsParams.itemType: 'task',
/// });
/// ```
class AnalyticsParams {
  AnalyticsParams._(); // Prevent instantiation

  // === Screen/Location ===

  /// Name of the screen
  static const screenName = 'screen_name';

  /// Class name of the screen widget
  static const screenClass = 'screen_class';

  // === User Actions ===

  /// Name of the button that was tapped
  static const buttonName = 'button_name';

  /// Search query (sanitized, no PII)
  static const searchQuery = 'search_query';

  /// Number of search results
  static const searchResultCount = 'search_result_count';

  // === Feature Usage ===

  /// Name of the feature
  static const featureName = 'feature_name';

  /// Name of the setting that was changed
  static const settingName = 'setting_name';

  /// New value of the setting
  static const settingValue = 'setting_value';

  // === Items ===

  /// ID of the item
  static const itemId = 'item_id';

  /// Type of item (task, note, etc.)
  static const itemType = 'item_type';

  /// Name/title of the item (if not sensitive)
  static const itemName = 'item_name';

  // === Authentication ===

  /// Authentication method (email, google, apple)
  static const method = 'method';

  // === Errors ===

  /// Type/category of error
  static const errorType = 'error_type';

  /// Error message (sanitized, no PII)
  static const errorMessage = 'error_message';

  /// Error code if available
  static const errorCode = 'error_code';

  // === Connectivity ===

  /// Number of items in offline queue
  static const queueCount = 'queue_count';

  /// Connection type (wifi, cellular, none)
  static const connectionType = 'connection_type';

  // === General ===

  /// Whether the action was successful
  static const success = 'success';

  /// Duration in milliseconds
  static const durationMs = 'duration_ms';

  /// Count of items
  static const count = 'count';
}
