# Add Stripe Payment Processing

Set up Stripe payment processing in this Flutter project.

**Before starting:** Read `docs/payments.md` for the full architecture guide and ground truth ownership model.

## Steps

1. **Install flutter_stripe**
   ```bash
   flutter pub add flutter_stripe
   ```
   Check for latest version: https://pub.dev/packages/flutter_stripe

2. **Configure Stripe publishable key**

   Add to your `.env` files:
   ```
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

   Initialize in `main.dart`:
   ```dart
   import 'package:flutter_stripe/flutter_stripe.dart';

   void main() {
     Stripe.publishableKey = env['STRIPE_PUBLISHABLE_KEY']!;
     runApp(MyApp());
   }
   ```

3. **Create payment files**

   Create `lib/core/payments/` directory with:

   - `payment_repository.dart` — Abstract interface (see docs/payments.md for example)
   - `payment_models.dart` — Freezed models: PaymentPlan, CheckoutSession, SubscriptionStatus, PaymentRecord
   - `payment_event.dart` — Freezed BLoC events
   - `payment_state.dart` — Freezed BLoC states
   - `payment_bloc.dart` — Payment state management
   - `stripe_service.dart` — Thin wrapper around flutter_stripe for testability

   Follow the example code in `docs/payments.md` for each file.

4. **Run code generation**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Register in dependency injection**

   In `lib/core/di/injection.dart`:
   ```dart
   // Payment services
   getIt.registerLazySingleton<StripeService>(() => StripeService());
   // Register your PaymentRepository implementation when server is ready
   ```

6. **Implement server-side**

   Your API server needs these endpoints (see docs/payments.md for full contract):
   - `POST /payments/checkout` — Create PaymentIntent
   - `GET /payments/status/{id}` — Check payment status
   - `POST /subscriptions` — Create subscription
   - `GET /subscriptions/status` — Current status
   - `POST /webhooks/stripe` — Webhook receiver

   Server guides:
   - https://docs.stripe.com/payments/accept-a-payment
   - https://docs.stripe.com/billing/subscriptions/build-subscriptions
   - https://docs.stripe.com/webhooks

7. **Platform configuration**

   **Android** — Add to `android/app/src/main/AndroidManifest.xml` if needed for custom URL schemes.

   **iOS** — No additional configuration needed for basic PaymentSheet usage.

8. **Test with Stripe test mode**
   - Use test card: `4242 4242 4242 4242`
   - Use Stripe CLI for local webhook testing: `stripe listen --forward-to localhost:8000/webhooks/stripe`
   - Full test card list: https://docs.stripe.com/testing#cards

## Important Notes

- **Never store card numbers** — Use Stripe's PaymentSheet UI component
- **Always verify webhooks** — Check signatures server-side
- **Use idempotency keys** — Prevent double charges
- **Check platform policies** — iOS requires IAP for digital goods consumed in-app (see docs/payments.md)
- **Currency: use smallest unit** — Cents, not dollars. Never use floating point for money.

## Reference

- Full architecture guide: `docs/payments.md`
- flutter_stripe: https://pub.dev/packages/flutter_stripe
- Stripe API docs: https://docs.stripe.com/api
