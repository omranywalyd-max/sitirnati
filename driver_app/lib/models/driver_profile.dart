/// Water grades a tanker can carry.
///
/// Stored as the Arabic label itself so a Firestore document stays readable in
/// the console, and so the customer app can filter on the same string without a
/// shared enum table.
abstract final class WaterTypes {
  /// Drinkable water.
  static const drinking = 'صالح للشرب';

  /// Water for building, irrigation and washing.
  static const notDrinking = 'غير صالح للشرب';

  /// Every grade, in the order they are offered.
  static const all = <String>[drinking, notDrinking];

  /// Whether [value] is one of the two known grades.
  static bool isValid(String value) => all.contains(value);
}

/// A driver's own record, stored at `drivers/{uid}`.
///
/// The uid is the Firebase Auth uid, so the security rules can answer "is this
/// your profile?" with `request.auth.uid == uid` and nothing else. The customer
/// app reads the same document to build its driver list, which is why the
/// contact details, the base point and the offer all live here.
class DriverProfile {
  /// Creates a profile.
  const DriverProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.waterType,
    required this.volumeM3,
    required this.price,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firebase Auth uid; also the document id.
  final String uid;

  /// Given name.
  final String firstName;

  /// Family name.
  final String lastName;

  /// Sign-in email, kept for the account page only.
  final String email;

  /// Contact phone, digits only.
  final String phone;

  /// Latitude of the driver's base point.
  final double lat;

  /// Longitude of the driver's base point.
  final double lng;

  /// One of [WaterTypes].
  final String waterType;

  /// Load size in cubic metres.
  final int volumeM3;

  /// Price per load in dinars.
  final int price;

  /// Whether the driver is accepting orders right now.
  final bool active;

  /// When the account was created.
  final DateTime createdAt;

  /// Last write.
  final DateTime updatedAt;

  /// The name shown to customers and in the driver's own header.
  String get fullName => '$firstName $lastName'.trim();

  /// Initials for the avatar.
  String get initials {
    final a = _initial(firstName);
    final b = _initial(lastName);
    final value = '$a$b';
    return value.isEmpty ? '؟' : value;
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '' : trimmed[0];
  }

  /// Whether the driver has a base point to measure distance from.
  bool get hasBase => lat != 0 || lng != 0;

  /// Copy with the given fields replaced.
  DriverProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    double? lat,
    double? lng,
    String? waterType,
    int? volumeM3,
    int? price,
    bool? active,
    DateTime? updatedAt,
  }) {
    return DriverProfile(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      phone: phone ?? this.phone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      waterType: waterType ?? this.waterType,
      volumeM3: volumeM3 ?? this.volumeM3,
      price: price ?? this.price,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// The document body written to `drivers/{uid}`.
  Map<String, dynamic> toFirestore() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'lat': lat,
        'lng': lng,
        'waterType': waterType,
        'volumeM3': volumeM3,
        'price': price,
        'active': active,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  /// Reads a document body back into a profile.
  factory DriverProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    return DriverProfile(
      uid: uid,
      firstName: (data['firstName'] as String?) ?? '',
      lastName: (data['lastName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      waterType: (data['waterType'] as String?) ?? WaterTypes.drinking,
      volumeM3: (data['volumeM3'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      active: (data['active'] as bool?) ?? false,
      createdAt: _date(created),
      updatedAt: _date(updated),
    );
  }

  static DateTime _date(Object? value) {
    return switch (value) {
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
      String s => DateTime.tryParse(s) ?? DateTime.now(),
      _ => DateTime.now(),
    };
  }
}
