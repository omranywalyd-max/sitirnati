import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_bottom_navbar_plus/liquid_glass_bottom_navbar_plus.dart';

import '../models/order.dart';
import '../models/truck.dart';
import '../services/orders_store.dart';
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
/// The bar lays its items out left to right (its selection pill geometry is
/// LTR only) while Arabic reads right to left, so the list is ordered with the
/// first tab on the right and the index is mirrored in both directions.
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

/// The app shell: gradient canvas, the two tabs, the floating glass bar, and
/// the morphing glass menu pinned to the header.
class HomeShell extends StatefulWidget {
  /// Creates the shell.
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _page = _browsePage;
  List<Order> _orders = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await OrdersStore.load();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  /// Bar index for a page index (two tabs, so the mapping is its own inverse).
  int _barIndex(int page) => page == _browsePage ? 1 : 0;

  int _pageForBarIndex(int index) => index == 1 ? _browsePage : _ordersPage;

  Future<void> _startOrder(Truck truck) async {
    final order = await showOrderFormSheet(context, truck);
    if (order == null || !mounted) return;

    final next = <Order>[order, ..._orders];
    setState(() => _orders = next);
    await OrdersStore.save(next);
    if (!mounted) return;

    // The order is already stored; the dialog confirms it and offers to jump to
    // the list. Nothing is written twice and dismissing it loses nothing.
    final openOrders = await showOrderSuccessDialog(context, order);
    if (!mounted) return;
    if (openOrders) setState(() => _page = _ordersPage);
  }

  Future<void> _deleteOrder(Order order) async {
    final confirmed = await _confirm(
      title: 'تحذف هذي الطلبية؟',
      message:
          'طلبية ${order.driverName} راح تمسح من هذا الهاتف. ما تقدرش ترجعها.',
      confirmLabel: 'امسح',
    );
    if (!confirmed || !mounted) return;

    final next = _orders.where((o) => o.id != order.id).toList();
    setState(() => _orders = next);
    await OrdersStore.save(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('الطلبية تمسحت.')));
  }

  Future<void> _clearOrders() async {
    if (_orders.isEmpty) {
      _toast('ما كاينش طلبيات باش نمسحو.');
      return;
    }
    final confirmed = await _confirm(
      title: 'تمسح كل الطلبيات؟',
      message:
          'راح تمسح ${_orders.length} طلبية من هذا الهاتف. '
          'هذا ما يتصلحش.',
      confirmLabel: 'امسح الكل',
    );
    if (!confirmed || !mounted) return;

    await OrdersStore.clear();
    if (!mounted) return;
    setState(() => _orders = const []);
    _toast('كل الطلبيات تمسحو.');
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
        content: Text(message),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'سيترنتي يوصلك بصهريج الماء: تختار السائق، تحدد مكانك '
              'على الخريطة، وتبعث الطلب.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            SizedBox(height: AppSpace.md),
            Text(
              'بلا حساب وبلا تسجيل دخول: كل طلبياتك تتخزن في هذا الهاتف.',
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
                  BrowsePage(onOrderTruck: _startOrder),
                  OrdersPage(
                    orders: _orders,
                    loading: _loading,
                    onDelete: _deleteOrder,
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
