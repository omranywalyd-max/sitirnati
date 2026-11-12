import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_bottom_navbar_plus/liquid_glass_bottom_navbar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/driver_offer.dart';
import '../models/order.dart';
import '../services/drivers_store.dart';
import '../services/orders_store.dart';
import '../services/overlay_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_morph_menu.dart';
import '../widgets/order_form_sheet.dart';
import '../widgets/order_success_dialog.dart';
import 'browse_page.dart';
import 'orders_page.dart';

/// Transparent system bars with light icons over the dark canvas.
const _overlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// Destinations shown by the bar.
///
/// The bar lays its items out left to right (its selection pill geometry is LTR
/// only) while Arabic reads right to left, so the list is ordered with the first
/// tab on the right and the index is mirrored in both directions.
const _barItems = <LiquidGlassBarItem>[
  LiquidGlassBarItem(
    icon: Icon(Icons.receipt_long_outlined),
    selectedIcon: Icon(Icons.receipt_long_rounded),
    label: 'طلبياتي',
  ),
  LiquidGlassBarItem(
    icon: Icon(Icons.water_drop_outlined),
    selectedIcon: Icon(Icons.water_drop_rounded),
    label: 'اطلب',
  ),
];

/// On this device family the Impeller shader returns opaque pixels, so the bar
/// uses the guaranteed-transparent BackdropFilter path.
///
/// The tint is the same smoked glass the cards use ([AppGlass.barTint]), which
/// is what makes the whole screen read as one material. It also fixes a real
/// contrast bug: with the package's 19%-white tint the bar sampled the content
/// scrolling behind it, so it turned teal over a card and the faint blue
/// selection capsule became invisible (measured 1.24:1 in the golden).
const _barSettings = LiquidGlassSettings(
  variant: GlassVariant.forcedFallback,
  glassColor: AppGlass.barTint,
  outlineIntensity: 1.0,
  lightIntensity: 0.5,
);

/// Bar contents: a faint blue selection capsule instead of the package's white
/// one, light cyan for the selected item and 85% white for the idle items.
///
/// Measured with `tool/contrast_check.mjs` on the bar's own smoked glass:
/// selected 12.6:1, idle 16.2:1, and the selected label still 6.9:1 on the
/// capsule it sits in — all well clear of 4.5:1 at the 10.5px label size.
const _barTheme = LiquidGlassBarTheme(
  pillColor: AppColors.barPill,
  iconColor: AppColors.barIdle,
  selectedIconColor: AppColors.barSelected,
  labelStyle: TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: AppColors.barIdle,
  ),
  selectedLabelStyle: TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: AppColors.barSelected,
  ),
);

/// Page index of the browse tab.
const _browsePage = 0;

/// Page index of the orders tab.
const _ordersPage = 1;

/// Where the "already announced" markers are kept, so a reinstall or a restart
/// does not replay an alert the customer already dismissed.
const _nearSeenKey = 'sitirnati_near_seen_v1';

/// The app shell: gradient canvas, the two tabs, the floating glass bar, and
/// the morphing glass menu pinned to the header.
///
/// It owns three streams and one side effect:
///
/// * the customer's own orders, for the list;
/// * every active driver, for the price board;
/// * the `nearAt` field on those orders, which raises the full-screen alert.
class HomeShell extends StatefulWidget {
  /// Creates the shell.
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _page = _browsePage;

  List<Order> _orders = const [];
  List<DriverOffer> _offers = const [];

  bool _loading = true;
  bool _offersLoading = true;

  StreamSubscription<List<Order>>? _ordersSub;
  StreamSubscription<List<DriverOffer>>? _offersSub;

