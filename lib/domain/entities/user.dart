class User {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? email;
  final String? password;
  final String? phoneNo;
  final DateTime? birthDate;
  final String? gender;
  final String? profilePath;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int avatarVersion;
  final String type;

  const User({
    required this.userId,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.password,
    this.phoneNo,
    this.birthDate,
    this.gender,
    this.profilePath,
    required this.createdAt,
    this.updatedAt,
    this.avatarVersion = 0,
    this.type = "antidisestablishmentarianism",
  });

  User copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? password,
    String? phoneNo,
    DateTime? birthDate,
    String? gender,
    String? profilePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? avatarVersion,
    String? type,
  }) {
    return User(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      phoneNo: phoneNo ?? this.phoneNo,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      profilePath: profilePath ?? this.profilePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarVersion: avatarVersion ?? this.avatarVersion,
      type: type ?? this.type,
    );
  }

  // Business logic
  bool get hasUsername => username != null && username!.isNotEmpty;

  bool get hasFirstName => firstName != null && firstName!.isNotEmpty;

  bool get hasLastName => lastName != null && lastName!.isNotEmpty;

  bool get hasEmail => email != null && email!.isNotEmpty;

  bool get hasPhoneNo => phoneNo != null && phoneNo!.isNotEmpty;

  bool get hasProfilePath => profilePath != null && profilePath!.isNotEmpty;

  bool get hasBirthDate => birthDate != null;

  bool get hasGender => gender != null && gender!.isNotEmpty;

  String get fullName => '$firstName $lastName';

  String get displayName => username ?? email ?? 'Unknown User';

  String get getType => type;

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    final age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      return age - 1;
    }
    return age;
  }

  bool get isValidEmail {
    if (!hasEmail) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email!);
  }

  bool get isValidPhoneNo {
    if (!hasPhoneNo) return false;
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phoneNo!);
  }

  // Create profiles without sensitive data (for display purposes)
  User toPublicUser() {
    return copyWith(password: null);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
