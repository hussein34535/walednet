class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isPremium;
  final bool isBanned;
  final DateTime? premiumActivatedAt;
  final String? premiumActivatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoUrl,
    this.isPremium = false,
    this.isBanned = false,
    this.premiumActivatedAt,
    this.premiumActivatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      isPremium: data['isPremium'] as bool? ?? false,
      isBanned: data['isBanned'] as bool? ?? false,
      premiumActivatedAt: _toDateTime(data['premiumActivatedAt']),
      premiumActivatedBy: data['premiumActivatedBy'] as String?,
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isPremium': isPremium,
      'isBanned': isBanned,
      'premiumActivatedAt': premiumActivatedAt,
      'premiumActivatedBy': premiumActivatedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    bool? isPremium,
    bool? isBanned,
    String? premiumActivatedBy,
    String? displayName,
    String? photoUrl,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isPremium: isPremium ?? this.isPremium,
      isBanned: isBanned ?? this.isBanned,
      premiumActivatedAt: isPremium == true ? DateTime.now() : premiumActivatedAt,
      premiumActivatedBy: premiumActivatedBy ?? this.premiumActivatedBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return (value as dynamic).toDate() as DateTime?;
  }
}
