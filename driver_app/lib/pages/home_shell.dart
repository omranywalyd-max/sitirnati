import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_bottom_navbar_plus/liquid_glass_bottom_navbar_plus.dart';

import '../models/driver_profile.dart';
import '../models/order.dart';
import '../services/driver_auth.dart';
import '../services/driver_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/launchers.dart';
import '../widgets/glass_morph_menu.dart';
import 'edit_profile_page.dart';
import 'incoming_page.dart';
import 'my_orders_page.dart';

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
    icon: Icon(Icons.inbox_outlined),
    selectedIcon: Icon(Icons.inbox_rounded),
    label: 'الطلبات',
  ),
];

/// On this device family the Impeller shader returns opaque pixels, so the bar
/// uses the guaranteed-transparent BackdropFilter path with the same smoked
/// glass the cards use.
const _barSettings = LiquidGlassSettings(
  variant: GlassVariant.forcedFallback,
  glassColor: AppGlass.barTint,
  outlineIntensity: 1.0,
  lightIntensity: 0.5,
);

/// Bar contents: a faint blue selection capsule, light cyan for the selected
/// item and 85% white for the idle items.
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

/// Page index of the incoming-orders tab.
const _incomingPage = 0;

/// Page index of the "my orders" tab.
const _myOrdersPage = 1;

/// The driver's home: the gradient canvas, the header, the two tabs, the
/// floating glass bar and the morphing menu.
///
/// It owns every Firestore write the driver makes, so the two tabs stay
/// presentational and the busy state is shared: accepting an order and marking
/// another one delivered can never run at the same time from the same screen.
class HomeShell extends StatefulWidget {
  /// Creates the shell for the signed-in [profile].
  const HomeShell({super.key, required this.profile});

  /// The driver, as the profile stream last reported it.
  final DriverProfile profile;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _page = _incomingPage;

  List<DriverOrder> _pool = const [];
  List<DriverOrder> _mine = const [];
  Set<String> _dismissed = const {};

  bool _poolLoading = true;
  bool _mineLoading = true;

  String? _busyId;
  bool _activeBusy = false;
  bool? _activeOverride;

  StreamSubscription<List<DriverOrder>>? _poolSub;
  StreamSubscription<List<DriverOrder>>? _mineSub;

  DriverProfile get _profile => widget.profile;

