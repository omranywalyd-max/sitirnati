/// A water-tanker driver offered in the browse list.
class Truck {
  /// Creates a truck card entry.
  const Truck({
    required this.id,
    required this.driverName,
    required this.waterType,
    required this.volumeM3,
    required this.price,
    required this.phone,
    required this.city,
  });

  /// Stable identifier.
  final String id;

  /// Driver's display name.
  final String driverName;

  /// Kind of water carried (drinking, well/irrigation, construction).
  final String waterType;

  /// Load size in cubic metres.
  final int volumeM3;

  /// Price per load in DZD.
  final int price;

  /// Contact phone number.
  final String phone;

  /// Home city shown on the card.
  final String city;
}
