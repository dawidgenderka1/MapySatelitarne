import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class UserModel {
  final String uid;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String? displayName;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.createdAt,
    this.displayName,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.viewer,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      displayName: data['displayName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'displayName': displayName,
    };
  }

  bool get canView => true;
  bool get canEdit => role == UserRole.editor || role == UserRole.admin;
  bool get canDelete => role == UserRole.admin;
}