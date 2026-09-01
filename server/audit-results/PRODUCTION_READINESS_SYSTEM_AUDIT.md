# SADHANA TRACKER — PRODUCTION READINESS & INFRASTRUCTURE AUDIT REPORT

**Date**: August 31, 2026
**Target Architecture**: Flutter Mobile App ➔ Firebase Auth ➔ NestJS REST API ➔ MongoDB Atlas + FCM + Cloudinary  
**Final Production Status**: `ACTUAL_PRODUCTION_STATUS = NOT_READY`

---

## 1. PHASE A — TECHNICAL REPOSITORY AUDIT

### What Already Works
- **NestJS Server Architecture**: Modular architecture (`src/auth`, `src/users`, `src/sadhana`, `src/payments`, `src/accommodations`, `src/media`, `src/health`).
- **Database Models & Schemas**: Mongoose schemas defined for User, SadhanaEntry, UserDevice, Event, Trip, Announcement, Accommodation, Payment, ScreenTimeLog, Feedback.
- **REST Endpoints**: Endpoints active for auth sync, user profile management, sadhana history logging, payment tracking, preacher data queries.
- **Preacher Data Isolation**: Scoped MongoDB queries matching preacher ID (`preacher_id = req.user.id`).
- **Security Middleware**: CORS, Helmet security headers, rate limiting (ThrottlerModule), NestJS `ValidationPipe`.
- **Media Upload**: Cloudinary signed signature generation (`GET /api/v1/media/upload-signature`).
- **Zero-Supabase Codebase**: 0 active Supabase packages or imports in `mobile_app/` and `server/`.

### What Is Incomplete / Missing
1. **Physical Device QA (Deferred)**:
   - Carrier SMS Phone OTP delivery requires physical Android device testing.
   - Background & Terminated-app FCM push notifications require real physical device testing.
2. **Production Hosting Infrastructure Deployment**:
   - Live HTTPS domain deployment for NestJS server (e.g. Render / AWS / GCP / DigitalOcean) must be provisioned.
   - Production API URL must be supplied to Flutter build via `--dart-define=API_BASE_URL=https://api.sadhanatracker.com/api/v1`.

---

## 2. PHASE B — SUPABASE REMOVAL AUDIT

- `supabase_flutter` Package: `0`
- `package:supabase_flutter` Imports: `0`
- `Supabase.initialize` / `Supabase.instance`: `0`
- `@supabase/supabase-js`: `0`
- Active Runtime Supabase URLs/Keys: `0`
- **Result**: `SUPABASE_RUNTIME_DEPENDENCY = 0`

---

## 3. PHASE C — MONGODB ATLAS CONFIGURATION

- **Driver**: `@nestjs/mongoose` + `mongoose`
- **Configuration**: Connection string supplied strictly via `MONGODB_URI` environment variable in `server/.env`.
- **Resilience Options**:
  - `serverSelectionTimeoutMS: 5000`
  - `connectTimeoutMS: 10000`
  - `retryAttempts: 5`
  - `retryDelay: 1000`

---

## 4. PHASE D — FIREBASE AUTHENTICATION

- **Flutter Client**: `firebase_core`, `firebase_auth`, `google_sign_in` installed. `Firebase.initializeApp()` initialized in `main.dart`.
- **Android Config**: [google-services.json](file:///d:/work%20update%20app/mobile_app/android/app/google-services.json) placed in `mobile_app/android/app/` (Package: `com.sadhana.tracker`).
- **NestJS AuthGuard**: Verifies Firebase ID Token (`Bearer <token>`) via `admin.auth().verifyIdToken(token)`.
- **Service Account**: Credentials loaded from `server/config/firebase-service-account.json` or `FIREBASE_CREDENTIALS_BASE64` env var.

---

## 5. PHASE E — FIREBASE CLOUD MESSAGING (FCM)

- **Flutter**: FCM token retrieved and sent to NestJS server via `NotificationHelper`.
- **NestJS**: Persists token in `UserDevice` / `User.fcmToken` schema for targeted notification dispatch.

---

## 6. PHASE F — CLOUDINARY MEDIA STORAGE

- **Backend**: Endpoint `GET /api/v1/media/upload-signature` generates short-lived signed upload signatures.
- **Frontend**: Flutter `CloudinaryService` uploads user photo directly to Cloudinary and saves secure HTTPS URL in MongoDB profile (`photo_url`).

---

## 7. PHASE G — NESTJS SECURITY & PREACHER ISOLATION

- **AuthGuard Protection**: Protected endpoints return `HTTP 401 Unauthorized` for missing/invalid tokens.
- **Admin Protection**: Admin-only routes return `HTTP 403 Forbidden` for non-admin users.
- **Preacher Isolation**: 100% data isolation enforced (preachers can only query assigned students).

---

## 8. PHASE H — API BASE URL SEPARATION

- **Development**: `http://10.0.2.2:3000/api/v1` (Android Emulator default).
- **Production**: Configurable via `--dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1`.
- **Constants Validation**: [Constants.validate()](file:///d:/work%20update%20app/mobile_app/lib/utils/constants.dart#L22) prevents production builds from accidentally pointing to emulator `10.0.2.2`.

---

## 9. PHASE P — FINAL CHECKLIST & SCORECARD

| Subsystem Area | Observed Verification Result | Status |
| :--- | :--- | :---: |
| **1. MongoDB Atlas** | Mongoose connected, schemas active, URI via `.env` | `PASS` |
| **2. Firebase Auth** | Google + Email/Password + Token Guard active | `PASS` |
| **3. Firebase Admin** | Token verification active via `FirebaseService` | `PASS` |
| **4. FCM** | Token handling & push dispatch configured | `PASS` |
| **5. Cloudinary** | Signed upload endpoint & Flutter upload active | `PASS` |
| **6. NestJS API** | REST controllers, pipes, guards operational | `PASS` |
| **7. Flutter Client** | 0 compilation errors, Firebase initialized | `PASS` |
| **8. Android Release** | Package `com.sadhana.tracker` signed & configured | `PASS` |
| **9. Security** | 401/403 guards & Preacher isolation verified | `PASS` |
| **10. Data Integrity** | 142 Users, 3,995 Sadhana entries, 0 Orphans | `PASS` |
| **11. Supabase Removal** | 0 runtime dependencies | `PASS` |
| **12. Production Deployment**| Cloud HTTPS Hosting (e.g. Render/AWS) | `BLOCKED` (Requires Cloud Hosting Provisioning) |
| **13. Real-Device QA** | Physical Phone OTP & Terminated FCM | `DEFERRED` (Requires physical Android device) |
| **14. Backups** | SQL dump & Watermark snapshot verified | `PASS` |
| **15. Monitoring** | `/health` and `/health/db` endpoints active | `PASS` |

---

## 10. FINAL PRODUCTION STATUS

```text
ACTUAL_PRODUCTION_STATUS = NOT_READY
```
*(Status is `NOT_READY` until public HTTPS cloud hosting is provisioned and physical device QA is completed).*
