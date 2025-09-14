import '../../domain/entities/user.dart';

class UserModel {
  final String userId;
  final String? username;
  final String? email;
  final String? password;
  final String? phoneNo;
  final DateTime? birthDate;
  final String? gender;
  final String? profilePath;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? firstName;
  final String? lastName;
  final bool isSynced;
  final bool needsSync;
  final bool isCurrentUser;

  const UserModel({
    required this.userId,
    this.username,
    this.email,
    this.password,
    this.phoneNo,
    this.birthDate,
    this.gender,
    this.profilePath,
    required this.createdAt,
    this.updatedAt,
    this.firstName,
    this.lastName,
    this.isSynced = false,
    this.needsSync = true,
    this.isCurrentUser = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      phoneNo: json['phone_no'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      gender: json['gender'] as String?,
      profilePath: json['profile_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      isSynced: (json['is_synced'] as int?) == 1,
      needsSync: (json['needs_sync'] as int?) == 1,
      isCurrentUser: (json['is_current_user'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'password': password,
      'phone_no': phoneNo,
      'birth_date': birthDate?.toIso8601String().split('T')[0], // Date only
      'gender': gender,
      'profile_path': profilePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'is_synced': isSynced ? 1 : 0,
      'needs_sync': needsSync ? 1 : 0,
      'is_current_user': isCurrentUser ? 1 : 0,
    };
  }

  // Convert to domain entity
  User toEntity() {
    return User(
      userId: userId,
      username: username,
      email: email,
      password: password,
      phoneNo: phoneNo,
      birthDate: birthDate,
      gender: gender,
      profilePath: profilePath,
      firstName: firstName,
      lastName: lastName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Create from domain entity
  factory UserModel.fromEntity(
    User entity, {
    bool? isSynced,
    bool? needsSync,
    bool? isCurrentUser,
  }) {
    return UserModel(
      userId: entity.userId,
      username: entity.username,
      email: entity.email,
      password: entity.password,
      phoneNo: entity.phoneNo,
      birthDate: entity.birthDate,
      gender: entity.gender,
      profilePath: entity.profilePath,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      firstName: entity.firstName,
      lastName: entity.lastName,
      isSynced: isSynced ?? false,
      needsSync: needsSync ?? true,
      isCurrentUser: isCurrentUser ?? false,
    );
  }

  UserModel copyWith({
    String? userId,
    String? username,
    String? email,
    String? password,
    String? phoneNo,
    DateTime? birthDate,
    String? gender,
    String? profilePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? firstName,
    String? lastName,
    bool? isSynced,
    bool? needsSync,
    bool? isCurrentUser,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      phoneNo: phoneNo ?? this.phoneNo,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      profilePath: profilePath ?? this.profilePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isSynced: isSynced ?? this.isSynced,
      needsSync: needsSync ?? this.needsSync,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  // Create without sensitive data
  UserModel toPublicModel() {
    return copyWith(password: null);
  }
}
