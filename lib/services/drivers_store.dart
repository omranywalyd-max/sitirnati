import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/driver_offer.dart';

/// The customer's window on the drivers.
///
/// One query: every driver document whose `active` flag is on. The flag is
/// written by the driver app, so a driver who goes off shift disappears from
/// this list within a second — no refresh, no polling.
///
/// No server-side `orderBy`: a `where` plus an `orderBy` on a different field
/// needs a composite index, and this list is small. Sorting in Dart keeps the
/// project index-free.
abstract final class DriversStore {
  static CollectionReference<Map<String, dynamic>> get _drivers =>
      FirebaseFirestore.instance.collection('drivers');

  /// Available drivers, cheapest first.
  ///
  /// Price ascending is deliberate: the list answers "what will this cost me?"
  /// before it answers "who is it?", which is the order a customer asks those
  /// questions in.
  ///
  /// Errors are **not** swallowed here: the shell's `onError` is what stops the
  /// "loading drivers" placeholder, and a stream that hides its failure would
  /// leave the customer looking at a spinner forever.
  static Stream<List<DriverOffer>> watchActive() {
    return _drivers.where('active', isEqualTo: true).snapshots().map(
      (snapshot) {
        final offers = snapshot.docs
            .map((doc) => DriverOffer.fromFirestore(doc.id, doc.data()))
            .where((offer) => offer.price > 0)
            .toList()
          ..sort((a, b) {
            final byPrice = a.price.compareTo(b.price);
            if (byPrice != 0) return byPrice;
            return a.fullName.compareTo(b.fullName);
          });
        return offers;
      },
    );
  }
}
