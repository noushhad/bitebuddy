import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<User?> registerUser(
      String email, String password, String userType) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'user_type': userType}, // optional if you use auth metadata
      );

      final user = response.user;
      if (user != null) {
        // Store user details in 'users' table
        final newUser =
            UserModel(uid: user.id, email: email, userType: userType);
        await _supabase.from('users').insert(newUser.toMap());
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginUser(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getUserDetails(String uid) async {
    try {
      final response =
          await _supabase.from('users').select().eq('uid', uid).single();

      if (response != null) {
        return UserModel.fromMap(response);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
