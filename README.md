# JamCon - Digital Studio Management & Booking Platform

Flutter frontend (customer mobile app **and** admin dashboard) backed by a **mock data layer**.
No real backend, database or payment gateway is used in this phase - but the architecture is
built so they can be plugged in without touching UI code (see `docs/BACKEND_INTEGRATION.md`).

## Setup

```bash
flutter pub get
flutter analyze
flutter test
flutter run                      # phone/emulator -> customer app
flutter run -d chrome            # web -> admin dashboard is fully responsive
```

The same app contains both interfaces: customers land on the customer app; the admin portal is
reached from the Welcome screen ("Studio admin portal") or directly at `/admin/login`.
Customer and admin share one in-process mock database, so an admin confirming an order is
instantly visible on the customer's order screen.

### Demo accounts

| Role | Email | Password |
|---|---|---|
| Customer (has orders in every status) | `demo@jamcon.app` | `demo123` |
| Super Admin | `super@jamcon.app` | `admin123` |
| Admin | `admin@jamcon.app` | `admin123` |
| Order Manager | `orders@jamcon.app` | `admin123` |
| Customer Support | `support@jamcon.app` | `admin123` |

Mock OTP code: `123456`. Online payment simulator: any 4+ digits succeed, credentials ending in
`0000` fail. Coupons to try: `WELCOME10`, `FLAT2000`, `VIP5000`, `EID25` (expired), `SOLDOUT`
(limit reached), `PAUSED` (inactive).

### Configuration (`--dart-define`)

| Key | Default | Purpose |
|---|---|---|
| `USE_MOCK` | `true` | choose mock vs API implementations |
| `API_BASE_URL` | `https://api.example.com/v1` | future REST base URL |
| `APP_NAME` | `JamCon` | brand name |
| `MOCK_LATENCY_MS` | `150` | simulated network delay |

Data is persisted in local storage. To reset the demo data, clear the app's storage (or call
`MockDatabase.reset()`).

## Project structure

```
lib/
  app/        config (Env), router + role guards, theme (design tokens)
  core/       errors (Failure types), utils (formatters, validators, pagination), storage, shared widgets
  domain/     models/ (entities)  rules/ (pricing, coupons, cancellation policy, revenue, permissions)
              services/ (abstract service contracts the UI depends on)
  data/       mock/ (MockDatabase, seed, mock services)  api/ (future HTTP client)  providers.dart
  features/   auth/  customer/ (home, packages, builder, booking, orders, profile)  admin/  common/
test/         domain rules, mock services, route guards, app smoke test
docs/         ARCHITECTURE.md, BACKEND_INTEGRATION.md
```

## Key business rules (enforced in `domain/rules`, not just in the UI)

* New bookings are always **Pending Confirmation**.
* A customer can cancel only while Pending. Once the admin confirms, only an admin can cancel.
* Cancellations record who, when and why and are shown on the order page.
* Prices and coupon discounts are recomputed server-side (in the service) from the catalogue;
  custom packages store a price **snapshot**, so later price edits never change old bookings.
* A customer's registered email can never be changed.
* Admin actions are permission-checked per role (Super Admin / Admin / Order Manager / Customer Support).
* Realized revenue = Completed orders; Confirmed = upcoming; Pending and Cancelled are excluded.

## Notes

* Images are offline gradient placeholders (`MockImage`); the admin "upload" picks from preset keys.
  Replace with cloud-storage URLs when the upload service exists.
* Privacy / Terms text is sample copy.
* The admin sidebar shows at >= 1024 px wide; below that it becomes a drawer.
