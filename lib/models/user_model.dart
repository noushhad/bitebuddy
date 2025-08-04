// class UserModel {
//   final String uid;
//   final String email;
//   final String userType; // 'customer' or 'owner'

//   UserModel({
//     required this.uid,
//     required this.email,
//     required this.userType,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'uid': uid,
//       'email': email,
//       'userType': userType,
//     };
//   }

//   factory UserModel.fromMap(Map<String, dynamic> map) {
//     return UserModel(
//       uid: map['uid'],
//       email: map['email'],
//       userType: map['userType'],
//     );
//   }
// }

class UserModel {
  final String uid;
  final String email;
  final String userType; // 'customer' or 'owner'
  final List<String>
      preferences; // A list of cuisine preferences (for customers)

  UserModel({
    required this.uid,
    required this.email,
    required this.userType,
    this.preferences = const [], // Default to an empty list if not set
  });

  // Convert UserModel object to Firestore-friendly data (Map)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'userType': userType,
      'preferences': preferences, // Store the preferences as an array
    };
  }

  // Convert Firestore data to a UserModel object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      userType: map['userType'],
      preferences: List<String>.from(
          map['preferences'] ?? []), // Parse preferences as a List<String>
    );
  }
}
