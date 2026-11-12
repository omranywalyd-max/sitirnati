/// One available driver, as the customer sees them on the browse tab.
///
/// This is a read-only projection of the driver's own document at
/// `drivers/{uid}`: only the fields a customer needs to choose an offer. The
/// email and the account state stay on the driver's side of the product.
class DriverOffer {
  /// Creates an offer.
  const DriverOffer({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.waterType,
    required this.volumeM3,
    required this.price,
    required this.lat,
    required this.lng,
  });

  /// The driver's Firebase Auth uid, also the document id.
  final String uid;

  /// Given name.
  final String firstName;

  /// Family name.
  final String lastName;

  /// Contact phone, digits only.
  final String phone;

  /// Water grade carried: `صالح للشرب` or `غير صالح للشرب`.
  final String waterType;

  /// Load size in cubic metres.
  final int volumeM3;

  /// Price per load in dinars.
  final int price;

  /// Base latitude.
  final double lat;

  /// Base longitude.
  final double lng;

  /// The name shown on the card.
  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'سائق سيترنتي' : name;
  }

  /// First letter of the name, for the avatar.
  String get initial {
    final name = fullName;
    return name.isEmpty ? '؟' : name[0];
  }

  /// Whether the driver has a base point to measure distance from.
  bool get hasBase => lat != 0 || lng != 0;

  /// Reads a `drivers/{uid}` document.
  factory DriverOffer.fromFirestore(String uid, Map<String, dynamic> data) {
    return DriverOffer(
      uid: uid,
      firstName: (data['firstName'] as String?) ?? '',
      lastName: (data['lastName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      waterType: (data['waterType'] as String?) ?? '',
      volumeM3: (data['volumeM3'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}