  /// `orderId:nearAtMillis` for every alert already shown on this device.
  Set<String> _announced = <String>{};

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _offersSub?.cancel();
    super.dispose();
  }

  /// Paints the on-device cache first, then follows the server.
  ///
  /// The cache read is what makes a cold start instant; the Firestore streams
  /// are what make a driver's accept, a status change or a "I am near" show up
  /// without a refresh.
  Future<void> _boot() async {
    _announced = await _loadAnnounced();

    final cached = await OrdersStore.cached();
    if (!mounted) return;
    setState(() {
      _orders = cached;
      _loading = false;
    });

    _ordersSub = OrdersStore.watchCustomer().listen(
      (orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders;
          _loading = false;
        });
        unawaited(_maybeAnnounce(orders));
      },
      onError: (Object error) {
        debugPrint('OrdersStore stream error: $error');
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );

    _offersSub = DriversStore.watchActive().listen(
      (offers) {
        if (!mounted) return;
        setState(() {
          _offers = offers;
          _offersLoading = false;
        });
      },
      onError: (Object error) {
        debugPrint('DriversStore stream error: $error');
        if (!mounted) return;
        setState(() => _offersLoading = false);
      },
    );
  }

  static Future<Set<String>> _loadAnnounced() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_nearSeenKey) ?? const <String>[]).toSet();
  }

  Future<void> _rememberAnnounced(String key) async {
    _announced.add(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_nearSeenKey, _announced.toList(growable: false));
  }

  /// Raises the full-screen "the driver is near" alert, once per `nearAt`.
  ///
  /// The key includes the timestamp, so a driver who presses the button twice
  /// (two different `nearAt` values) does alert twice — that is a real second
  /// notification — while the same value seen again after a restart does not.
  ///
  /// One alert per snapshot: if two orders are somehow flagged, the newest is
  /// announced now and the other on the next snapshot, instead of two native
  /// activities stacking on top of each other.
  Future<void> _maybeAnnounce(List<Order> orders) async {
    for (final order in orders) {
      final near = order.nearAt;
      if (near == null) continue;
      if (order.status != OrderStatus.accepted) continue;

      final key = '${order.id}:${near.millisecondsSinceEpoch}';
      if (_announced.contains(key)) continue;

      // Registered before the await, so a second snapshot arriving while the
      // native screen is being prepared cannot announce the same order twice.
      await _rememberAnnounced(key);

      final granted = await OverlayService.hasPermission();
      if (!granted) {
        // No permission: the alert cannot be drawn over other apps, so say it in
        // the app the customer is already looking at rather than silently doing
        // nothing.
        _toast('${order.driverName} قريب منك. سيترنتي ما يقدرش يطلّع تنبيه '
            'فوق الشاشة حتى تشعل «العرض فوق التطبيقات».');
        return;
      }

      await OverlayService.showArrival(
        driverName: order.driverName,
        placeName: order.placeName,
        phone: order.driverPhone,
      );
      return;
    }
  }

  /// Bar index for a page index (two tabs, so the mapping is its own inverse).
  int _barIndex(int page) => page == _browsePage ? 1 : 0;

  int _pageForBarIndex(int index) => index == 1 ? _browsePage : _ordersPage;

  Future<void> _startOrder(DriverOffer offer) async {
    final order = await showOrderFormSheet(context, offer);
    if (order == null || !mounted) return;

    // Optimistic: the row appears before the write round-trips. The stream
    // below replaces this list with the server truth as soon as it lands, and
    // the write itself is queued locally when the phone has no network.
    setState(() => _orders = <Order>[order, ..._orders]);
    try {
      await OrdersStore.place(order);
    } catch (error) {
      debugPrint('OrdersStore.place failed: $error');
      if (!mounted) return;
      _toast('الطلبية تسجلت في الهاتف، بصح ما وصلتش للسواقين. '
          'تحقق من الاتصال.');
    }
    if (!mounted) return;

    // The order is already stored; the dialog confirms it and offers to jump to
    // the list. Nothing is written twice and dismissing it loses nothing.
    final openOrders = await showOrderSuccessDialog(context, order);
    if (!mounted) return;
    if (openOrders) setState(() => _page = _ordersPage);
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await _confirm(
      title: 'تلغي هذي الطلبية؟',
      message: order.hasDriver
          ? '${order.driverName} قبل الطلبية و يمكن راه في الطريق. '
              'إذا لغيتها، راح يشوف بلي ما تحتاجهاش.'
          : 'الطلب راح يتلغى و ما يبقاش يبان للسواقين. تقدر تعاود تطلب '
              'من جديد في أي وقت.',
      confirmLabel: 'الغي',
    );
    if (!confirmed || !mounted) return;

    final previous = _orders;
    setState(() {
      _orders = [
        for (final item in _orders)
          if (item.id == order.id)
            item.withStatus(OrderStatus.cancelled)
          else
            item,
      ];
    });
    try {
      await OrdersStore.cancel(order);
    } catch (error) {
      debugPrint('OrdersStore.cancel failed: $error');
      if (!mounted) return;
      setState(() => _orders = previous);
      _toast('ما قدرناش نلغيو الطلبية. تحقق من الاتصال و عاود.');
      return;
    }
    if (!mounted) return;
    _toast('الطلبية تلغات.');
  }

  Future<void> _deleteOrder(Order order) async {
    final confirmed = await _confirm(
      title: 'تحذف هذي الطلبية من السجل؟',
      message: 'الطلبية راح تمسح من «طلبياتي» على هذا الهاتف. '
          'ما تقدرش ترجعها.',
      confirmLabel: 'امسح',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _orders = _orders.where((o) => o.id != order.id).toList();
    });
    try {
      await OrdersStore.delete(order);
    } catch (error) {
      debugPrint('OrdersStore.delete failed: $error');
      if (!mounted) return;
      _toast('ما قدرناش نمسحو الطلبية من السيرفر.');
      return;
    }
    if (!mounted) return;
    _toast('الطلبية تمسحت.');
  }

  Future<void> _clearOrders() async {
    if (_orders.isEmpty) {
      _toast('ما كاينش طلبيات باش نمسحو.');
      return;
    }
    final confirmed = await _confirm(
      title: 'تمسح كل الطلبيات؟',
      message: 'راح تمسح ${_orders.length} طلبية من سجلك. هذا ما يتصلحش.',
      confirmLabel: 'امسح الكل',
    );
    if (!confirmed || !mounted) return;

    setState(() => _orders = const []);
    try {
      await OrdersStore.clearMine();
    } catch (error) {
      debugPrint('OrdersStore.clearMine failed: $error');
      if (!mounted) return;
      _toast('ما قدرناش نمسحو كلشي من السيرفر. تحقق من الاتصال.');
      return;
    }
    if (!mounted) return;
    _toast('كل الطلبيات تمسحو.');
  }

  Future<void> _callDriver(Order order) async {
    final phone = order.driverPhone;
    if (phone.isEmpty) {
      _toast('ما عندناش رقم السائق. جرّب تعاود شوية.');
      return;
    }
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) {
      _toast('ما قدرناش نفتحو الاتصال. الرقم: $phone');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('خلّي'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حول سيترنتي'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيترنتي يوصلك بصهريج الماء: تشوف السواقين المتوفرين دابا '
              'بالسعر تاعهم، تحدد مكانك على الخريطة، وتبعث الطلب.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            SizedBox(height: AppSpace.md),
            Text(
              'بلا حساب وبلا تسجيل دخول. الطلب يوصل للسواقين المتوفرين '
              'كاملين، و أول واحد يقبلو ياخذو و يعيّطلك.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            SizedBox(height: AppSpace.md),
            Text(
              'كي يوصل السائق قريب منك، يطلعلك تنبيه على كامل الشاشة — '
              'هذا علاش التطبيق يطلب إذن «العرض فوق التطبيقات».',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            SizedBox(height: AppSpace.md),
            Text(
              'الإصدار 1.0.0',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('واخا'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: GradientBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          // No [BackdropGroup] here any more: nothing in the body blurs its
          // backdrop (cards and buttons pass `blur: 0`, because they sit on an
          // already-soft canvas), so a shared capture would be a full-screen
          // layer per frame for zero pixels of difference. The bar and the
          // sheets keep their own live frost, where content really does move
          // behind the glass.
          body: Stack(
            children: [
              IndexedStack(
                index: _page,
                children: [
                  BrowsePage(
                    offers: _offers,
                    loading: _offersLoading,
                    onOrder: _startOrder,
                  ),
                  OrdersPage(
                    orders: _orders,
                    loading: _loading,
                    onCancel: _cancelOrder,
                    onDelete: _deleteOrder,
                    onCall: _callDriver,
                    onBrowse: () => setState(() => _page = _browsePage),
                  ),
                ],
              ),
              GlassMorphMenu(
                anchor: Alignment.topLeft,
                padding: const EdgeInsets.only(
                  top: AppSpace.md,
                  left: AppSpace.lg,
                ),
                items: [
                  GlassMenuItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'طلبياتي',
                    onTap: () => setState(() => _page = _ordersPage),
                  ),
                  GlassMenuItem(
                    icon: Icons.delete_sweep_rounded,
                    label: 'مسح الطلبيات',
                    onTap: _clearOrders,
                  ),
                  GlassMenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'حول سيترنتي',
                    onTap: _showAbout,
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: Directionality(
            textDirection: TextDirection.ltr,
            child: LiquidGlassBottomBar(
              items: _barItems,
              selectedIndex: _barIndex(_page),
              onDestinationSelected: (index) =>
                  setState(() => _page = _pageForBarIndex(index)),
              settings: _barSettings,
              theme: _barTheme,
            ),
          ),
        ),
      ),
    );
  }
}