  /// The switch position: the optimistic value while a write is in flight,
  /// otherwise what the server says.
  bool get _active => _activeOverride ?? _profile.active;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Once the server agrees with the optimistic flip, stop overriding it.
    final override = _activeOverride;
    if (override != null && widget.profile.active == override) {
      _activeOverride = null;
    }
  }

  @override
  void dispose() {
    _poolSub?.cancel();
    _mineSub?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    _dismissed = await DriverStore.dismissed();
    if (!mounted) return;
    setState(() {});

    _poolSub = DriverStore.watchPool().listen(
      (orders) {
        if (!mounted) return;
        setState(() {
          _pool = orders;
          _poolLoading = false;
        });
      },
      onError: (Object error) {
        debugPrint('HomeShell.watchPool: $error');
        if (!mounted) return;
        setState(() => _poolLoading = false);
      },
    );

    _mineSub = DriverStore.watchMine(_profile.uid).listen(
      (orders) {
        if (!mounted) return;
        setState(() {
          _mine = orders;
          _mineLoading = false;
        });
      },
      onError: (Object error) {
        debugPrint('HomeShell.watchMine: $error');
        if (!mounted) return;
        setState(() => _mineLoading = false);
      },
    );
  }

  /// Bar index for a page index (two tabs, so the mapping is its own inverse).
  int _barIndex(int page) => page == _incomingPage ? 1 : 0;

  int _pageForBarIndex(int index) => index == 1 ? _incomingPage : _myOrdersPage;

  // --------------------------------------------------------------- actions --

  Future<void> _toggleActive(bool value) async {
    if (_activeBusy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeOverride = value;
      _activeBusy = true;
    });
    try {
      await DriverStore.setActive(_profile.uid, value);
      if (!mounted) return;
      _toast(
        value
            ? 'وليت نشط. الزبائن يشوفوك و الطلبات توصلك.'
            : 'وليت غير نشط. ما راح توصلكش طلبات جديدة.',
      );
    } catch (error) {
      debugPrint('HomeShell.setActive: $error');
      if (!mounted) return;
      setState(() => _activeOverride = null);
      _toast('ما قدرناش نبدلو الحالة. تحقق من الاتصال و عاود.');
    } finally {
      if (mounted) setState(() => _activeBusy = false);
    }
  }

  Future<void> _accept(DriverOrder order) async {
    if (_busyId != null) return;
    setState(() => _busyId = order.id);
    try {
      await DriverStore.accept(order, _profile);
      if (!mounted) return;
      _toast('قبلت الطلبية. تلقاها في «طلبياتي».');
    } catch (error) {
      debugPrint('HomeShell.accept: $error');
      if (!mounted) return;
      _toast('ما قدرناش نقبلو الطلبية. يمكن سائق آخر سبقك — عاود شوف اللائحة.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(DriverOrder order) async {
    try {
      await DriverStore.dismiss(order.id);
    } catch (error) {
      debugPrint('HomeShell.dismiss: $error');
    }
    if (!mounted) return;
    setState(() => _dismissed = {..._dismissed, order.id});
    _toast('الطلب تخبى من عندك. باقي متاح لسواقين آخرين.');
  }

  Future<void> _showMap(DriverOrder order) async {
    final opened = await openInMaps(
      lat: order.lat,
      lng: order.lng,
      label: order.placeName,
    );
    if (!opened && mounted) {
      _toast('ما لقيناش تطبيق خرائط في الهاتف.');
    }
  }

  Future<void> _call(DriverOrder order) async {
    final opened = await callPhone(order.phone);
    if (!opened && mounted) {
      _toast('ما قدرناش نفتحو الاتصال. تحقق من الرقم.');
    }
  }

  Future<void> _markNear(DriverOrder order) async {
    if (_busyId != null) return;
    setState(() => _busyId = order.id);
    try {
      await DriverStore.markNear(order.id);
      if (!mounted) return;
      _toast('بعثنا للزبون: «السائق قريب». راح تطلعلو شاشة كاملة.');
    } catch (error) {
      debugPrint('HomeShell.markNear: $error');
      if (!mounted) return;
      _toast('ما قدرناش نبعثو التبليغ. تحقق من الاتصال و عاود.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _markDelivered(DriverOrder order) async {
    if (_busyId != null) return;
    final confirmed = await _confirm(
      title: 'تم إيصال الطلب؟',
      message: 'راح تتسجل الطلبية كـ«منتهية» و تنتقل للسجل. '
          'ما تقدرش ترجعها لـ«جارية».',
      confirmLabel: 'وصلت',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = order.id);
    try {
      await DriverStore.markDelivered(order.id);
      if (!mounted) return;
      _toast('تسجلت الطلبية كـ«منتهية». يعطيك الصحة.');
    } catch (error) {
      debugPrint('HomeShell.markDelivered: $error');
      if (!mounted) return;
      _toast('ما قدرناش نسجلو الطلبية. تحقق من الاتصال و عاود.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProfilePage(profile: _profile),
      ),
    );
    if (saved == true && mounted) _toast('تسجلت التعديلات.');
  }

  Future<void> _showAdminContact() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معلومات اتصال الادمن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إذا صار مشكل في الحساب ولا في الطلبيات، اتصل بالمشغّل:',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: AppSpace.md),
            SelectableText(
              formatPhone(DriverStore.adminPhone),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 0.6,
              ),
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('واخا'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              callPhone(DriverStore.adminPhone);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('اتصل'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await _confirm(
      title: 'تسجيل الخروج؟',
      message: 'راح تخرج من الحساب. كي تعاود تدخل، تلقى طلبياتك كيفما كانت.',
      confirmLabel: 'اخرج',
    );
    if (!confirmed) return;
    await DriverAuth.signOut();
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

  @override
  Widget build(BuildContext context) {
    // Only orders still waiting for a driver, minus the ones this phone hid.
    final pool = _pool
        .where((order) =>
            order.status == OrderStatus.sent &&
            !_dismissed.contains(order.id))
        .toList(growable: false);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: GradientBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: Stack(
            children: [
              Column(
                children: [
                  _Header(profile: _profile, active: _active),
                  Expanded(
                    child: IndexedStack(
                      index: _page,
                      children: [
                        IncomingPage(
                          profile: _profile,
                          orders: pool,
                          loading: _poolLoading,
                          active: _active,
                          activeBusy: _activeBusy,
                          busyId: _busyId,
                          onToggleActive: _toggleActive,
                          onAccept: _accept,
                          onReject: _reject,
                          onShowMap: _showMap,
                        ),
                        MyOrdersPage(
                          profile: _profile,
                          orders: _mine,
                          loading: _mineLoading,
                          busyId: _busyId,
                          onCall: _call,
                          onShowMap: _showMap,
                          onNear: _markNear,
                          onDelivered: _markDelivered,
                        ),
                      ],
                    ),
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
                    icon: Icons.person_outline_rounded,
                    label: 'تعديل معلومات الحساب',
                    onTap: _editProfile,
                  ),
                  GlassMenuItem(
                    icon: Icons.support_agent_rounded,
                    label: 'معلومات اتصال الادمن',
                    onTap: _showAdminContact,
                  ),
                  GlassMenuItem(
                    icon: Icons.logout_rounded,
                    label: 'تسجيل الخروج',
                    onTap: _signOut,
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

/// The driver's own line at the top of both tabs: who is signed in, whether
/// they are available, and the offer customers see.
class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.active});

  final DriverProfile profile;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = profile.firstName.trim().isEmpty
        ? 'سائق سيترنتي'
        : profile.firstName.trim();

    return SafeArea(
      bottom: false,
      // 80 on the physical left keeps the header clear of the 52dp morph menu
      // that is pinned to that corner.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          80,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentSoft, Color(0x0D5FD3E8)],
                  ),
                  border: Border.all(color: const Color(0x4D5FD3E8)),
                ),
                child: Text(
                  profile.initials,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'مرحبا $name',
                    style: text.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? AppColors.success
                                : AppColors.textFaint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          active
                              ? 'نشط · ${formatCubicMetresAsLitres(profile.volumeM3)}'
                                  ' · ${formatDzd(profile.price)} دج'
                              : 'غير نشط · ما توصلكش طلبات',
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
