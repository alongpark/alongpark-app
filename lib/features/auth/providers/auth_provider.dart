import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/enums.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  void loginAs(UserRole role) {
    state = switch (role) {
      UserRole.client => const AppUser(
          id: 'client-01',
          name: 'Sophie Martin',
          role: UserRole.client,
        ),
      UserRole.driver => const AppUser(
          id: 'driver-01',
          name: 'Marc Dupont',
          role: UserRole.driver,
        ),
    };
  }

  void logout() => state = null;
}
