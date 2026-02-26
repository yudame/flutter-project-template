# Stripe Payment Processing Plan

## Goal

Add Stripe payment processing architecture documentation and starter code to the template. The key challenge is defining **where each concern lives** in a three-party system (mobile app, API server, Stripe) and **where ground truth resides** for each piece of data.

## The Three-Party Problem

Payment processing creates a unique architectural challenge. Unlike auth or data sync (two parties), payments involve three:

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

**Critical principle: The mobile app NEVER talks directly to Stripe for server-side operations.** The app only uses Stripe's client SDK for secure card collection (Elements/PaymentSheet) and 3D Secure confirmation.

## Ground Truth Ownership

| Data | Ground Truth | Why |
|------|-------------|-----|
| **Payment Intent status** | Stripe | Stripe is the payment rail — only it knows if a charge succeeded |
| **Subscription status** | Stripe | Billing cycles, trials, cancellations — Stripe manages the state machine |
| **Customer record** | Stripe | Payment methods, default sources, billing info |
| **Order/purchase record** | API Server | Business logic: what was bought, pricing rules, discounts applied |
| **Entitlements/access** | API Server | What features/content the user can access (derived from subscription status) |
| **UI display state** | Mobile App | Optimistic updates, loading states, cached status for offline |
| **Price catalog** | Stripe (Products/Prices API) | Single source for pricing, synced to server via webhooks |
| **Receipts** | Stripe | Hosted invoice/receipt pages |

### The Golden Rule

> **Stripe is ground truth for payment state. Your server is ground truth for business state. Your app is a read-through cache of both.**

The server listens to Stripe webhooks to keep its local state in sync. The app reads from the server. The app NEVER determines payment success from its own state — it always confirms with the server, which confirmed with Stripe.

## Architecture by Responsibility

### Mobile App (Flutter)

**What it does:**
- Presents Stripe PaymentSheet / CardField for secure card collection
- Displays payment status, subscription info, purchase history
- Handles 3D Secure / SCA authentication flows (Stripe SDK manages this)
- Caches payment status locally for offline display
- Sends purchase requests to API server (NOT to Stripe directly)

**What it does NOT do:**
- Create PaymentIntents (server does this)
- Validate prices or compute totals (server does this)
- Store raw card numbers (Stripe SDK handles PCI compliance)
- Determine payment success independently (server confirms via webhooks)

**Key packages:**
- `flutter_stripe` — Stripe SDK for Flutter (PaymentSheet, CardField, 3DS)

### API Server

**What it does:**
- Creates Stripe Customers (linked to app users)
- Creates PaymentIntents / SetupIntents with correct amounts
- Validates orders, applies business rules (discounts, limits, eligibility)
- Manages Stripe Subscriptions (create, update, cancel)
- Receives and processes Stripe webhooks (the critical sync mechanism)
- Maintains local payment/subscription state (synced from webhooks)
- Exposes REST endpoints for the app to query payment status
- Enforces entitlements based on subscription status

**Webhook-driven state sync:**
```
Stripe Event                    → Server Action
─────────────────────────────── → ──────────────────────────
payment_intent.succeeded        → Mark order as paid, grant access
payment_intent.payment_failed   → Mark order as failed, notify user
customer.subscription.created   → Record subscription, grant tier access
customer.subscription.updated   → Update tier, handle plan changes
customer.subscription.deleted   → Revoke access, handle grace period
invoice.paid                    → Extend subscription period
invoice.payment_failed          → Flag account, start dunning
```

### Stripe

**What it manages:**
- PCI-compliant card storage and tokenization
- Payment processing and settlement
- Subscription billing cycles and retry logic
- 3D Secure / SCA authentication
- Receipts and invoices
- Dispute management

## Payment Flows

### One-Time Payment Flow

```
App                          Server                      Stripe
 │                              │                           │
 │  1. POST /checkout           │                           │
 │  {items, quantities}  ──────►│                           │
 │                              │  2. Validate order         │
 │                              │  3. Calculate total        │
 │                              │                           │
 │                              │  4. Create PaymentIntent  │
 │                              │  {amount, currency} ─────►│
 │                              │                           │
 │                              │  ◄── client_secret ───────│
 │  ◄── {client_secret} ───────│                           │
 │                              │                           │
 │  5. Stripe PaymentSheet      │                           │
 │     (card entry + 3DS)  ────────────────────────────────►│
 │                              │                           │
 │  ◄── confirmation ──────────────────────────────────────│
 │                              │                           │
 │                              │  ◄── webhook: succeeded ──│
 │                              │  6. Mark order paid        │
 │                              │  7. Grant entitlements     │
 │                              │                           │
 │  8. GET /orders/{id}/status  │                           │
 │  ────────────────────────────►                           │
 │  ◄── {status: paid} ────────│                           │
 │                              │                           │
 │  9. Show success UI          │                           │
```

