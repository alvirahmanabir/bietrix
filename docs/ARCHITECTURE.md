# Architecture

```
Presentation (features/**/presentation, core/widgets)
      | watches / calls
Application  (Riverpod providers & notifiers: session, booking draft, queries)
      | depends on interfaces only
Domain       (models, pure rules, abstract services)
      ^ implemented by
Data         (mock/ today -> api/ later)   <- selected in data/providers.dart only
```

## Layers

* **Models** (`domain/models`): immutable entities with `toJson/fromJson`; IDs are prefixed strings
  (`usr_`, `pkg_`, `svc_`, `bk_`, `cpn_`, `sup_`); money is **integer BDT**; dates are ISO-8601.
  `Booking` references the customer, optional package (null = custom), a snapshot of
  `BookingItem`s, schedule, location, contact, coupon snapshot, pricing, payment, status,
  optional `Cancellation` and a status history.
* **Rules** (`domain/rules`): `PricingEngine`, `CouponValidator`, `BookingPolicy` (state machine),
  `RevenueCalculator`, `Permissions`. Pure Dart, unit-tested, portable to a backend.
* **Services** (`domain/services/services.dart`): `AuthService`, `UserService`, `PackageService`,
  `ServiceManagementService`, `BookingService`, `CouponService`, `WishlistService`, `PaymentService`,
  `SupportService`, `AdminService`, `AnalyticsService`. Reads are `watch*` streams (live updates);
  writes are Futures. Admin mutations take the acting `Session` and are permission-checked.
* **State**: `sessionProvider`, `bookingDraftProvider` (persisted), `builderSelectionProvider`,
  stream providers in `features/common/queries.dart`. Screens never talk to the mock DB directly.
* **Navigation**: `go_router` with a customer `StatefulShellRoute` (bottom nav), an admin `ShellRoute`
  (sidebar / drawer) and a pure, tested `redirectFor()` guard (guest / customer / admin + permission).
* **Errors**: sealed `Failure` types -> `ErrorHandler` (snackbars) and `ErrorView` (screens).
* **Design system**: tokens in `app/theme`, components in `core/widgets` (buttons, inputs, cards,
  badges, skeletons, empty/error states, dialogs, price summary).

## Performance choices
Skeleton loaders, `const` widgets, builder-based lists/grids, targeted `select()` rebuilds
(wishlist hearts), instant optimistic wishlist toggles, debounced admin search, no heavy animations,
small configurable mock latency.
