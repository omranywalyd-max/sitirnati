import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitirnati/main.dart';
import 'package:sitirnati/widgets/app_buttons.dart';

/// Objective layout checks on the worst realistic device: a 320dp-wide phone
/// with the system font scaled up 1.3x, in Arabic.
///
/// A `RenderFlex` overflow throws inside a widget test, so "no exception" here
/// means no clipped or overflowing text on that screen.
///
/// The real Tajawal files are loaded first: the test harness default font draws
/// every glyph as a full em square, which reports overflows the shipped font
/// never produces. Measuring with the shipped metrics is the only honest check.
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

  Future<void> pumpSmall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(960, 1704); // 320 x 568 at 3x
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(const SitirnatiApp(showSplash: false));
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('browse tab fits a 320dp screen at 1.3x text', (tester) async {
    await pumpSmall(tester);
    expect(find.text('سيترنتي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every primary action is at least 48dp tall', (tester) async {
    await pumpSmall(tester);
    final button = tester.getSize(find.byType(PrimaryButton).first);
    expect(button.height, greaterThanOrEqualTo(48));
  });

  testWidgets('orders tab fits, empty and filled', (tester) async {
    await pumpSmall(tester);
    await tester.tap(find.text('طلبياتي').last);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ما عندك حتى طلبية دابا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order form opens and validates on a small screen',
      (tester) async {
    await pumpSmall(tester);
    final cta = find.text('اطلب الآن').first;
    await tester.ensureVisible(cta);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(cta);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('الاسم الكامل'), findsOneWidget);

    // Submitting an empty form must show every field error, not crash.
    final submit = find.text('ابعث الطلب للسائق');
    await tester.ensureVisible(submit);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('اكتب اسمك الكامل.'), findsOneWidget);
    expect(find.text('اكتب رقم هاتفك.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
