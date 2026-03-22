import 'enums.dart';

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  AppUser copyWith({String? id, String? name, UserRole? role, String? avatarUrl}) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
