# Bug Reports & Solutions

> **Last Updated:** 2026-03-31  
> **Status:** Auto-maintained - Add new bugs and solutions as discovered

---

## 📋 Table of Contents

1. [How to Use This Document](#how-to-use-this-document)
2. [Firebase/Authentication Bugs](#firebaseauthentication-bugs)
3. [UI/Rendering Bugs](#uirendering-bugs)
4. [State Management Bugs](#state-management-bugs)
5. [Platform-Specific Bugs](#platform-specific-bugs)
6. [Build/Compilation Bugs](#buildcompilation-bugs)
7. [Data/Logic Bugs](#datalogic-bugs)
8. [Submit New Bug Report](#submit-new-bug-report)

---

## 🔍 How to Use This Document

### Bug Entry Format

```markdown
## [Bug ID: XXX] - Short Description

**Date Reported:** YYYY-MM-DD  
**Reported By:** [Name/AI]  
**Status:** [Open/In Progress/Resolved/WontFix]  
**Affected Version:** [Version/App]

### Problem Description
What the bug is and how to reproduce it.

### Steps to Reproduce
1. Step one
2. Step two
3. Step three

### Expected Behavior
What should happen.

### Actual Behavior
What actually happens.

### Error Messages
Any error messages or logs:
```
Error message here
```

### Root Cause
Why the bug occurs.

### Solution
How to fix the bug.

### Code Changes
```dart
// Before (broken code)
broken_code();

// After (fixed code)
fixed_code();
```

### Related Files
- `path/to/file.dart`

### Related Bugs
- [Bug ID: XXX](#bug-id-xxx---description)

---

## 🔥 Firebase/Authentication Bugs

<!-- Add Firebase bugs below -->

---

## 🎨 UI/Rendering Bugs

<!-- Add UI bugs below -->

---

## 🎯 State Management Bugs

<!-- Add state management bugs below -->

---

## 📱 Platform-Specific Bugs

<!-- Add platform-specific bugs below -->

---

## ⚙️ Build/Compilation Bugs

<!-- Add build bugs below -->

---

## 📊 Data/Logic Bugs

<!-- Add data/logic bugs below -->

---

## [Bug ID: 001] - Pending Buses Not Showing in Admin Bus Section

**Date Reported:** 2026-04-01  
**Reported By:** User  
**Status:** Resolved  
**Affected Version:** admin_web

### Problem Description
The "En attente" tab in the admin bus management section was not displaying buses with pending validation status, even though buses existed in Firestore with `validationStatus: 'pending'`.

### Steps to Reproduce
1. Open the admin web app
2. Navigate to "Gestion des bus" (Bus Management)
3. Check the "En attente" (Pending) tab
4. Observe that the list is empty (or shows "Aucun bus en attente de validation")

### Expected Behavior
Buses with `validationStatus` set to `'pending'` should appear in the "En attente" tab.

### Actual Behavior
The "En attente" tab shows an empty state message even when pending buses exist in Firestore.

### Root Cause
The `getPendingBuses()` method in `AdminService` uses a compound Firestore query:

```dart
static Stream<List<Map<String, dynamic>>> getPendingBuses() {
  return _db.collection('buses')
    .where('validationStatus', isEqualTo: 'pending')   // Filter on field 1
    .orderBy('createdAt', descending: true)           // Sort on field 2
    .snapshots()...
}
```

Firestore requires a **composite index** when combining a `where` clause on one field with an `orderBy` clause on a different field. Without this index, the query silently returns empty results.

### Solution
Created a `firestore.indexes.json` file with the required composite indexes for the `buses` collection.

### Code Changes

**Modified:** `admin_web/lib/services/admin_service.dart`
```dart
// Before (required composite index)
static Stream<List<Map<String, dynamic>>> getPendingBuses() {
  return _db.collection('buses')
    .where('validationStatus', isEqualTo: 'pending')
    .orderBy('createdAt', descending: true)  // Required composite index!
    .snapshots()...
}

// After (no composite index needed)
static Stream<List<Map<String, dynamic>>> getPendingBuses() {
  return _db.collection('buses')
    .where('validationStatus', isEqualTo: 'pending')
    .snapshots()...
}
```

**Modified:** `admin_web/lib/screens/buses_page.dart`
Added error handling to the StreamBuilder to catch and display Firestore query errors.

### Deployment
After merging this fix, run:
```bash
firebase deploy --only firestore:indexes
```

### Related Files
- `admin_web/lib/services/admin_service.dart`
- `admin_web/lib/screens/buses_page.dart`
- `firestore.indexes.json`

---

## 📝 Submit New Bug Report

When submitting a new bug, use the format above and add it to the appropriate section.

### Bug ID Format
- Format: `XXX` (3-digit number)
- Next available ID: See the highest number in existing bugs
- Example: If highest is 005, next bug is 006

### Status Definitions
| Status | Meaning |
|--------|---------|
| **Open** | Bug reported, not yet started |
| **In Progress** | Being worked on |
| **Resolved** | Fix implemented and verified |
| **WontFix** | Known issue, not going to fix |

### Quick Search Keywords
- `Firebase` - Authentication, Firestore issues
- `NullPointer` - Null safety errors
- `Provider` - State management issues
- `Build` - Compilation errors
- `Platform` - iOS/Android specific issues
- `UI` - Visual/rendering issues

---

## 📈 Statistics

| Category | Count | Open | Resolved |
|----------|-------|------|----------|
| Firebase/Auth | 0 | 0 | 0 |
| UI/Rendering | 0 | 0 | 0 |
| State Management | 0 | 0 | 0 |
| Platform-Specific | 0 | 0 | 0 |
| Build/Compilation | 0 | 0 | 0 |
| Data/Logic | 0 | 0 | 0 |
| **Total** | **0** | **0** | **0** |

---

## 🔗 Quick Reference

| Issue Type | Common Solution |
|------------|------------------|
| Firebase timeout | Add retry logic with exponential backoff |
| Null safety errors | Use null-aware operators (`?.`, `??`) |
| Provider not updating | Call `notifyListeners()` after state change |
| Build failing | Run `flutter clean` then `flutter pub get` |
| Platform-specific | Check platform channels and permissions |

---

**Remember:** Update this document immediately when a new bug is discovered or resolved!
