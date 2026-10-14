# ShopAd Platform Monorepo (`shop_ad_platform`)

A production-oriented Flutter monorepo containing five independently runnable Android applications and six modular shared packages for an out-of-home (OOH) digital shop advertising network.

---

## 1. Monorepo Architecture Overview

```
shop_ad_platform/
├── apps/
│   ├── master_admin_app/     # Global platform oversight, billing & system governance
│   ├── admin_app/            # Operations, regional management & shop approval
│   ├── employee_app/         # Field agents, screen installation & hardware pairing
│   ├── shopkeeper_app/       # Store owners, screen telemetry & revenue payouts
│   └── company_app/          # Advertisers, campaign creation & budget escrow
│
├── packages/
│   ├── app_core/             # Config, environment, logger, errors & secure storage
│   ├── design_system/        # Material 3 light/dark theme, Bengali/English typography
│   ├── domain_models/        # Pure domain entities, value objects & enums
│   ├── data_repository/      # Data access layer & Supabase health diagnostics
│   ├── map_features/         # Google Maps Flutter & Geolocator location services
│   └── payment_features/     # QR code rendering (qr_flutter) & scanning (mobile_scanner)
│
├── .env.dev.example          # Template for local development credentials
├── .env.staging.example      # Template for staging environment credentials
├── .env.prod.example         # Template for production credentials
├── .gitignore                # Excludes all active .env files, builds & caches
├── analysis_options.yaml     # Strict linting and typing rules
└── melos.yaml                # Monorepo task orchestration configuration
```

---

## 2. Package Responsibility Matrix

| Package | Purpose & Primary Dependencies |
| :--- | :--- |
| `packages/domain_models` | Zero/low-dependency pure domain entities (`UserRole`, `UserProfile`, `Shop`, `AdCampaign`, `DeviceScreen`, `PaymentTransaction`, `AppHealthInfo`). |
| `packages/app_core` | `flutter_riverpod`, `flutter_secure_storage`, `supabase_flutter`. Loads environment variables via `--dart-define-from-file`, wraps Keystore/EncryptedSharedPreferences, manages safe Supabase lifecycle and typed exception handling. |
| `packages/design_system` | Material 3 light and dark themes, design tokens, Bengali and English typography with font fallbacks (`Noto Sans Bengali`, `Hind Siliguri`, `Roboto`), bilingual dictionary (`AppStrings`), and reusable diagnostic widgets. |
| `packages/data_repository` | Concrete data source implementations querying Supabase database tables (`profiles`, `shops`, `campaigns`) and orchestrating multi-system health checks. |
| `packages/map_features` | `google_maps_flutter`, `geolocator`. GPS permissions, location stream, and interactive Google Map view with automatic dev-sandbox fallback when API keys are unconfigured. |
| `packages/payment_features` | `qr_flutter`, `mobile_scanner`. Generates transaction/pairing QR codes and provides live camera QR scanning with torch and lens toggle controls. |

---

## 3. Environment Configuration & Security

> **CRITICAL SECURITY RULE:**  
> Never commit active credentials, Supabase keys, Google Maps keys, or OTP secrets to Git. Active `.env` files are excluded by `.gitignore`. Read public client configuration only through `--dart-define-from-file`.

### Setting Up Environment Files

1. Copy the example templates:
   ```bash
   cp .env.dev.example .env.dev
   cp .env.staging.example .env.staging
   cp .env.prod.example .env.prod
   ```

2. Populate `.env.dev` with your sandbox credentials:
   ```properties
   APP_ENV=dev
   APP_NAME=Shop Ad Platform (DEV)
   SUPABASE_URL=https://your-dev-project.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   GOOGLE_MAPS_API_KEY=AIzaSyYourDevGoogleMapsKey
   API_BASE_URL=http://10.0.2.2:3000
   ENABLE_VERBOSE_LOGGING=true
   ```

---

## 4. Android Permissions & Configuration

Each app includes the necessary permissions configured in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Internet & Network Connectivity -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- GPS & Precise Location (For Shop Geofencing & Map Navigation) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

<!-- Camera Access (For QR Code Scanning) -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>

<!-- Hardware Feature Declarations (Allows installation on camera/GPS-optional tablets) -->
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
<uses-feature android:name="android.hardware.location.gps" android:required="false"/>

<!-- Google Maps Android API Key Hook -->
<application ...>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="AIzaSy_SHOPAD_MAP_KEY_PLACEHOLDER"/>
</application>
```

---

## 5. Supabase Backend Architecture & Schema Recommendations

Configure your Supabase project with the following recommended PostgreSQL tables and Row-Level Security (RLS) policies:

```sql
-- 1. User Profiles Table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('master_admin', 'admin', 'employee', 'shopkeeper', 'company')),
    phone_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- 2. Shops Table
