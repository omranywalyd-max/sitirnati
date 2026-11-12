/// A water delivery order, as the driver sees it.
///
/// The order is the single document the two apps share. The customer writes it
/// with `driverUid` empty — that is the *pool*: every signed-in driver reads the
/// pool and the first one to accept claims it by writing their own uid into
/// `driverUid`. From then on the document belongs to that driver.
///
/// The fields the driver needs to act (`customerName`, `phone`, `placeName`,
/// `lat`, `lng`) are copied into the document at creation time, so the driver
/// never has to read the customer's profile — which the rules do not expose.
class DriverOrder {
  /// Creates an order view.
  const DriverOrder({
    required this.id,
    required this.customerUid,
    required this.customerName,
    required this.phone,
    required this.placeName,
    required this.lat,
    required this.lng,
    required this.driverUid,
    required this.driverName,
    required this.waterType,
    required this.volumeM3,
    required this.price,
    required this.status,
    required this.createdAt,
    this.nearAt,
  });

  /// Firestore document id.
  final String id;

  /// Anonymous uid of the customer who placed it.
  final String customerUid;

  /// Customer's full name.
  final String customerName;

  /// Customer's phone, digits only.
  final String phone;

  /// Human-readable place label.
  final String placeName;

  /// Delivery latitude.
  final double lat;

  /// Delivery longitude.
  final double lng;

  /// Uid of the driver who accepted it; empty while it sits in the pool.
  final String driverUid;

  /// Driver name captured when the order was claimed.
  final String driverName;

  /// Water grade requested.
  final String waterType;

  /// Load size in cubic metres.
  final int volumeM3;

  /// Price in dinars, as the driver quoted it.
  final int price;

  /// Current state.
  final OrderStatus status;

  /// When the customer placed it.
  final DateTime createdAt;

  /// When the driver pressed "أنا قريب" — the customer app watches this field
  /// and raises its full-screen alert. `null` until the driver is near.
  final DateTime? nearAt;

  /// Whether the order is still in the pool.
  bool get isPool => driverUid.isEmpty;

  /// Whether the driver can still move it forward.
  bool get isRunning => status == OrderStatus.accepted;

  /// Reads a document body back into a model.
  factory DriverOrder.fromFirestore(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final near = data['nearAt'];
    return DriverOrder(
      id: id,
      customerUid: (data['customerUid'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      placeName: (data['placeName'] as String?) ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      driverUid: (data['driverUid'] as String?) ?? '',
      driverName: (data['driverName'] as String?) ?? '',
      waterType: (data['waterType'] as String?) ?? '',
      volumeM3: (data['volumeM3'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => OrderStatus.sent,
      ),
      createdAt: _date(created),
      nearAt: near == null ? null : _date(near),
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

/// Lifecycle of an order.
enum OrderStatus {
  /// Created by the customer, waiting for a driver to claim it.
  sent('مُرسلة'),

  /// Claimed by this driver.
  accepted('جارية'),

  /// Delivered.
  delivered('وصلت'),

  /// Turned down by the driver, or cancelled by the customer.
  cancelled('ملغاة');

  const OrderStatus(this.label);

  /// Arabic label shown in the UI.
  final String label;

  /// Whether nothing else will happen to this order.
  bool get isClosed =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;
}