**Why the app checks the server (step 8), not just the SDK response:**
The Stripe SDK confirmation (step 6) tells the app "payment was submitted." But the definitive "payment succeeded" comes from the webhook. In most cases they align instantly, but edge cases (bank delays, fraud checks) mean the app should poll/confirm with the server.

### Subscription Flow

```
App                          Server                      Stripe
 │                              │                           │
 │  1. GET /plans               │                           │
 │  ────────────────────────────►  (cached from Stripe     │
 │  ◄── [{plan_id, price}] ────│   Products/Prices API)   │
 │                              │                           │
 │  2. POST /subscriptions      │                           │
 │  {plan_id}  ────────────────►│                           │
 │                              │  3. Create/get Customer   │
 │                              │  4. Create Subscription   │
 │                              │  {customer, price} ──────►│
 │                              │                           │
 │                              │  ◄── client_secret ───────│
 │  ◄── {client_secret} ───────│                           │
 │                              │                           │
 │  5. Confirm payment          │                           │
 │     (PaymentSheet)  ────────────────────────────────────►│
 │                              │                           │
 │                              │  ◄── webhook: sub.created │
 │                              │  6. Grant tier access      │
 │                              │                           │
 │  7. GET /subscription/status │                           │
 │  ────────────────────────────►                           │
 │  ◄── {tier, expires_at} ────│                           │
```

## Deliverables

### 1. Documentation (`docs/payments.md`)

Comprehensive payment integration guide covering:
- Three-party architecture explanation
- Ground truth ownership table
- Payment flows with sequence diagrams
- Server requirements and webhook setup
- Mobile app integration with flutter_stripe
- Security considerations (PCI compliance, idempotency)
- Testing strategy (Stripe test mode, mock server)
- Common pitfalls and edge cases

### 2. Mobile App Code (Committed)

#### `lib/core/payments/payment_repository.dart`
Abstract interface defining the contract:
```dart
abstract class PaymentRepository {
  /// Fetch available plans/products from server
  Future<Result<List<PaymentPlan>>> getPlans();

  /// Request a checkout session from server, returns client secret
  Future<Result<CheckoutSession>> createCheckout(CheckoutRequest request);

  /// Confirm payment was processed (poll server after Stripe confirmation)
  Future<Result<PaymentStatus>> getPaymentStatus(String paymentIntentId);

  /// Get current subscription status
  Future<Result<SubscriptionStatus>> getSubscriptionStatus();

  /// Request subscription creation, returns client secret
  Future<Result<CheckoutSession>> createSubscription(String planId);

  /// Cancel subscription
  Future<Result<void>> cancelSubscription();

  /// Get payment history
  Future<Result<List<PaymentRecord>>> getPaymentHistory();
}
```

#### `lib/core/payments/payment_models.dart`
Freezed models:
- `PaymentPlan` — id, name, price, interval, features
- `CheckoutSession` — clientSecret, paymentIntentId, ephemeralKey, customerId
- `PaymentStatus` — enum: pending, processing, succeeded, failed, refunded
- `SubscriptionStatus` — tier, status, currentPeriodEnd, cancelAtPeriodEnd
- `PaymentRecord` — id, amount, currency, status, createdAt, description
- `CheckoutRequest` — items, quantities, metadata

#### `lib/core/payments/payment_bloc.dart`
BLoC for payment state management:

Events:
- `PlansRequested` — fetch available plans
- `CheckoutStarted(CheckoutRequest)` — initiate payment
- `PaymentConfirmed(paymentIntentId)` — app confirms after Stripe SDK
- `SubscriptionRequested(planId)` — start subscription
- `SubscriptionCancelled` — cancel subscription
- `StatusRefreshRequested` — poll current status

