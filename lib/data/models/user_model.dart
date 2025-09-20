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
  final DateTime updatedAt;
  final String? firstName;
  final String? lastName;
  final bool isSynced;
  final bool needsSync;
  final bool isCurrentUser;
  final int version; // Add version for LWW
  final int avatarVersion;

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
    required this.updatedAt,
    this.firstName,
    this.lastName,
    this.isSynced = false,
    this.needsSync = true,
    this.isCurrentUser = false,
    this.version = 1,
    this.avatarVersion = 0,
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
      updatedAt: DateTime.parse(json['updated_at'] as String),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      isSynced: (json['is_synced'] as int?) == 1,
      needsSync: (json['needs_sync'] as int?) == 1,
      isCurrentUser: (json['is_current_user'] as int?) == 1,
      version: (json['version'] as int?) ?? 1,
      avatarVersion: (json['avatar_version'] as int?) ?? 0,
    );
  }

  // From Supabase JSON
  factory UserModel.fromSupabaseJson(Map<String, dynamic> json) {
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
      updatedAt: DateTime.parse(json['updated_at'] as String),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      isSynced: true,
      needsSync: false,
      isCurrentUser: false,
      version: (json['version'] as int?) ?? 1,
      avatarVersion: (json['avatar_version'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'password': password,
      'phone_no': phoneNo,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'gender': gender,
      'profile_path': profilePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'is_synced': isSynced ? 1 : 0,
      'needs_sync': needsSync ? 1 : 0,
      'is_current_user': isCurrentUser ? 1 : 0,
      'version': version,
      'avatar_version': avatarVersion,
    };
  }

  // To Supabase JSON
  Map<String, dynamic> toSupabaseJson() {
    final data = toJson();
    data.remove('is_synced');
    data.remove('needs_sync');
    data.remove('is_current_user');
    return data;
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
    int? version,
    int? avatarVersion,
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
      version: version ?? this.version,
      avatarVersion: avatarVersion ?? this.avatarVersion,
    );
  }

  // Last-Write Wins conflict resolution
  bool isNewerThan(UserModel other) {
    return updatedAt.isAfter(other.updatedAt) ||
        (updatedAt.isAtSameMomentAs(other.updatedAt) &&
            version > other.version);
  }

  User toEntity() {
    return User(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      password: password,
      phoneNo: phoneNo,
      birthDate: birthDate,
      gender: gender,
      profilePath: profilePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      avatarVersion: avatarVersion,
    );
  }

  factory UserModel.fromEntity(
    User entity, {
    bool? isSynced,
    bool? needsSync,
    bool? isCurrentUser,
    int? version,
  }) {
    return UserModel(
      userId: entity.userId,
      firstName: entity.firstName,
      lastName: entity.lastName,
      username: entity.username,
      email: entity.email,
      password: entity.password,
      phoneNo: entity.phoneNo,
      birthDate: entity.birthDate,
      gender: entity.gender,
      profilePath: entity.profilePath,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt ?? DateTime.now(),
      isSynced: isSynced ?? false,
      needsSync: needsSync ?? true,
      isCurrentUser: isCurrentUser ?? false,
      version: version ?? 1,
      avatarVersion: entity.avatarVersion,
    );
  }

  UserModel toPublicModel() {
    return copyWith(password: null);
  }
}
