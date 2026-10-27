class AppUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final String country;
  final String city;
  final String? deviceId;
  final bool isPremium;
  final int totalScans;
  final String? createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.country,
    required this.city,
    this.deviceId,
    this.isPremium = false,
    this.totalScans = 0,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      country: json['country'] as String? ?? 'Unknown',
      city: json['city'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String?,
      isPremium: json['isPremium'] == true || json['is_premium'] == true,
      totalScans: (json['totalScans'] ?? json['total_scans'] ?? 0) as int,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'country': country,
      'city': city,
      'deviceId': deviceId,
      'isPremium': isPremium,
      'totalScans': totalScans,
      'createdAt': createdAt,
    };
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? country,
    String? city,
    String? deviceId,
    bool? isPremium,
    int? totalScans,
    String? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      country: country ?? this.country,
      city: city ?? this.city,
      deviceId: deviceId ?? this.deviceId,
      isPremium: isPremium ?? this.isPremium,
      totalScans: totalScans ?? this.totalScans,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
