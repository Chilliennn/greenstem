class UserModel {
  final String userId;
  final String username;
  final String? email;
  final String? password;
  final String? phoneNo;
  final DateTime? birthDate;
  final String? gender;
  final String? profilePath;
  final DateTime createdAt;

  const UserModel({
    required this.userId,
    required this.username,
    this.email,
    this.password,
    this.phoneNo,
    this.birthDate,
    this.gender,
    this.profilePath,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'],
      username: json['username'] ?? '',
      email: json['email'],
      password: json['password'],
      phoneNo: json['phone_no'],
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      gender: json['gender'],
      profilePath: json['profile_path'],
      createdAt: DateTime.parse(json['created_at']),
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
    };
  }
}
