// Example User Model
// Put all your data models here (User, Product, Order, etc.)

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' or 'user'

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  // Convert from database map to UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
    );
  }

  // Convert UserModel to database map
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'email': email, 'role': role};
  }
}
