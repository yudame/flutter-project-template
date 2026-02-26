# Stripe Payment Processing

This guide covers integrating Stripe payment processing into a Flutter app with a server backend. The architecture addresses the three-party relationship between mobile app, API server, and Stripe.

> **Always check official Stripe docs for the latest SDK versions and API changes.** Links are provided throughout and collected in the [Reference Links](#reference-links) section.

## Architecture Overview

```
┌──────────┐       ┌──────────┐       ┌──────────┐
│  Mobile   │◄─────►│   API    │◄─────►│  Stripe  │
│   App     │       │  Server  │       │          │
└──────────┘       └──────────┘       └──────────┘
   UI/UX            Business Logic     Payment Rail
   Collect card     Validate orders    Process charges
   Show status      Create intents     Store payment methods
   Cache state      Webhook handler    Subscription mgmt
```

**Critical principle: The mobile app NEVER talks directly to Stripe for server-side operations.** The app only uses Stripe's client SDK for secure card collection ([PaymentSheet](https://docs.stripe.com/payments/accept-a-payment?platform=react-native&ui=payment-sheet)) and 3D Secure confirmation.

## Ground Truth Ownership

The most important architectural decision is knowing **where each piece of data is authoritative**.

| Data | Ground Truth | Why |
|------|-------------|-----|
| Payment Intent status | **Stripe** | Only Stripe knows if a charge actually succeeded |
| Subscription status | **Stripe** | Billing cycles, trials, cancellations — Stripe manages the state machine |
| Customer record | **Stripe** | Payment methods, default sources, billing info |
| Price catalog | **Stripe** | Single source via [Products/Prices API](https://docs.stripe.com/api/prices), synced to server via webhooks |
| Receipts | **Stripe** | [Hosted invoice/receipt pages](https://docs.stripe.com/receipts) |
| Order/purchase record | **API Server** | What was bought, pricing rules, discounts applied |
| Entitlements/access | **API Server** | What features the user can access (derived from subscription status) |
| UI display state | **Mobile App** | Optimistic updates, loading states, cached status for offline |

### The Golden Rule

> **Stripe is ground truth for payment state. Your server is ground truth for business state. Your app is a read-through cache of both.**

The server listens to [Stripe webhooks](https://docs.stripe.com/webhooks) to keep its local state in sync. The app reads from the server. The app NEVER determines payment success from its own state — it always confirms with the server, which confirmed with Stripe.

## What Goes Where

### Mobile App (Flutter)

**Responsibilities:**
- Present Stripe [PaymentSheet](https://docs.stripe.com/payments/accept-a-payment?platform=react-native&ui=payment-sheet) for secure card collection
- Display payment status, subscription info, purchase history
- Handle [3D Secure / SCA](https://docs.stripe.com/payments/3d-secure) authentication (Stripe SDK manages this)
- Cache payment status locally for offline display
- Send purchase requests to API server (NOT to Stripe directly)

**Not responsible for:**
- Creating PaymentIntents (server does this)
- Validating prices or computing totals (server does this)
- Storing card numbers (Stripe SDK handles [PCI compliance](https://docs.stripe.com/security))
- Determining payment success independently (server confirms via webhooks)

**Key package:** [`flutter_stripe`](https://pub.dev/packages/flutter_stripe) — Stripe SDK for Flutter

### API Server

**Responsibilities:**
- Create Stripe [Customers](https://docs.stripe.com/api/customers) linked to app users
- Create [PaymentIntents](https://docs.stripe.com/api/payment_intents) / [SetupIntents](https://docs.stripe.com/api/setup_intents) with correct amounts
- Validate orders, apply business rules (discounts, limits, eligibility)
- Manage [Subscriptions](https://docs.stripe.com/api/subscriptions) (create, update, cancel)
- Receive and process [webhooks](https://docs.stripe.com/webhooks) (the critical sync mechanism)
- Maintain local payment/subscription state (synced from webhooks)
- Expose REST endpoints for the app to query payment status
- Enforce entitlements based on subscription status

**Webhook-driven state sync:**

```
Stripe Event                      → Server Action
────────────────────────────────  → ──────────────────────────────
payment_intent.succeeded          → Mark order as paid, grant access
payment_intent.payment_failed     → Mark order as failed, notify user
customer.subscription.created     → Record subscription, grant tier
customer.subscription.updated     → Update tier, handle plan changes
customer.subscription.deleted     → Revoke access, handle grace period
invoice.paid                      → Extend subscription period
invoice.payment_failed            → Flag account, start dunning
```

See [Stripe webhook event types](https://docs.stripe.com/api/events/types) for the complete list.

### Stripe

**Manages:**
- PCI-compliant card storage and tokenization
- Payment processing and settlement
- Subscription billing cycles and retry logic
- 3D Secure / SCA authentication
- Receipts and invoices
- Dispute management

## Payment Flows

### One-Time Payment

```
App                          Server                      Stripe
 │                              │                           │
 │  1. POST /checkout           │                           │
 │  {items, quantities}  ──────►│                           │
 │                              │  2. Validate + total       │
 │                              │  3. Create PaymentIntent  │
 │                              │  {amount, currency} ─────►│
 │                              │  ◄── client_secret ───────│
 │  ◄── {client_secret} ───────│                           │
 │                              │                           │
 │  4. Stripe PaymentSheet      │                           │
 │     (card + 3DS)  ──────────────────────────────────────►│
 │  ◄── confirmation ──────────────────────────────────────│
 │                              │                           │
 │                              │  ◄── webhook: succeeded ──│
 │                              │  5. Mark paid, grant access│
 │                              │                           │
 │  6. Poll /status ───────────►│                           │
 │  ◄── {paid} ────────────────│                           │
```

**Why the app polls the server (step 6):** The Stripe SDK confirmation tells the app "payment was submitted." The definitive "payment succeeded" comes from the webhook. In most cases they align instantly, but edge cases (bank delays, fraud checks) mean the app should confirm with the server.

See: [Accept a payment](https://docs.stripe.com/payments/accept-a-payment)

### Subscription

```
App                          Server                      Stripe
 │                              │                           │
 │  1. GET /plans ─────────────►│  (cached from Stripe)    │
 │  ◄── [{plans}] ────────────│                           │
 │                              │                           │
 │  2. POST /subscriptions     │                           │
 │  {plan_id} ────────────────►│  3. Create Subscription  │
 │                              │  {customer, price} ──────►│
 │                              │  ◄── client_secret ───────│
 │  ◄── {client_secret} ───────│                           │
 │                              │                           │
 │  4. PaymentSheet ───────────────────────────────────────►│
 │                              │  ◄── webhook: sub.created │
 │                              │  5. Grant tier access      │
 │                              │                           │
 │  6. GET /subscription ──────►│                           │
 │  ◄── {tier, expires_at} ────│                           │
```

See: [Build a subscriptions integration](https://docs.stripe.com/billing/subscriptions/build-subscriptions)

## Server API Contract

Your API server must implement these endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/payments/plans` | List available plans/products (cached from Stripe) |
| POST | `/payments/checkout` | Create PaymentIntent, return `client_secret` |
| GET | `/payments/status/{intent_id}` | Check payment status |
| POST | `/subscriptions` | Create subscription, return `client_secret` |
| GET | `/subscriptions/status` | Current subscription status + tier |
| DELETE | `/subscriptions` | Cancel subscription (at period end) |
| GET | `/payments/history` | Payment history for current user |
| POST | `/webhooks/stripe` | Stripe webhook receiver (verify signature!) |

### Webhook Verification

Always verify webhook signatures. Never trust unverified webhook payloads.

```python
# Python/Django example
import stripe

@csrf_exempt
def stripe_webhook(request):
    payload = request.body
    sig_header = request.META['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = settings.STRIPE_WEBHOOK_SECRET

    event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    # Process event...
```

See: [Verify webhook signatures](https://docs.stripe.com/webhooks#verify-official-libraries)

## Flutter Integration Pattern

### Setup

```dart
// In main.dart or DI setup
import 'package:flutter_stripe/flutter_stripe.dart';

void main() {
  Stripe.publishableKey = env['STRIPE_PUBLISHABLE_KEY']!;
  // Optionally set merchant identifier for Apple Pay:
  // Stripe.merchantIdentifier = 'merchant.com.yourapp';
  runApp(MyApp());
}
```

### PaymentSheet Flow

```dart
// 1. Request checkout session from YOUR server
final response = await dio.post('/payments/checkout', data: {
  'items': [{'id': 'item_123', 'quantity': 1}],
});

final clientSecret = response.data['client_secret'];
final customerId = response.data['customer_id'];
final ephemeralKey = response.data['ephemeral_key'];

// 2. Initialize PaymentSheet with server response
await Stripe.instance.initPaymentSheet(
  paymentSheetParameters: SetupPaymentSheetParameters(
    paymentIntentClientSecret: clientSecret,
    customerEphemeralKeySecret: ephemeralKey,
    customerId: customerId,
    merchantDisplayName: 'Your App Name',
  ),
);

// 3. Present PaymentSheet (Stripe handles card input + 3DS)
await Stripe.instance.presentPaymentSheet();

// 4. Poll your server for confirmed status
final status = await dio.get('/payments/status/${intentId}');
```

See: [`flutter_stripe` package docs](https://pub.dev/packages/flutter_stripe)

### BLoC Pattern (Example)

Following the template's BLoC conventions:

```dart
// payment_event.dart
@freezed
class PaymentEvent with _$PaymentEvent {
  const factory PaymentEvent.plansRequested() = PlansRequested;
  const factory PaymentEvent.checkoutStarted(CheckoutRequest request) = CheckoutStarted;
  const factory PaymentEvent.paymentConfirmed(String intentId) = PaymentConfirmed;
  const factory PaymentEvent.subscriptionRequested(String planId) = SubscriptionRequested;
  const factory PaymentEvent.subscriptionCancelled() = SubscriptionCancelled;
  const factory PaymentEvent.statusRefreshRequested() = StatusRefreshRequested;
}
```

```dart
// payment_state.dart
@freezed
class PaymentState with _$PaymentState {
  const factory PaymentState.initial() = PaymentInitial;
  const factory PaymentState.loading() = PaymentLoading;
  const factory PaymentState.plansLoaded(List<PaymentPlan> plans) = PlansLoaded;
  const factory PaymentState.checkoutReady(CheckoutSession session) = CheckoutReady;
  const factory PaymentState.processing() = PaymentProcessing;
  const factory PaymentState.succeeded(PaymentRecord record) = PaymentSucceeded;
  const factory PaymentState.failed(String error) = PaymentFailed;
  const factory PaymentState.subscriptionActive(SubscriptionStatus status) = SubscriptionActive;
  const factory PaymentState.subscriptionInactive() = SubscriptionInactive;
}
```

### Repository Interface (Example)

```dart
abstract class PaymentRepository {
  Future<Result<List<PaymentPlan>>> getPlans();
  Future<Result<CheckoutSession>> createCheckout(CheckoutRequest request);
  Future<Result<PaymentStatus>> getPaymentStatus(String intentId);
  Future<Result<SubscriptionStatus>> getSubscriptionStatus();
  Future<Result<CheckoutSession>> createSubscription(String planId);
  Future<Result<void>> cancelSubscription();
  Future<Result<List<PaymentRecord>>> getPaymentHistory();
}
```

### Models (Example)

```dart
@freezed
class PaymentPlan with _$PaymentPlan {
  const factory PaymentPlan({
    required String id,
    required String name,
    required int priceInCents,  // Always smallest currency unit
    required String currency,
    required String interval,    // 'month', 'year'
    required List<String> features,
  }) = _PaymentPlan;

  factory PaymentPlan.fromJson(Map<String, dynamic> json) =>
      _$PaymentPlanFromJson(json);
}

@freezed
class CheckoutSession with _$CheckoutSession {
  const factory CheckoutSession({
    required String clientSecret,
    required String paymentIntentId,
    String? ephemeralKey,
    String? customerId,
  }) = _CheckoutSession;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      _$CheckoutSessionFromJson(json);
}

@freezed
class SubscriptionStatus with _$SubscriptionStatus {
  const factory SubscriptionStatus({
    required String tier,
    required String status,  // 'active', 'past_due', 'canceled', 'trialing'
    required DateTime currentPeriodEnd,
    required bool cancelAtPeriodEnd,
  }) = _SubscriptionStatus;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionStatusFromJson(json);
}
```

### Connectivity-Aware Status Caching

Following the template's offline-first pattern:

```dart
class PaymentRepositoryImpl implements PaymentRepository {
  final DioClient _dio;
  final LocalCacheService _cache;
  final ConnectivityBloc _connectivity;

  @override
  Future<Result<SubscriptionStatus>> getSubscriptionStatus() async {
    switch (_connectivity.state.status) {
      case ConnectivityState.online:
        final response = await _dio.get('/subscriptions/status');
        final status = SubscriptionStatus.fromJson(response.data);
        await _cache.put('payments', 'subscription', status.toJson());
        return Result.success(status);

      case ConnectivityState.poor:
        try {
          final response = await _dio.get('/subscriptions/status')
              .timeout(const Duration(seconds: 5));
          final status = SubscriptionStatus.fromJson(response.data);
          await _cache.put('payments', 'subscription', status.toJson());
          return Result.success(status);
        } catch (_) {
          return _getCachedSubscription();
        }

      case ConnectivityState.offline:
        return _getCachedSubscription();
    }
  }
}
```

## Security Considerations

### PCI Compliance

Using Stripe's client SDK (PaymentSheet, CardField) means your app **never handles raw card numbers**. Card data goes directly from the user's device to Stripe's servers. This keeps you out of PCI scope.

- Never build custom card input fields
- Never log or store card numbers
- Always use Stripe's pre-built UI components

See: [Stripe PCI compliance](https://docs.stripe.com/security)

### Idempotency

Always use [idempotency keys](https://docs.stripe.com/api/idempotent_requests) when creating PaymentIntents to prevent double charges:

```python
# Server-side
stripe.PaymentIntent.create(
    amount=2000,
    currency='usd',
    idempotency_key=f'order_{order_id}',
)
```

### Webhook Security

- Always [verify webhook signatures](https://docs.stripe.com/webhooks#verify-official-libraries)
- Use HTTPS endpoints only
- Respond with 200 quickly, process asynchronously if needed
- Handle duplicate events (webhooks can be retried)

## Testing

### Stripe Test Mode

Stripe provides a complete test environment. No real money is ever charged.

**Test card numbers** ([full list](https://docs.stripe.com/testing#cards)):

| Number | Scenario |
|--------|----------|
| `4242 4242 4242 4242` | Successful payment |
| `4000 0025 0000 3155` | Requires 3D Secure |
| `4000 0000 0000 9995` | Declined (insufficient funds) |
| `4000 0000 0000 0002` | Declined (generic) |

### Local Webhook Testing

Use [Stripe CLI](https://docs.stripe.com/stripe-cli) to forward webhooks to your local server:

```bash
stripe listen --forward-to localhost:8000/webhooks/stripe
```

### Test Clocks

For subscription testing, use [test clocks](https://docs.stripe.com/billing/testing/test-clocks) to simulate time passing (billing cycles, trial expiration, etc.) without waiting.

### App-Side Testing

Mock the server responses and StripeService in BLoC tests:

```dart
blocTest<PaymentBloc, PaymentState>(
  'emits [loading, checkoutReady] when checkout succeeds',
  build: () {
    when(() => repo.createCheckout(any()))
        .thenAnswer((_) async => Result.success(mockSession));
    return PaymentBloc(repository: repo, stripeService: stripeService);
  },
  act: (bloc) => bloc.add(CheckoutStarted(request)),
  expect: () => [
    const PaymentLoading(),
    CheckoutReady(mockSession),
  ],
);
```

## Edge Cases & Failure Modes

| Scenario | How to Handle |
|----------|---------------|
| **Webhook fails but payment succeeded** | Server must reconcile by [retrieving the PaymentIntent](https://docs.stripe.com/api/payment_intents/retrieve) from Stripe |
| **User closes app during 3D Secure** | PaymentIntent stays `requires_action`; server should handle abandoned intents |
| **Double-charge risk** | Use [idempotency keys](https://docs.stripe.com/api/idempotent_requests) on PaymentIntent creation |
| **Subscription renewal fails** | Stripe retries via [Smart Retries](https://docs.stripe.com/billing/revenue-recovery/smart-retries); server handles `invoice.payment_failed` webhook |
| **Offline display** | Cache last-known subscription status; don't gate sensitive access on cached state alone |
| **Currency amounts** | Always use smallest unit (cents); never use floating point for money |
| **Price changes mid-subscription** | Existing subscriptions keep their price; new subscriptions get new price |
| **Refunds** | Process via server → Stripe API; handle `charge.refunded` webhook |

## Platform Policies

### iOS App Store

**If your app sells digital goods or services consumed within the app, Apple requires In-App Purchase (IAP).** Stripe is only permitted for:

- Physical goods and services
- Services consumed outside the app
- Person-to-person payments

See: [Apple App Store Review Guidelines §3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)

### Google Play Store

Similar restrictions apply. Digital goods consumed in-app must use Google Play Billing.

See: [Google Play billing policy](https://support.google.com/googleplay/android-developer/answer/9858738)

### Implications

If your app sells both physical and digital goods:
- Use Stripe for physical goods/services
- Use IAP for digital goods consumed in-app
- Your server must handle both payment systems

## Reference Links

### Flutter / Mobile SDK
- [`flutter_stripe` package](https://pub.dev/packages/flutter_stripe)
- [Stripe React Native SDK](https://docs.stripe.com/payments/accept-a-payment?platform=react-native) (upstream of flutter_stripe)
- [PaymentSheet integration](https://docs.stripe.com/payments/accept-a-payment?platform=react-native&ui=payment-sheet)
- [Mobile payment element](https://docs.stripe.com/payments/mobile-payment-element)

### Server-Side APIs
- [PaymentIntents API](https://docs.stripe.com/api/payment_intents)
- [SetupIntents API](https://docs.stripe.com/api/setup_intents)
- [Subscriptions API](https://docs.stripe.com/api/subscriptions)
- [Customers API](https://docs.stripe.com/api/customers)
- [Products API](https://docs.stripe.com/api/products)
- [Prices API](https://docs.stripe.com/api/prices)

### Webhooks
- [Webhooks overview](https://docs.stripe.com/webhooks)
- [Webhook event types](https://docs.stripe.com/api/events/types)
- [Verify webhook signatures](https://docs.stripe.com/webhooks#verify-official-libraries)
- [Stripe CLI for local testing](https://docs.stripe.com/stripe-cli)

### Guides
- [Accept a payment](https://docs.stripe.com/payments/accept-a-payment)
- [Build a subscriptions integration](https://docs.stripe.com/billing/subscriptions/build-subscriptions)
- [SCA / 3D Secure](https://docs.stripe.com/payments/3d-secure)
- [Idempotent requests](https://docs.stripe.com/api/idempotent_requests)
- [Test clocks](https://docs.stripe.com/billing/testing/test-clocks)
- [Test card numbers](https://docs.stripe.com/testing#cards)
- [PCI compliance](https://docs.stripe.com/security)
- [Receipts](https://docs.stripe.com/receipts)

### Platform Policies
- [Apple IAP requirements](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)
- [Google Play billing policy](https://support.google.com/googleplay/android-developer/answer/9858738)
