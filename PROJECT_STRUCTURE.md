# Flutter Project Structure Guide

## 📁 Project Folder Organization

### **lib/** - All Your Dart Code Goes Here

```
lib/
├── main.dart                    # App entry point - DO NOT DELETE
├── models/                      # Data models (User, Product, Order, etc.)
│   └── user_model.dart
├── screens/                     # All app screens/pages
│   ├── admin/                   # Admin-only screens
│   │   └── admin_dashboard.dart
│   ├── user/                    # User screens
│   │   └── user_home.dart
│   └── auth/                    # Login, signup screens
│       └── login_screen.dart
├── widgets/                     # Reusable UI components
│   └── custom_button.dart
├── services/                    # Business logic (API calls, auth, etc.)
│   └── auth_service.dart
├── database/                    # Database code (SQLite, Firebase, etc.)
│   └── database_helper.dart
├── utils/                       # Helper functions (validators, formatters)
│   └── validators.dart
└── constants/                   # App constants (colors, strings, configs)
    ├── app_colors.dart
    └── app_strings.dart
```

### **assets/** - Images, Icons, Fonts

```
assets/
├── images/                      # Put all images here (.png, .jpg, .svg)
│   ├── logo.png
│   ├── banner.jpg
│   └── profile_placeholder.png
├── icons/                       # Custom icons
│   └── custom_icon.png
└── fonts/                       # Custom fonts (.ttf, .otf)
    └── Roboto-Regular.ttf
```

**Important:** After adding images/fonts, run `flutter pub get`

### **test/** - Unit & Widget Tests

```
test/
└── widget_test.dart             # Write your tests here
```

---

## 🎯 Where to Put Your Code

### 1. **Data Models** → `lib/models/`

Define data structures (classes)

```dart
// lib/models/product_model.dart
class Product {
  final String id;
  final String name;
  final double price;
}
```

### 2. **Screens/Pages** → `lib/screens/`

Create new screens for different features

- **Admin screens** → `lib/screens/admin/`
- **User screens** → `lib/screens/user/`
- **Auth screens** → `lib/screens/auth/`

### 3. **Reusable Widgets** → `lib/widgets/`

Custom buttons, cards, dialogs, etc.

```dart
// lib/widgets/loading_spinner.dart
class LoadingSpinner extends StatelessWidget { ... }
```

### 4. **Database Code** → `lib/database/`

SQLite queries, Firebase setup, API integration

```dart
// lib/database/database_helper.dart
class DatabaseHelper {
  Future<List<User>> getUsers() async { ... }
}
```

### 5. **Services** → `lib/services/`

Authentication, API calls, background tasks

```dart
// lib/services/api_service.dart
class ApiService {
  Future<List<Product>> fetchProducts() async { ... }
}
```

### 6. **Constants** → `lib/constants/`

Colors, text strings, API endpoints

```dart
// lib/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'https://api.example.com';
}
```

### 7. **Utilities** → `lib/utils/`

Validators, formatters, helper functions

```dart
// lib/utils/date_formatter.dart
String formatDate(DateTime date) { ... }
```

---

## 📸 How to Use Images

### 1. Add image to `assets/images/` folder

```
assets/images/logo.png
```

### 2. Use in your code

```dart
Image.asset('assets/images/logo.png')
```

---

## 🎨 How to Use Custom Fonts

### 1. Add font file to `assets/fonts/`

```
assets/fonts/Roboto-Regular.ttf
```

### 2. Register in `pubspec.yaml`

```yaml
flutter:
  fonts:
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
```

### 3. Use in your code

```dart
Text('Hello', style: TextStyle(fontFamily: 'Roboto'))
```

---

## 🚀 Common Packages for Mobile Development

Add these to `pubspec.yaml` under `dependencies:`:

### Database

```yaml
sqflite: ^2.3.0 # SQLite database
path: ^1.8.3 # File paths
```

### State Management

```yaml
provider: ^6.1.1 # Recommended for beginners
# OR
riverpod: ^2.4.9 # More advanced
```

### HTTP/API

```yaml
http: ^1.1.2 # HTTP requests
dio: ^5.4.0 # Advanced HTTP client
```

### Firebase

```yaml
firebase_core: ^2.24.2 # Firebase core
firebase_auth: ^4.16.0 # Authentication
cloud_firestore: ^4.14.0 # Firestore database
```

### Navigation

```yaml
go_router: ^13.0.0 # Modern navigation
```

### Forms & Validation

```yaml
form_validator: ^2.1.1 # Form validation
```

### Local Storage

```yaml
shared_preferences: ^2.2.2 # Key-value storage
```

After adding packages, run:

```bash
flutter pub get
```

---

## 📝 Quick Start Workflow

1. **Design your database schema** → Write in `lib/database/`
2. **Create data models** → Add to `lib/models/`
3. **Build UI screens** → Create in `lib/screens/`
4. **Add reusable widgets** → Put in `lib/widgets/`
5. **Connect logic** → Write services in `lib/services/`
6. **Add assets** → Place images in `assets/images/`
7. **Run your app** → `flutter run`

---

## 🛠️ Important Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run app on connected device
flutter build apk            # Build Android APK
flutter clean                # Clean build cache
flutter doctor               # Check setup
```

---

## 📱 Example Flow: Login → Dashboard

```
1. User opens app → main.dart
2. Shows LoginScreen → lib/screens/auth/login_screen.dart
3. User enters credentials
4. AuthService validates → lib/services/auth_service.dart
5. Database checks user → lib/database/database_helper.dart
6. Navigate to:
   - Admin → lib/screens/admin/admin_dashboard.dart
   - User → lib/screens/user/user_home.dart
```

---

## ✅ Best Practices

- **One screen = one file** in `lib/screens/`
- **One model = one file** in `lib/models/`
- **Keep widgets small** - break into smaller reusable widgets
- **Use constants** instead of hardcoded strings/colors
- **Name files with snake_case**: `user_profile_screen.dart`
- **Name classes with PascalCase**: `UserProfileScreen`

---

Ready to start coding! 🎉
