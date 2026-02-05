Add a new analytics event to the codebase.

## Input Required

Ask for:
- **Event name** (snake_case, e.g., `purchase_completed`, `tutorial_started`)
- **Description** (what user action triggers this)
- **Parameters** (what data should be captured)

## Process

### 1. Add Event Constant

Add to `lib/core/analytics/analytics_events.dart`:

```dart
class AnalyticsEvents {
  // ... existing events

  /// {Description of what triggers this event}
  static const myNewEvent = 'my_new_event';
}
```

### 2. Add Parameter Constants (if needed)

If the event uses new parameters, add to `AnalyticsParams`:

```dart
class AnalyticsParams {
  // ... existing params

  /// {Description of this parameter}
  static const myNewParam = 'my_new_param';
}
```

### 3. Show Usage Example

```dart
await analytics.logEvent(AnalyticsEvents.myNewEvent, {
  AnalyticsParams.myNewParam: value,
  AnalyticsParams.screenName: 'current_screen',
});
```

## Naming Conventions

### Event Names
- Use `snake_case`
- Start with noun or verb: `button_tapped`, `item_created`
- Be specific: `checkout_started` not `started`
- Keep under 40 characters

### Parameter Names
- Use `snake_case`
- Be descriptive: `item_type` not `type`
- Reuse existing params when applicable
- Keep under 40 characters

## Common Event Patterns

### User Actions
```dart
static const featureNameTapped = 'feature_name_tapped';
static const featureNameEnabled = 'feature_name_enabled';
static const featureNameDisabled = 'feature_name_disabled';
```

### Lifecycle Events
```dart
static const featureNameStarted = 'feature_name_started';
static const featureNameCompleted = 'feature_name_completed';
static const featureNameCancelled = 'feature_name_cancelled';
static const featureNameFailed = 'feature_name_failed';
```

### CRUD Events
```dart
static const itemTypeCreated = 'item_type_created';
static const itemTypeViewed = 'item_type_viewed';
static const itemTypeUpdated = 'item_type_updated';
static const itemTypeDeleted = 'item_type_deleted';
```

## Reminder

After adding the event:
1. Document in your analytics event catalog (if maintaining one)
2. Inform team members about the new event
3. Test that the event fires correctly
