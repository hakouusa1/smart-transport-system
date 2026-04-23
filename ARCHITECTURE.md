# Transport System Architecture Documentation

> **Last Updated:** 2026-03-31  
> **Status:** Auto-maintained - Update when changes are made to the project structure

---

## 📋 Table of Contents

1. [Project Overview](#-project-overview)
2. [Directory Structure](#-directory-structure)
3. [Application Modules](#-application-modules)
4. [Technology Stack](#-technology-stack)
5. [Data Models](#-data-models)
6. [Services Layer](#-services-layer)
7. [Screens/Pages](#-screenspages)
8. [State Management](#-state-management)
9. [Firebase Integration](#-firebase-integration)
10. [Platform-Specific Code](#-platform-specific-code)
11. [Rules for Updates](#-rules-for-updates)

---

## 🎯 Project Overview

This is a **Flutter-based Transport Management System** consisting of two interconnected applications:

| Application | Purpose | Platform |
|-------------|---------|----------|
| `admin_web/` | Admin dashboard for managing transport operations | Web (Primary), Mobile |
| `chauffeur_app/` | Driver application for managing trips and routes | Mobile (Android/iOS) |

**Core Features:**
- User management (admins, drivers, passengers)
- Bus/vehicle fleet management
- Line/route management
- Booking system
- Trip scheduling and tracking
- Incident reporting
- Statistics and analytics
- Real-time updates via Firebase

---

## 📁 Directory Structure

```
transport_system/
├── admin_web/                    # Admin Dashboard Application
│   ├── lib/
│   │   ├── main.dart              # Entry point
│   │   ├── firebase_options.dart # Firebase configuration
│   │   ├── theme.dart             # App theming
│   │   ├── screens/               # UI screens/pages
│   │   ├── services/              # Business logic & API calls
│   │   └── widgets/               # Reusable UI components
│   ├── android/                   # Android platform code
│   ├── ios/                       # iOS platform code
│   ├── web/                       # Web-specific assets
│   ├── linux/                     # Linux desktop support
│   ├── macos/                     # macOS desktop support
│   ├── windows/                   # Windows desktop support
│   └── pubspec.yaml               # Dependencies
│
├── chauffeur_app/                 # Chauffeur/Driver Application
│   ├── lib/
│   │   ├── main.dart              # Entry point
│   │   ├── screens/               # Driver UI screens
│   │   ├── services/              # Business logic & API calls
│   │   ├── models/                # Data models
│   │   └── widgets/               # Reusable widgets
│   ├── android/                   # Android platform code
│   ├── ios/                       # iOS platform code
│   └── pubspec.yaml               # Dependencies
│
├── ARCHITECTURE.md                # This file
├── CODE_RULES.md                  # Coding rules and guidelines
└── BUG_REPORTS.md                 # Bug tracking and solutions
```

---

## 📱 Application Modules

### Admin Web Application (`admin_web/`)

#### Source Code Location: `admin_web/lib/`

| Directory/File | Purpose |
|----------------|---------|
| [`lib/main.dart`](admin_web/lib/main.dart) | Application entry point, Firebase initialization |
| [`lib/theme.dart`](admin_web/lib/theme.dart) | Material theme configuration (colors, typography) |
| [`lib/firebase_options.dart`](admin_web/lib/firebase_options.dart) | Firebase project configuration |
| [`lib/screens/`](admin_web/lib/screens/) | All admin dashboard screens |
| [`lib/services/`](admin_web/lib/services/) | API services and business logic |

#### Screens (`admin_web/lib/screens/`)

| File | Page Description |
|------|------------------|
| [`login_page.dart`](admin_web/lib/screens/login_page.dart) | Admin authentication/login page |
| [`admin_shell_page.dart`](admin_web/lib/screens/admin_shell_page.dart) | Main navigation shell with sidebar |
| [`dashboard_page.dart`](admin_web/lib/screens/dashboard_page.dart) | Overview dashboard with stats |
| [`new_owners_page.dart`](admin_web/lib/screens/new_owners_page.dart) | Pending owner subscription approvals |
| [`new_buses_page.dart`](admin_web/lib/screens/new_buses_page.dart) | Pending bus validation & approval |
| [`users_page.dart`](admin_web/lib/screens/users_page.dart) | User management (CRUD operations) |
| [`buses_page.dart`](admin_web/lib/screens/buses_page.dart) | Bus/vehicle fleet management |
| [`lines_page.dart`](admin_web/lib/screens/lines_page.dart) | Route/line management |
| [`bookings_page.dart`](admin_web/lib/screens/bookings_page.dart) | Booking management |
| [`incidents_page.dart`](admin_web/lib/screens/incidents_page.dart) | Incident reports and handling |
| [`stats_page.dart`](admin_web/lib/screens/stats_page.dart) | Statistics and analytics |
| [`other_pages.dart`](admin_web/lib/screens/other_pages.dart) | Settings, profiles, additional pages |

#### Services (`admin_web/lib/services/`)

| File | Purpose |
|------|---------|
| [`admin_service.dart`](admin_web/lib/services/admin_service.dart) | Main service for Firebase operations, authentication, data management |
| [`admin_notification_service.dart`](admin_web/lib/services/admin_notification_service.dart) | Service for fetching pending counts (owners, buses) |

#### Widgets (`admin_web/lib/widgets/`)

| File | Purpose |
|------|---------|
| [`notification_badge_widget.dart`](admin_web/lib/widgets/notification_badge_widget.dart) | Badge showing pending notification counts on navigation items |

---

### Chauffeur App (`chauffeur_app/`)

#### Source Code Location: `chauffeur_app/lib/`

| Directory/File | Purpose |
|----------------|---------|
| [`lib/main.dart`](chauffeur_app/lib/main.dart) | Application entry point |
| [`lib/screens/`](chauffeur_app/lib/screens/) | Driver UI screens |
| [`lib/services/`](chauffeur_app/lib/services/) | Business logic & API calls |
| [`lib/models/`](chauffeur_app/lib/models/) | Data model classes |
| [`lib/widgets/`](chauffeur_app/lib/widgets/) | Reusable UI components |

---

## 🛠 Technology Stack

### Flutter SDK
- **Admin Web:** Flutter 3.x with web support enabled
- **Chauffeur App:** Flutter 3.x for mobile (Android/iOS)

### Key Dependencies

| Package | Purpose | Used In |
|---------|---------|---------|
| `firebase_core` | Firebase initialization | Both apps |
| `firebase_auth` | Authentication | Both apps |
| `cloud_firestore` | Database | Both apps |
| `firebase_storage` | File storage | Both apps |
| `provider` | State management | Both apps |

### State Management
- **Pattern:** Provider (as seen in `admin_service.dart` using `ChangeNotifier`)
- **Location:** Services contain business logic with state management

---

## 📊 Data Models

### Core Entities

| Entity | Description | Primary Location |
|--------|-------------|------------------|
| **User** | Admin, Driver, Passenger | Firebase Auth + Firestore |
| **Bus/Vehicle** | Fleet vehicles | Firestore `buses` collection |
| **Line/Route** | Transport routes | Firestore `lines` collection |
| **Booking** | Trip reservations | Firestore `bookings` collection |
| **Incident** | Issues/reports | Firestore `incidents` collection |
| **Trip** | Active/completed trips | Firestore `trips` collection |

### Firestore Collections Structure

```
firestore/
├── users/           # User profiles and roles
├── buses/           # Vehicle fleet data
├── lines/           # Route definitions
├── bookings/        # Reservations
├── incidents/       # Reported issues
├── trips/           # Trip records
└── stats/           # Analytics data
```

---

## 🔧 Services Layer

### Admin Service (`admin_web/lib/services/admin_service.dart`)

**Responsibilities:**
- Firebase authentication (login/logout)
- CRUD operations for all collections
- Real-time data subscription
- Data validation and transformation
- Error handling and logging

**Key Methods:**
```dart
// Authentication
Future<User?> signIn(String email, String password)
Future<void> signOut()

// CRUD Operations
Future<void> createDocument(String collection, Map<String, dynamic> data)
Future<List<Map<String, dynamic>>> getDocuments(String collection)
Future<void> updateDocument(String collection, String id, Map<String, dynamic> data)
Future<void> deleteDocument(String collection, String id)

// Real-time updates
Stream<List<Map<String, dynamic>>> watchCollection(String collection)
```

---

## 🎨 Screens/Pages

### Admin Web Screens

Each screen follows a consistent pattern:
1. **Header:** Page title and actions
2. **Content:** Main data display (tables, cards, lists)
3. **Dialogs:** Forms for create/edit operations

**Screen Components:**
- Data tables with sorting, filtering, pagination
- Form dialogs for data entry
- Confirmation dialogs for destructive actions
- Toast notifications for feedback
- Loading states and error handling

---

## 🔐 Firebase Integration

### Configuration Files

| File | Purpose |
|------|---------|
| `firebase_options.dart` (per app) | Firebase configuration for each platform |
| `google-services.json` (Android) | Firebase Android configuration |
| `firestore.rules` | Firestore security rules (root) |
| `database.rules.json` | Realtime Database security rules (root) |

### Firebase Services Used

| Service | Purpose |
|---------|---------|
| Firebase Auth | User authentication |
| Cloud Firestore | Primary database |
| Firebase Storage | File/image storage |

---

## 📂 Platform-Specific Code

### Android (`android/`)

| File | Purpose |
|------|---------|
| `app/build.gradle.kts` | App build configuration |
| `app/google-services.json` | Firebase Android config |
| `app/src/main/AndroidManifest.xml` | App permissions and configuration |
| `app/src/main/kotlin/.../MainActivity.kt` | Main activity |

### iOS (`ios/`)

| File | Purpose |
|------|---------|
| `Runner/AppDelegate.swift` | App delegate |
| `Runner/Info.plist` | iOS configuration |
| `Runner/Assets.xcassets/` | App icons and images |

### Web (`web/`)

| File | Purpose |
|------|---------|
| `index.html` | Web entry HTML |
| `manifest.json` | PWA manifest |
| `icons/` | Favicon and app icons |

### Desktop (Linux/macOS/Windows)

| Directory | Purpose |
|-----------|---------|
| `linux/` | Linux desktop app |
| `macos/` | macOS desktop app |
| `windows/` | Windows desktop app |

---

## 📝 Rules for Updates

### When to Update This Document

**⚠️ IMPORTANT:** Update this document immediately when:

| Change Type | Required Updates |
|-------------|------------------|
| New app/module added | Add to Project Overview, Directory Structure |
| New screen created | Add to Screens/Pages section with file path |
| New service created | Add to Services Layer section |
| New data model | Add to Data Models section |
| New Firebase collection | Add to Firestore Collections Structure |
| New dependency added | Add to Technology Stack section |
| New platform support | Add to Platform-Specific Code section |
| New feature/pattern | Add to appropriate section |
| **Bug discovered/fixed** | **Update BUG_REPORTS.md** |

### Update Procedure

1. **Identify the change** - What was added/modified?
2. **Find the section** - Which part of this document needs updating?
3. **Make the edit** - Add the new information in the correct location
4. **Update timestamp** - Change "Last Updated" date to current date
5. **Cross-reference** - Check if other sections need updates

### Update Template for New Files

When adding a new file, append to the relevant section:

```markdown
| [`new_file.dart`](path/to/new_file.dart) | Description of purpose |
```

### Update Template for New Directories

```markdown
### New Directory Name
| File | Purpose |
|------|---------|
| `file1.dart` | Description |
| `file2.dart` | Description |
```

---

## 🔄 Architecture Patterns

### Feature-Based Organization
- Each feature has its own directory/screen
- Shared components are in `widgets/` or `services/`

### Service-Oriented Architecture
- Business logic in services
- Services handle Firebase operations
- Screens only handle UI and user input

### Single Source of Truth
- Firebase Firestore is the primary data source
- Services manage data synchronization
- UI reacts to service state changes

---

## 📞 Quick Reference

| Question | Answer |
|----------|--------|
| Where is the admin app entry point? | [`admin_web/lib/main.dart`](admin_web/lib/main.dart) |
| Where is the driver app entry point? | [`chauffeur_app/lib/main.dart`](chauffeur_app/lib/main.dart) |
| Where is the main admin service? | [`admin_web/lib/services/admin_service.dart`](admin_web/lib/services/admin_service.dart) |
| Where is Firebase config? | [`admin_web/lib/firebase_options.dart`](admin_web/lib/firebase_options.dart) |
| Where are the admin screens? | [`admin_web/lib/screens/`](admin_web/lib/screens/) |
| Where is the theme? | [`admin_web/lib/theme.dart`](admin_web/lib/theme.dart) |
| Where to report bugs? | [`BUG_REPORTS.md`](BUG_REPORTS.md) |

---

**Remember:** This document is the single source of truth for the project structure. Always keep it updated when making changes!
