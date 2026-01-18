import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userDataProvider = FutureProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(authServiceProvider).getUserData(uid);
});

final currentUserDataProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user != null && !user.isAnonymous) {
        return ref.watch(authServiceProvider).getUserData(user.uid);
      }
      return null;
    },
    loading: () => null,
    error: (error, stack) => null,
  );
});