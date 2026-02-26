# Stripe Payment Processing Plan

**Issue:** https://github.com/yudame/flutter-project-template/issues/11

## Goal

Add Stripe payment processing architecture documentation to the template. Define where each concern lives in the three-party system (mobile app, API server, Stripe), where ground truth resides, and reference official Stripe documentation so future developers can check for SDK updates.

This is a **documentation-only deliverable** — architecture guide, patterns, and references. No committed application code beyond example snippets in the docs.

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

**Critical principle: The mobile app NEVER talks directly to Stripe for server-side operations.** The app only uses Stripe's client SDK for secure card collection (PaymentSheet) and 3D Secure confirmation.

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

## Stripe Documentation References

These are the canonical sources. Always check for latest SDK versions and API changes.

### Flutter / Mobile SDK
- **flutter_stripe package**: https://pub.dev/packages/flutter_stripe
- **Stripe React Native SDK** (upstream of flutter_stripe): https://docs.stripe.com/payments/accept-a-payment?platform=react-native
- **PaymentSheet integration**: https://docs.stripe.com/payments/accept-a-payment?platform=react-native&ui=payment-sheet
- **Mobile payment element**: https://docs.stripe.com/payments/mobile-payment-element

### Server-Side
- **PaymentIntents API**: https://docs.stripe.com/api/payment_intents
- **Subscriptions API**: https://docs.stripe.com/api/subscriptions
- **Customers API**: https://docs.stripe.com/api/customers
- **Webhook events**: https://docs.stripe.com/webhooks
- **Webhook event types reference**: https://docs.stripe.com/api/events/types
- **Stripe CLI (local webhook testing)**: https://docs.stripe.com/stripe-cli

### Architecture & Best Practices
- **Accept a payment (full guide)**: https://docs.stripe.com/payments/accept-a-payment
- **Subscription integration guide**: https://docs.stripe.com/billing/subscriptions/build-subscriptions
- **SCA / 3D Secure**: https://docs.stripe.com/payments/3d-secure
- **Idempotent requests**: https://docs.stripe.com/api/idempotent_requests
- **Testing with test clocks**: https://docs.stripe.com/billing/testing/test-clocks
- **Stripe test card numbers**: https://docs.stripe.com/testing#cards

### Platform Policy (Important)
- **Apple IAP requirements**: https://developer.apple.com/app-store/review/guidelines/#in-app-purchase — If your app sells digital goods/services consumed within the app, Apple requires IAP. Stripe is only permitted for physical goods, services delivered outside the app, or person-to-person payments.
- **Google Play billing policy**: https://support.google.com/googleplay/android-developer/answer/9858738 — Similar restrictions for digital goods.

## Deliverables

### 1. Documentation (`docs/payments.md`)

Comprehensive payment architecture guide covering:

- Three-party architecture explanation with responsibility matrix
- Ground truth ownership table
- Payment flows with sequence diagrams (one-time + subscription)
- What the mobile app handles vs what the server handles
- Server API contract (required endpoints + webhook handlers)
- `flutter_stripe` setup and PaymentSheet integration pattern
- Connectivity-aware payment status caching (follows existing offline patterns)
- BLoC pattern for payment state (example code, not committed)
- Security considerations (PCI compliance, idempotency, webhook verification)
- Testing strategy (Stripe test mode, test cards, test clocks)
- Edge cases and failure modes
- Full Stripe documentation reference links (see above)
- iOS/Android platform policy warnings re: digital goods

### 2. Claude Command (`.claude/commands/add-payments.md`)

Step-by-step scaffolding guide that:
- Installs `flutter_stripe` package
- Creates `lib/core/payments/` directory with example files
- Registers services in get_it
- Adds Stripe publishable key to environment config
- References Stripe docs for server-side setup

### 3. Update Sphinx Docs
- Add payments.md to sphinx source
- Update index.rst with Payments section under Core Systems
- Update build scripts to copy payments.md

## What We're NOT Building

- **No committed app code** — This is a template. Example code lives in docs only.
- **No server implementation** — We document the server contract and link to Stripe's server guides.
- **No Apple/Google IAP** — Stripe only. IAP is a separate concern (document the policy boundary).
- **No Stripe Connect** — Marketplace/platform payments are out of scope.
- **No invoicing** — Simple checkout and subscription patterns only.

## Payment Flows to Document

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

## Server Contract to Document

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

## Edge Cases to Document

1. **Payment succeeds on Stripe but webhook fails** — Server must reconcile by querying Stripe API
2. **User closes app during 3D Secure** — PaymentIntent stays pending; handle abandoned intents
3. **Double-charge prevention** — Idempotency keys on PaymentIntent creation
4. **Subscription renewal failure** — Dunning (Stripe Smart Retries + webhook handling)
5. **Offline display** — Cache last-known subscription status; don't gate sensitive access on cached state alone
6. **Currency handling** — Always use Stripe's smallest unit (cents), never floating point
7. **Price changes** — Existing subscriptions keep their price; new subscriptions get new price

## Example Code Patterns (In Docs Only)

The documentation will include example snippets for:
- `PaymentRepository` abstract interface (follows existing template pattern)
- `PaymentBloc` events and states (Freezed, follows existing AuthBloc pattern)
- `StripeService` thin wrapper for testability
- Freezed models: `PaymentPlan`, `CheckoutSession`, `PaymentStatus`, `SubscriptionStatus`
- Connectivity-aware payment status caching

These are **reference examples** in markdown, not committed lib/ code.

## Implementation Order

1. Write `docs/payments.md` with all architecture, flows, examples, and Stripe doc links
2. Create `.claude/commands/add-payments.md`
3. Update Sphinx docs (index.rst, build scripts)
4. Commit and close issue

## Estimated Work

- Documentation: ~3 hours
- Claude command: ~30 min
- Sphinx integration: ~15 min
- **Total: ~4 hours**
