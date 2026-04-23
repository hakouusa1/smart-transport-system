# Code Rules & Guidelines

> **Last Updated:** 2026-03-31  
> **Applies To:** All developers and AI assistants working on this project

---

## 📋 Table of Contents

1. [File Naming Conventions](#-file-naming-conventions)
2. [Code Structure Rules](#-code-structure-rules)
3. [Firebase/Firestore Rules](#-firebasefirestore-rules)
4. [State Management Guidelines](#-state-management-guidelines)
5. [UI/Screen Guidelines](#-uiscreen-guidelines)
6. [Error Handling](#-error-handling)
7. [Documentation Requirements](#-documentation-requirements)
8. [Git/Version Control](#-gitversion-control)
9. [Performance Guidelines](#-performance-guidelines)
10. [Security Guidelines](#-security-guidelines)

---

## 📝 File Naming Conventions

### Dart Files

| Type | Convention | Example |
|------|------------|---------|
| Screens/Pages | `*_page.dart` | `users_page.dart`, `dashboard_page.dart` |
| Services | `*_service.dart` | `admin_service.dart` |
| Models | `*_model.dart` | `user_model.dart` |
| Widgets | `*_widget.dart` | `custom_button_widget.dart` |
| Providers | `*_provider.dart` | `auth_provider.dart` |
| Utils/Helpers | `*_utils.dart` | `date_utils.dart` |
| Constants | `*_constants.dart` | `app_constants.dart` |
| Theme | `theme.dart` | `theme.dart` |
| Main | `main.dart` | `main.dart` |

### Directory Naming

- Use **lowercase_with_underscores**
- Group related files together
- Screens go in `lib/screens/`
- Services go in `lib/services/`
- Models go in `lib/models/`
- Widgets go in `lib/widgets/`

---

## 🏗 Code Structure Rules

### Project Structure

```
lib/
├── main.dart                 # Entry point (one per app)
├── firebase_options.dart     # Firebase config (if needed)
├── theme.dart                # Theme configuration
├── screens/                  # All UI screens
│   ├── login_screen.dart
│   └── *_page.dart
├── services/                 # Business logic
│   └── *_service.dart
├── models/                   # Data models
│   └── *_model.dart
├── widgets/                  # Reusable widgets
│   └── *_widget.dart
└── providers/                # State management
    └── *_provider.dart
```

### Class Organization

```dart
// 1. Imports
import 'package:flutter/material.dart';
import 'package:firebase/firebase.dart';

// 2. Class definition
class MyClass extends StatelessWidget {
  // 3. Constants/Static fields
  static const String myConstant = 'value';
  
  // 4. Instance fields
  final String title;
  
  // 5. Constructor
  const MyClass({super.key, required this.title});
  
  // 6. Lifecycle methods (for StatefulWidget)
  @override
  void initState() { ... }
  
  // 7. Build method
  @override
  Widget build(BuildContext context) {
    // 8. Return widget
    return Container();
  }
  
  // 9. Helper methods (private)
  Widget _buildHelper() { ... }
}
```

### Import Order

1. Dart/Flutter built-in packages
2. Third-party packages
3. Project internal packages
4. Relative imports (local files)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase/firebase.dart';
import 'services/admin_service.dart';
import '../screens/other_page.dart';
```

---

## 🔥 Firebase/Firestore Rules

### Collection Naming

- Use **plural lowercase**: `users`, `buses`, `lines`, `bookings`
- Be consistent across the entire project
- Document collection names in ARCHITECTURE.md

### Document Structure

```dart
// Good: Flat, denormalized structure
{
  "id": "doc_id",
  "name": "John Doe",
  "email": "john@example.com",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}

// Avoid: Deeply nested structures
{
  "user": {
    "profile": {
      "name": { "first": "John", "last": "Doe" }
    }
  }
}
```

### CRUD Operations

```dart
// CREATE
Future<String> createDocument(String collection, Map<String, dynamic> data) async {
  final docRef = await FirebaseFirestore.instance
    .collection(collection)
    .add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  return docRef.id;
}

// READ
Future<Map<String, dynamic>?> getDocument(String collection, String id) async {
  final doc = await FirebaseFirestore.instance
    .collection(collection)
    .doc(id)
    .get();
  return doc.data();
}

// UPDATE
Future<void> updateDocument(String collection, String id, Map<String, dynamic> data) async {
  await FirebaseFirestore.instance
    .collection(collection)
    .doc(id)
    .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
}

// DELETE
Future<void> deleteDocument(String collection, String id) async {
  await FirebaseFirestore.instance
    .collection(collection)
    .doc(id)
    .delete();
}
```

### Real-time Updates

```dart
Stream<List<Map<String, dynamic>>> watchCollection(String collection) {
  return FirebaseFirestore.instance
    .collection(collection)
    .snapshots()
    .map((snapshot) => 
      snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
    );
}
```

---

## 🎯 State Management Guidelines

### Provider Pattern

```dart
// Service extends ChangeNotifier
class AdminService extends ChangeNotifier {
  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];
  
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get items => _items;
  
  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _items = await fetchItems();
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### Consumer/Selector Usage

```dart
// Use Consumer for rebuilds
Consumer<AdminService>(
  builder: (context, service, child) {
    if (service.isLoading) return CircularProgressIndicator();
    return ListView.builder(...);
  },
)

// Use Selector for specific updates
Selector<AdminService, bool>(
  selector: (_, service) => service.isLoading,
  builder: (_, isLoading, __) {
    return isLoading ? CircularProgressIndicator() : Content();
  },
)
```

---

## 🎨 UI/Screen Guidelines

### Screen Structure

```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page Title'),
        actions: [/* Action buttons */],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }
  
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content here
        ],
      ),
    );
  }
}
```

### Responsive Design

```dart
// Use LayoutBuilder for responsive layouts
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 800) {
      return WideLayout(); // Tablet/Desktop
    } else {
      return NarrowLayout(); // Mobile
    }
  },
)
```

### Form Guidelines

```dart
// Always validate forms
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: Column(
    children: [
      TextFormField(
        decoration: InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter email';
          }
          if (!value.contains('@')) {
            return 'Please enter valid email';
          }
          return null;
        },
      ),
    ],
  ),
)
```

---

## ⚠️ Error Handling

### Try-Catch Pattern

```dart
Future<void> myAsyncFunction() async {
  try {
    // Call Firebase or API
    await FirebaseFirestore.instance.collection('test').add({'data': 'value'});
  } on FirebaseException catch (e) {
    // Handle Firebase-specific errors
    print('Firebase error: ${e.message}');
    rethrow; // Or handle appropriately
  } catch (e) {
    // Handle all other errors
    print('Unexpected error: $e');
    rethrow;
  }
}
```

### Async/Await Best Practices

```dart
// Always handle loading and error states
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      await context.read<MyService>().fetchData();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

---

## 📚 Documentation Requirements

### Every New File Must Have

```dart
/// [FileName].dart
/// 
/// Description of what this file does.
/// 
/// Created: YYYY-MM-DD
/// Author: [Name/AI]
/// 
/// Last Modified: YYYY-MM-DD
```

### Class Documentation

```dart
/// [ClassName] handles [specific functionality].
/// 
/// Usage:
/// ```dart
/// final service = AdminService();
/// await service.loadUsers();
/// ```
class AdminService extends ChangeNotifier {
  // ...
}
```

### Method Documentation

```dart
/// Fetches all documents from [collection].
/// 
/// Throws [FirebaseException] if fetch fails.
/// 
/// Returns [List<Map<String, dynamic>>] of documents.
Future<List<Map<String, dynamic>>> fetchDocuments(String collection) async {
  // ...
}
```

---

## 🔀 Git/Version Control

### Commit Message Format

```
[type]: [short description]
|
|[blank line]
|[detailed description]
|
|[blank line]
|[footer with issue references]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Example:**
```
feat: Add user profile page

- Created new profile page with edit functionality
- Added image upload to Firebase Storage
- Updated routing

Closes #12
```

### Branch Naming

```
feature/feature-name
bugfix/bug-description
hotfix/critical-fix
docs/documentation-update
```

---

## ⚡ Performance Guidelines

### ListView Optimization

```dart
// Use ListView.builder for large lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(
      title: Text(items[index]['name']),
    );
  },
)

// Use const constructors when possible
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Constant text'),
)
```

### Firebase Query Optimization

```dart
// Limit results when possible
.collection('users')
.limit(50)  // Limit to 50 documents
.get();

// Use indexes for large collections
// Create composite indexes in Firebase Console
.collection('bookings')
.where('status', isEqualTo: 'pending')
.where('date', isGreaterThan: DateTime.now())
.get();
```

### Memory Management

```dart
// Cancel subscriptions when not needed
@override
void dispose() {
  subscription?.cancel(); // Cancel Firestore subscriptions
  super.dispose();
}
```

---

## 🔒 Security Guidelines

### Firebase Security Rules

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Admin can access all users
    match /users/{userId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### Data Validation

```dart
// Always validate data before saving
void validateAndSave(Map<String, dynamic> data) {
  // Check required fields
  if (data['email'] == null || data['email'].toString().isEmpty) {
    throw ValidationException('Email is required');
  }
  
  // Validate email format
  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(data['email'])) {
    throw ValidationException('Invalid email format');
  }
  
  // Sanitize data
  data['email'] = data['email'].toString().trim().toLowerCase();
}
```

### Sensitive Data

- **NEVER** hardcode API keys or credentials
- Use environment variables or Firebase config
- Don't log sensitive information
- Clear sensitive data from memory when done

---

## 📌 Quick Reference Checklist

Before completing any task, verify:

- [ ] File naming follows conventions
- [ ] Code is properly organized
- [ ] Firebase operations use proper error handling
- [ ] State management follows Provider pattern
- [ ] UI follows screen structure guidelines
- [ ] New code is documented
- [ ] Git commit message is formatted correctly
- [ ] Performance considerations addressed
- [ ] Security best practices followed
- [ ] ARCHITECTURE.md updated (if structure changed)
- [ ] BUG_REPORTS.md updated (if bug discovered/fixed)

---

## 📞 Quick Reference

| Question | Answer |
|----------|--------|
| Where to put new screens? | `admin_web/lib/screens/` or `chauffeur_app/lib/screens/` |
| Where to put services? | `admin_web/lib/services/` or `chauffeur_app/lib/services/` |
| How to name new files? | Use `snake_case.dart` with appropriate suffix |
| How to update docs? | Update ARCHITECTURE.md when structure changes |
| Where is Firebase config? | `admin_web/lib/firebase_options.dart` |
| Where to report bugs? | `BUG_REPORTS.md` |

---

**Remember:** These rules exist to maintain consistency and quality. Always follow them when working on this project!
