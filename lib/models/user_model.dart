class UserModel {
  final String uid;
  final String email;
  final String userType; // 'customer' or 'owner'
  final List<String> preferences;

  UserModel({
    required this.uid,
    required this.email,
    required this.userType,
    this.preferences = const [],
  });

  // Convert UserModel to Map for Supabase insert/update
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'user_type': userType,
      'preferences': preferences,
    };
  }

  // Create UserModel from Supabase response map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      userType: map['user_type'],
      preferences: List<String>.from(map['preferences'] ?? []),
    );
  }
}
