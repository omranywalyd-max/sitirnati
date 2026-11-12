import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitirnati/main.dart';
import 'package:sitirnati/models/order.dart';
import 'package:sitirnati/widgets/order_success_dialog.dart';

/// Renders the real screens at a phone size and compares them against the
/// checked-in images in `test/goldens`.
///
/// Regenerate after an intentional visual change:
/// `flutter test --update-goldens test/visual_test.dart`
Future<void> _loadTajawal() async {
  final loader = FontLoader('Tajawal');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Tajawal-$weight.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadTajawal);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LiquidGlassEngine.liteGlassOnSkia = true;
    LiquidGlassEngine.liteGlassOnImpeller = true;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SitirnatiApp());
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('browse tab', (tester) async {
    await pumpApp(tester);
    await expectLater(
      find.byType(SitirnatiApp),
      matchesGoldenFile('goldens/browse.png'),
    );
  });

  testWidgets('orders tab, empty', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('طلبياتي').last);
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(SitirnatiApp),
      matchesGoldenFile('goldens/orders_empty.png'),
    );
  });

  testWidgets('order form sheet', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('اطلب الآن').first);
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(SitirnatiApp),
      matchesGoldenFile('goldens/order_form.png'),
    );
  });

  testWidgets('order success dialog', (tester) async {
    await pumpApp(tester);
    final order = Order(
      id: 'golden-order',
      truckId: 't1',
      driverName: 'كريم بلقاسم',
      waterType: 'ماء صالح للشرب',
      volumeM3: 10,
      price: 4500,
      customerName: 'أمين بوقرة',
      phone: '0550123456',
      placeName: 'حي 5 جويلية، عمارة 12',
      lat: 36.75381,
      lng: 3.05877,
      createdAt: DateTime(2026, 11, 12, 14, 5),
    );
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(showOrderSuccessDialog(context, order));
    await tester.pump();
    // Long enough for the route transition and the drawn check to finish.
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(SitirnatiApp),
      matchesGoldenFile('goldens/order_success.png'),
    );
  });
}
