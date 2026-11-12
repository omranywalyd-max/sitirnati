import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitirnati/main.dart';

void main() {
  setUp(() {
    // The order cache is device storage; in a widget test it is memory.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // No fragment shaders in the test harness: the same lite-glass path the
    // app uses on the phone.
    LiquidGlassEngine.liteGlassOnSkia = true;
    LiquidGlassEngine.liteGlassOnImpeller = true;
  });

  testWidgets('opens on the browse tab with the driver list', (tester) async {
    await tester.pumpWidget(const SitirnatiApp());
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('سيترنتي'), findsOneWidget);
    expect(find.text('السائقون المتوفرون'), findsOneWidget);
    expect(find.text('كريم بلقاسم'), findsOneWidget);
    expect(find.text('اطلب الآن'), findsWidgets);
  });

  testWidgets('exposes both destinations in the glass bar', (tester) async {
    await tester.pumpWidget(const SitirnatiApp());
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('اطلب'), findsWidgets);
    expect(find.text('طلبياتي'), findsWidgets);
  });
}
