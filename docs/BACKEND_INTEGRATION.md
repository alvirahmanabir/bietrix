# Replacing the mock layer with a real backend

1. **Add an HTTP client** (e.g. `dio`) in `lib/data/api/api_client.dart`: base URL from
   `Env.apiBaseUrl`, bearer token injection, refresh-on-401, mapping of HTTP errors onto the
   `Failure` types (400/422 -> `ValidationFailure`, 401/403 -> `UnauthorizedFailure`,
   404 -> `NotFoundFailure`, 409 business conflicts -> `PolicyFailure`, I/O -> `NetworkFailure`).
2. **Implement the interfaces** in `lib/data/api/` (`ApiAuthService`, `ApiBookingService`, ...).
   They implement the same abstract classes in `domain/services/services.dart`.
3. **Switch them on** in `lib/data/providers.dart` (this is the only file that names concrete
   implementations), e.g. `Env.useMock ? MockBookingService(db) : ApiBookingService(client)`.
4. Keep `MockDatabase` for tests/demos. Nothing in `features/` needs to change.

## Endpoint map (suggested)

| Service method | REST |
|---|---|
| `AuthService.login / register / verifyOtp / resendOtp` | `POST /auth/login`, `/auth/register`, `/auth/verify-otp`, `/auth/resend-otp` |
| `requestPasswordReset / resetPassword` | `POST /auth/forgot-password`, `/auth/reset-password` |
| `UserService.watchUser / updateProfile / deleteAccount` | `GET/PATCH/DELETE /me` (email not patchable) |
| `UserService.watchCustomers` | `GET /admin/customers?q=&status=` |
| `PackageService` | `GET /packages`, `POST/PUT/DELETE /admin/packages/:id` |
| `ServiceManagementService` | `GET /services`, `POST/PUT/DELETE /admin/services/:id` |
| `BookingService.create / freeSlots / fullyBookedDates` | `POST /bookings`, `GET /availability?date=` , `GET /availability/blocked` |
| `watchCustomerBookings / watchBooking` | `GET /me/bookings`, `GET /bookings/:id` |
| `watchAllBookings` | `GET /admin/bookings?q=&status=&eventDate=&page=&pageSize=` -> `Paginated` |
| `cancelByCustomer` | `POST /bookings/:id/cancel` |
| `confirm / cancelByAdmin / complete` | `POST /admin/bookings/:id/confirm`, `/cancel`, `/complete` |
| `CouponService.validate / watchAll / save / delete` | `POST /coupons/validate`, `GET /coupons`, `/admin/coupons` |
| `WishlistService` | `GET /me/wishlist`, `PUT/DELETE /me/wishlist/:packageId` |
| `PaymentService.charge` | `POST /payments/intents` + gateway SDK/redirect + webhook |
| `SupportService` | `POST /support-requests`, `GET/PATCH /admin/support-requests`, `POST .../notes` |
| `AnalyticsService` | `GET /admin/analytics/dashboard`, `/admin/analytics/revenue` |

## What the backend MUST enforce (never trust the client)

* **Booking lifecycle**: same transition table as `BookingPolicy` (customer may cancel only
  *Pending Confirmation*; once confirmed only an admin can cancel). Return 409 on violations.
* **Pricing**: ignore any client-sent prices. Recompute from the catalogue; store the item/price
  snapshot, coupon snapshot and totals on the booking.
* **Coupons**: re-run the full `CouponValidator` rule order inside the booking transaction
  (expiry, active, min order, total + per-user limits) and increment usage atomically.
* **Slots**: reject double-booking atomically (unique constraint on date + slot for non-cancelled bookings).
* **RBAC**: enforce the `Permissions` matrix on every `/admin/**` endpoint from the token's role claim.
* **Profile**: registered email is immutable; admins cannot edit customer profile data.
* **Account deletion**: erase/anonymise personal data, cancel pending bookings, revoke tokens.
* **Passwords/OTP**: hash passwords, expire and rate-limit OTPs; never reveal whether an email exists.

## Real-time updates
`watch*` methods return `Stream`s. Implement them with SSE/WebSocket (or short polling to start)
so order status changes pushed by an admin reach the customer immediately.

## Payments
`PaymentService.charge` is a simulator. In production create a payment intent on the server,
open the gateway (bKash / Nagad / card) via its SDK or hosted page, and confirm via webhook.
Prefer creating the booking first (payment pending) and marking it paid from the webhook, so a
failed booking never follows a successful charge.

## Images
`MockImage` renders gradients from an `imageKey`. Add an upload endpoint (signed URLs to cloud
storage), store the returned URL in `imageKey` (or a new `imageUrl`), and swap `MockImage` for
`Image.network` / `cached_network_image`.

## Tokens & storage
`LocalStore` is a plain key/value store. Keep tokens in `flutter_secure_storage` when real auth lands.
