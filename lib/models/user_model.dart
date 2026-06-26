import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, worker, admin }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final List<String> skills; // For workers: plumbing, electrical, carpentry
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? profileImageUrl;
  final bool isVerified;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.skills = const [],
    this.latitude,
    this.longitude,
    this.address,
    this.profileImageUrl,
    this.isVerified = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'skills': skills,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'isVerified': isVerified,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to a JSON-safe map for the REST API (no Firestore types).
  Map<String, dynamic> toApiMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'skills': skills,
      'city': address ?? 'Cairo',
      'address': address ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'profileImageUrl': profileImageUrl ?? '',
      'isVerified': isVerified,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.customer,
      ),
      skills: List<String>.from(map['skills'] ?? []),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'],
      profileImageUrl: map['profileImageUrl'],
      isVerified: map['isVerified'] ?? false,
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  AppUser copyWith({
    String? name,
    String? phone,
    List<String>? skills,
    double? latitude,
    double? longitude,
    String? address,
    String? profileImageUrl,
    bool? isVerified,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      skills: skills ?? this.skills,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
    );
  }
}
