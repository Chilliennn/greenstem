class User{
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String birthDate;
  final String phoneNo;
  final String? gender;
  final String? profileImgPath;
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.birthDate,
    required this.phoneNo,
    this.gender,
    this.profileImgPath,
  });
}