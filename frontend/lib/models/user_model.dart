/// User profile, mirrored from the backend `users` table.
///
/// Authentication is performed by the Node.js backend which issues a JWT.
/// The cached copy of this model lets the UI render the current user
/// without re-fetching on every screen.
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'admin',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'created_at': createdAt.toIso8601String(),
      };
}