States:
- `PaymentInitial`
- `PaymentLoading`
- `PlansLoaded(plans)`
- `CheckoutReady(session)` — has client_secret, ready for PaymentSheet
- `PaymentProcessing` — waiting for server confirmation
- `PaymentSucceeded(record)`
- `PaymentFailed(error)`
- `SubscriptionActive(status)`
- `SubscriptionInactive`

#### `lib/core/payments/stripe_service.dart`
Thin wrapper around flutter_stripe for testability:
```dart
class StripeService {
  Future<void> initialize(String publishableKey);
  Future<PaymentSheetResult> presentPaymentSheet(CheckoutSession session);
  Future<void> confirmPayment(String clientSecret);
}
```

### 3. Server Contract Documentation

Document the **required API endpoints** the server must implement:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/payments/plans` | List available plans/products |
| POST | `/payments/checkout` | Create PaymentIntent, return client_secret |
| GET | `/payments/status/{intent_id}` | Check payment status |
| POST | `/subscriptions` | Create subscription |
| GET | `/subscriptions/status` | Current subscription status |
| DELETE | `/subscriptions` | Cancel subscription |
| GET | `/payments/history` | Payment history |
| POST | `/webhooks/stripe` | Stripe webhook receiver |

Document the **required webhook handlers** the server must implement.

### 4. Claude Commands

#### `.claude/commands/add-payments.md`
- Install flutter_stripe package
- Register StripeService and PaymentRepository in get_it
- Add Stripe publishable key to environment config
- Scaffold payment UI pages

### 5. Tests

#### `test/core/payments/payment_bloc_test.dart`
- Plans loading (success, failure)
- Checkout flow (create → confirm → success/failure)
- Subscription flow (create → active → cancel)
- Status polling
- Error handling

### 6. Update Sphinx Docs
- Add payments.md to sphinx source
- Update index.rst with Payments section under Core Systems

## What We're NOT Doing

- **No server implementation** — This is a Flutter template. We document the server contract.
- **No Apple/Google IAP** — Stripe only. IAP is a separate concern (and required for digital goods on iOS).
- **No Stripe Connect** — Marketplace/platform payments are out of scope.
- **No invoicing** — Simple checkout and subscription only.
- **No real Stripe API calls in tests** — Mock the server, mock StripeService.

## Structure After Implementation

```
lib/core/payments/
├── payment_repository.dart    # Abstract interface
├── payment_models.dart        # Freezed models (plan, status, session, record)
├── payment_models.freezed.dart
├── payment_models.g.dart
├── payment_bloc.dart          # BLoC (events + states + logic)
├── payment_event.dart         # Freezed events
├── payment_state.dart         # Freezed states
└── stripe_service.dart        # Thin Stripe SDK wrapper

docs/
├── payments.md                # Comprehensive guide

test/core/payments/
└── payment_bloc_test.dart     # BLoC tests

.claude/commands/
└── add-payments.md            # Setup command
```

## Edge Cases to Document

1. **Payment succeeds on Stripe but webhook fails** — Server must be able to reconcile by querying Stripe API
2. **User closes app during 3D Secure** — PaymentIntent stays pending; server should handle abandoned intents
3. **Double-charge prevention** — Idempotency keys on PaymentIntent creation
4. **Subscription renewal failure** — Dunning (Stripe Smart Retries + webhook handling)
5. **Offline display** — Cache last-known subscription status, but don't gate features purely on cached state for sensitive access
6. **Currency handling** — Always use Stripe's smallest unit (cents), never floating point
7. **Price changes** — Existing subscriptions keep their price; new subscriptions get new price

## Dependencies

- Existing `Result<T>` pattern (committed)
- Existing BLoC patterns (committed)
- Existing `DioClient` for server communication (committed)
- Existing connectivity-aware repository pattern (committed)
- `flutter_stripe` package (to be added)

## Estimated Work

- Documentation: ~2 hours
- Models + Repository interface: ~1 hour
- BLoC + Events + States: ~1.5 hours
- StripeService wrapper: ~30 min
- Tests: ~1.5 hours
- Claude command + Sphinx: ~30 min
- **Total: ~6-7 hours**

## Open Questions

1. **iOS App Store policy**: If the app sells digital goods/services, Apple requires IAP (30% cut). Stripe is only allowed for physical goods/services or out-of-app purchases. This should be prominently documented.
2. **Should we include a payment UI example page?** Other features (auth, home) include example UI. A checkout page example would be consistent but adds scope.
