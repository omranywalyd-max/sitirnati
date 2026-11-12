/// A water delivery order placed by the customer.
class Order {
  /// Creates an order.
  const Order({
    required this.id,
    required this.truckId,
    required this.driverName,
    required this.waterType,
    required this.volumeM3,
    required this.price,
    required this.customerName,
    required this.phone,
    required this.placeName,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.status = OrderStatus.sent,
  });

  /// Stable identifier.
  final String id;

  /// Truck this order was placed on.
  final String truckId;

  /// Driver name at order time.
  final String driverName;

  /// Water type at order time.
  final String waterType;

  /// Load size in cubic metres.
  final int volumeM3;

  /// Price in DZD.
  final int price;

  /// Customer full name.
  final String customerName;

  /// Customer phone.
  final String phone;

  /// Human-readable place label typed by the customer.
  final String placeName;

  /// Pinned latitude.
  final double lat;

  /// Pinned longitude.
  final double lng;

  /// When the order was placed.
  final DateTime createdAt;

  /// Current order state.
  final OrderStatus status;

  /// Serialises to a JSON map for local cache storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'truckId': truckId,
        'driverName': driverName,
        'waterType': waterType,
        'volumeM3': volumeM3,
        'price': price,
        'customerName': customerName,
        'phone': phone,
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  /// Restores an order from cached JSON.
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      truckId: json['truckId'] as String,
      driverName: json['driverName'] as String,
      waterType: json['waterType'] as String,
      volumeM3: (json['volumeM3'] as num).toInt(),
      price: (json['price'] as num).toInt(),
      customerName: json['customerName'] as String,
      phone: json['phone'] as String,
      placeName: json['placeName'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.sent,
      ),
    );
  }
}

/// Lifecycle of an order. No backend yet — new orders land in [sent].
enum OrderStatus {
  /// Request created and queued for the driver.
  sent('مُرسل'),

  /// Driver accepted the request.
  accepted('مقبول'),

  /// Water delivered.
  delivered('وصل');

  const OrderStatus(this.label);

  /// Arabic label shown in the UI.
  final String label;
}
