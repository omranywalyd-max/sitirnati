/// A water delivery order, as the customer sees it.
///
/// The order is the single document the two apps share, at `orders/{id}`. The
/// customer writes it with `driverUid` empty — that is the *pool*: every
/// registered driver reads the pool, and the first one to accept claims it by
/// writing their own uid. From that moment the document belongs to that driver.
///
/// Nothing about the driver is guessed at creation time. The offer terms
/// (`waterType`, `volumeM3`, `price`) come from the card the customer tapped,
/// and they are overwritten by the driver's own figures when the order is
/// claimed, so the order always reflects the deal that was actually made.
class Order {
  /// Creates an order.
  const Order({
    required this.id,
    required this.customerUid,
    required this.customerName,
    required this.phone,
    required this.placeName,
    required this.lat,
    required this.lng,
    required this.waterType,
    required this.volumeM3,
    required this.price,
    required this.createdAt,
    this.driverUid = '',
    this.driverName = '',
    this.driverPhone = '',
    this.status = OrderStatus.sent,
    this.nearAt,
  });

  /// Stable identifier: the Firestore document id.
  final String id;

  /// Firebase Auth uid of the customer who placed it.
  ///
  /// The security rules use it to decide who may read and cancel the order, so
  /// it is written once at creation and never updated.
  final String customerUid;

  /// Customer full name.
  final String customerName;

  /// Customer phone, digits only.
  final String phone;

  /// Human-readable place label typed by the customer.
  final String placeName;

  /// Pinned latitude.
  final double lat;

  /// Pinned longitude.
  final double lng;

  /// Water grade requested.
  final String waterType;

  /// Load size in cubic metres.
  final int volumeM3;

  /// Price in dinars.
  final int price;

  /// When the order was placed.
  final DateTime createdAt;

  /// Uid of the driver who accepted it; empty while it waits in the pool.
  final String driverUid;

  /// Name of the driver who accepted it; empty while it waits in the pool.
  final String driverName;

  /// Phone of the driver who accepted it; empty while it waits in the pool.
  ///
  /// Written by the driver app at claim time, so the customer can call back the
  /// person who is actually coming instead of the operator.
  final String driverPhone;

  /// Current order state.
  final OrderStatus status;

  /// When the driver pressed "أنا قريب", or `null` while they are not.
  ///
  /// The customer app watches this field: the moment it turns non-null it
  /// raises the full-screen "the driver is near" alert, once per value.
  final DateTime? nearAt;

  /// Whether a driver has claimed the order yet.
  bool get hasDriver => driverUid.isNotEmpty;

  /// Whether the customer can still cancel it.
  bool get canCancel => status == OrderStatus.sent || status == OrderStatus.accepted;

  /// Copy with a new [status].
  Order withStatus(OrderStatus next) => Order(
        id: id,
        customerUid: customerUid,
        customerName: customerName,
        phone: phone,
        placeName: placeName,
        lat: lat,
        lng: lng,
        waterType: waterType,
        volumeM3: volumeM3,
        price: price,
        createdAt: createdAt,
        driverUid: driverUid,
        driverName: driverName,
        driverPhone: driverPhone,
        status: next,
        nearAt: nearAt,
      );

  /// Serialises to a JSON map for the on-device cache.
  Map<String, dynamic> toJson() => {
        'id': id,
        'customerUid': customerUid,
        'customerName': customerName,
        'phone': phone,
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        'waterType': waterType,
        'volumeM3': volumeM3,
        'price': price,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'driverUid': driverUid,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'status': status.name,
        'nearAt': nearAt?.millisecondsSinceEpoch,
      };

  /// Restores an order from the on-device cache.
  factory Order.fromJson(Map<String, dynamic> json) {
    final near = json['nearAt'];
    return Order(
      id: json['id'] as String,
      customerUid: (json['customerUid'] as String?) ?? '',
      customerName: (json['customerName'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      placeName: (json['placeName'] as String?) ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      waterType: (json['waterType'] as String?) ?? '',
      volumeM3: (json['volumeM3'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      createdAt: _date(json['createdAt']),
      driverUid: (json['driverUid'] as String?) ?? '',
      driverName: (json['driverName'] as String?) ?? '',
      driverPhone: (json['driverPhone'] as String?) ?? '',
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.sent,
      ),
      nearAt: near == null ? null : _date(near),
    );
  }

  /// The document body written to `orders/{id}`.
  ///
  /// `customerUid`, `driverUid` and `status` are part of the write on purpose:
  /// the rules reject a document whose owner is not the caller, whose driver is
  /// already set, or whose state is not `sent`, so a client cannot forge any of
  /// them.
  ///
  /// Timestamps are epoch milliseconds rather than `Timestamp` values because
  /// both apps parse them without a platform conversion, and a plain int
  /// compares and sorts the same way in Firestore and in Dart.
  Map<String, dynamic> toFirestore() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'customerUid': customerUid,
      'customerName': customerName,
      'phone': phone,
      'placeName': placeName,
      'lat': lat,
      'lng': lng,
      'waterType': waterType,
      'volumeM3': volumeM3,
      'price': price,
      'driverUid': driverUid,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': now,
      'nearAt': nearAt?.millisecondsSinceEpoch,
    };
  }

  /// Reads a document body back into a model.
  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    final near = data['nearAt'];
    return Order(
      id: id,
      customerUid: (data['customerUid'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      placeName: (data['placeName'] as String?) ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      waterType: (data['waterType'] as String?) ?? '',
      volumeM3: (data['volumeM3'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      createdAt: _date(data['createdAt']),
      driverUid: (data['driverUid'] as String?) ?? '',
      driverName: (data['driverName'] as String?) ?? '',
      driverPhone: (data['driverPhone'] as String?) ?? '',
      status: OrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => OrderStatus.sent,
      ),
      nearAt: near == null ? null : _date(near),
    );
  }

  /// Accepts every shape a date can arrive in: epoch millis from this app, a
  /// `Timestamp` from the console, or an ISO string from the cache.
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
///
/// The customer creates it as [sent]; a driver claims it and moves it along the
/// edges encoded in `firestore.rules`; the customer may cancel it until it is
/// delivered.
enum OrderStatus {
  /// Created and waiting for a driver to claim it.
  sent('في انتظار سائق'),

  /// Claimed by a driver and on its way.
  accepted('جاية في الطريق'),

  /// Water delivered.
  delivered('وصلت'),

  /// Cancelled by the customer.
  cancelled('ملغاة');

  const OrderStatus(this.label);

  /// Arabic label shown in the UI.
  final String label;

  /// Whether the order is still waiting for a driver.
  bool get isWaiting => this == OrderStatus.sent;

  /// Whether nothing else will happen to this order.
  bool get isClosed =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;
}