CREATE TABLE public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id),
    shop_name TEXT NOT NULL,
    category TEXT DEFAULT 'General',
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'pending', 'suspended')),
    active_screens_count INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Ad Campaigns Table
CREATE TABLE public.campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.profiles(id),
    title TEXT NOT NULL,
    description TEXT,
    media_url TEXT NOT NULL,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'pending_approval', 'active', 'paused', 'completed')),
    budget NUMERIC(12,2) DEFAULT 0.00,
    target_radius_km DOUBLE PRECISION DEFAULT 5.0,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Device Display Screens
CREATE TABLE public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    screen_code TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'maintenance')),
    resolution TEXT DEFAULT '1920x1080',
    location_note TEXT,
    last_ping_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Payment & Settlement Transactions
CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES public.campaigns(id),
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    amount NUMERIC(12,2) NOT NULL,
    currency TEXT DEFAULT 'BDT',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    method TEXT DEFAULT 'mock_bkash',
    gateway_reference TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
```

---

## 6. Exact Commands to Launch Each App

Run each app from the root or within its app directory, pointing `--dart-define-from-file` to your chosen environment:

### Master Admin App (`apps/master_admin_app`)
- **Development**:
  ```bash
  flutter run -d chrome -t apps/master_admin_app/lib/main.dart --dart-define-from-file=.env.dev
  # Or on Android device/emulator:
  flutter run -d android -t apps/master_admin_app/lib/main.dart --dart-define-from-file=.env.dev
  ```
- **Staging**:
  ```bash
  flutter run -d android -t apps/master_admin_app/lib/main.dart --dart-define-from-file=.env.staging
  ```
- **Production**:
  ```bash
  flutter run -d android -t apps/master_admin_app/lib/main.dart --dart-define-from-file=.env.prod --release
  ```

### Admin App (`apps/admin_app`)
- **Development**:
  ```bash
  flutter run -d android -t apps/admin_app/lib/main.dart --dart-define-from-file=.env.dev
  ```
- **Staging**:
  ```bash
  flutter run -d android -t apps/admin_app/lib/main.dart --dart-define-from-file=.env.staging
  ```
- **Production**:
  ```bash
  flutter run -d android -t apps/admin_app/lib/main.dart --dart-define-from-file=.env.prod --release
  ```

### Field Employee App (`apps/employee_app`)
- **Development**:
  ```bash
  flutter run -d android -t apps/employee_app/lib/main.dart --dart-define-from-file=.env.dev
  ```
- **Staging**:
  ```bash
  flutter run -d android -t apps/employee_app/lib/main.dart --dart-define-from-file=.env.staging
  ```
- **Production**:
  ```bash
  flutter run -d android -t apps/employee_app/lib/main.dart --dart-define-from-file=.env.prod --release
  ```

### Shopkeeper App (`apps/shopkeeper_app`)
- **Development**:
  ```bash
  flutter run -d android -t apps/shopkeeper_app/lib/main.dart --dart-define-from-file=.env.dev
  ```
- **Staging**:
  ```bash
  flutter run -d android -t apps/shopkeeper_app/lib/main.dart --dart-define-from-file=.env.staging
  ```
- **Production**:
  ```bash
  flutter run -d android -t apps/shopkeeper_app/lib/main.dart --dart-define-from-file=.env.prod --release
  ```

### Company / Advertiser App (`apps/company_app`)
- **Development**:
  ```bash
  flutter run -d android -t apps/company_app/lib/main.dart --dart-define-from-file=.env.dev
  ```
- **Staging**:
  ```bash
  flutter run -d android -t apps/company_app/lib/main.dart --dart-define-from-file=.env.staging
  ```
- **Production**:
  ```bash
  flutter run -d android -t apps/company_app/lib/main.dart --dart-define-from-file=.env.prod --release
  ```

---

## 7. Quality Assurance: Formatting, Static Analysis, and Unit Testing

### 1. Code Formatting
Format all Dart files with 100-character line width:
```bash
dart format --line-length=100 apps packages
```

### 2. Static Analysis
Run strict static analysis across all packages and apps:
```bash
flutter analyze packages/domain_models
flutter analyze packages/app_core
flutter analyze packages/design_system
flutter analyze packages/data_repository
flutter analyze packages/map_features
flutter analyze packages/payment_features
flutter analyze apps/master_admin_app
flutter analyze apps/admin_app
flutter analyze apps/employee_app
flutter analyze apps/shopkeeper_app
flutter analyze apps/company_app
```

### 3. Unit & Widget Testing
Execute the complete test suite across all 11 monorepo packages:
```bash
# Packages
flutter test packages/domain_models
flutter test packages/app_core
flutter test packages/design_system
flutter test packages/data_repository
flutter test packages/map_features
flutter test packages/payment_features

# Applications
flutter test apps/master_admin_app
flutter test apps/admin_app
flutter test apps/employee_app
flutter test apps/shopkeeper_app
flutter test apps/company_app
```
