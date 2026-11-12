import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/driver_offer.dart';
import '../models/order.dart';
import '../pages/map_picker_page.dart';
import '../services/auth_service.dart';
import '../services/overlay_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_buttons.dart';
import 'glass_surface.dart';

/// Opens the order form for [offer] and resolves with the placed order, or
/// `null` when the customer closes it.
Future<Order?> showOrderFormSheet(BuildContext context, DriverOffer offer) {
  return showModalBottomSheet<Order>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC000000),
    builder: (_) => OrderFormSheet(offer: offer),
  );
}

/// The order form: who is asking, where, and how to reach them, plus the map
/// pin that tells the driver where to stop.
///
/// The terms at the top are the offer the customer tapped, but they are not a
/// promise about *who* will come: the order goes to the pool and the first
/// available driver to accept takes it. The copy says that in plain Arabic
/// rather than implying a booking, because the customer will otherwise wait for
/// a specific face that may never arrive.
///
/// The submit button stays disabled until a location is pinned, and every
/// validation message sits directly under its field.
class OrderFormSheet extends StatefulWidget {
  /// Creates the order form for [offer].
  const OrderFormSheet({super.key, required this.offer});

  /// The driver offer whose terms pre-fill the order.
  final DriverOffer offer;

  @override
  State<OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<OrderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _placeController = TextEditingController();
  final _phoneController = TextEditingController();

  LatLng? _pin;
  bool _showErrors = false;
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (_) => MapPickerPage(initial: _pin),
      ),
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = picked);
  }

  Future<void> _submit() async {
    if (_sending) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() => _showErrors = true);
    if (!formValid) return;
    if (_pin == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('حدد مكانك على الخريطة قبل ما تبعث الطلب.'),
          ),
        );
      return;
    }

    FocusScope.of(context).unfocus();

    // Asked before the order exists, not after: the customer should learn why
    // the app wants this permission while they can still decide, and the answer
    // is stored by Android, so this dialog appears once and never again.
    if (!await OverlayService.hasPermission()) {
      if (!mounted) return;
      final proceed = await showOverlayPermissionDialog(context);
      if (!proceed || !mounted) return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _sending = true);

    // The uid is what the security rules compare the document against, so the
    // order is not built until the anonymous session exists. It normally
    // resolved during the splash; the await only bites on a first offline run.
    final uid = await AuthService.customerUidOrEmpty();
    if (!mounted) return;

    final offer = widget.offer;
    final order = Order(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      customerUid: uid,
      customerName: _nameController.text.trim(),
      phone: digitsOnly(_phoneController.text),
      placeName: _placeController.text.trim(),
      lat: _pin!.latitude,
      lng: _pin!.longitude,
      waterType: offer.waterType,
      volumeM3: offer.volumeM3,
      price: offer.price,
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pop(order);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offer = widget.offer;
    final pin = _pin;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GlassSurface(
          blur: AppGlass.sheetBlur,
          tint: AppColors.surfaceSheet,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          rim: AppColors.glassBorder,
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.xl,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: _showErrors
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpace.md),
                      decoration: BoxDecoration(
                        color: AppColors.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // The terms the customer picked from the price board.
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('العرض المختار', style: text.bodySmall),
                            const SizedBox(height: 2),
                            Text(
                              '${formatVolume(offer.volumeM3)} · '
                              '${formatDzd(offer.price)} دج',
                              style: text.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${offer.waterType} · عرض ${offer.fullName}',
                              style: text.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Container(height: 1, color: AppColors.divider),
                  const SizedBox(height: AppSpace.lg),

                  _FieldLabel('الاسم الكامل'),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    style: _fieldStyle,
                    decoration: const InputDecoration(
                      hintText: 'مثال: أمين بوقرة',
                    ),
                    // 80 is the ceiling the security rules enforce on
                    // `customerName`; capping the field here turns a rejected
                    // write into a normal typing limit.
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'اكتب اسمك الكامل.';
                      if (name.length < 3) return 'الاسم قصير بزاف.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpace.lg),

                  _FieldLabel('اسم المكان'),
                  TextFormField(
                    controller: _placeController,
                    textInputAction: TextInputAction.next,
                    style: _fieldStyle,
                    decoration: const InputDecoration(
                      hintText: 'الحي، الشارع، رقم العمارة',
                    ),
                    // Same ceiling as the rules (`placeName` <= 160).
                    inputFormatters: [LengthLimitingTextInputFormatter(160)],
                    validator: (value) {
                      final place = value?.trim() ?? '';
                      if (place.isEmpty) {
                        return 'اكتب اسم المكان باش السائق يلقاك.';
                      }
                      if (place.length < 2) {
                        return 'اكتب اسم المكان كامل.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpace.lg),

                  _FieldLabel('رقم الهاتف'),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: _fieldStyle,
                    decoration: const InputDecoration(
                      hintText: '05 50 12 34 56',
                    ),
                    validator: (value) {
                      final phone = digitsOnly(value ?? '');
                      if (phone.isEmpty) return 'اكتب رقم هاتفك.';
                      if (!isValidAlgerianMobile(phone)) {
                        return 'رقم غير صحيح: 10 أرقام يبدا بـ 05 ولا 06 ولا 07.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpace.lg),

                  _FieldLabel('الموقع على الخريطة'),
                  _LocationPicker(
                    pin: pin,
                    hasError: _showErrors && pin == null,
                    onTap: _pickLocation,
                  ),
                  const SizedBox(height: AppSpace.xl),

                  PrimaryButton(
                    label: 'ابعث الطلب',
                    icon: Icons.send_rounded,
                    busy: _sending,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'الطلب يوصل للسواقين المتوفرين كاملين، و أول واحد يقبلو '
                    'ياخذو و يعيّطلك. تتبع الحالة في «طلبياتي».',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _fieldStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );
}

/// Explains, in the customer's own words, why the app asks to draw over other
/// apps — and opens the system screen that grants it.
///
/// Resolves `true` when the order should still be sent, `false` when the
/// customer backed out. Sending is allowed either way: the order is the
/// customer's goal, the alert is a convenience, and a permission dialog that
/// blocks the product would be held against it. Without the permission the
/// near-alert degrades to an in-app banner — see `HomeShell._maybeAnnounce`.
Future<bool> showOverlayPermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final text = Theme.of(dialogContext).textTheme;

      return AlertDialog(
        title: const Text('خلّي سيترنتي يبان فوق الشاشة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'كي يوصل السائق قريب منك، سيترنتي يحطلك تنبيه على كامل الشاشة '
              'باش ما يفوتكش — حتى إذا كان الهاتف مقفول ولا راك في تطبيق آخر.',
              style: text.bodySmall?.copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'هذا يحتاج إذن واحد من النظام: «العرض فوق التطبيقات الأخرى». '
              'بلا هذا الإذن، التنبيه يبان غير كي تكون فاتح سيترنتي.',
              style: text.bodySmall?.copyWith(height: 1.6),
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
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('كمّل بلا التنبيه'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await OverlayService.requestPermission();
              if (navigator.canPop()) navigator.pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('افتح الإعدادات'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// A visible label above every field: a placeholder is never the only label.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// The map row: empty prompt, or the pinned coordinates plus a change action.
class _LocationPicker extends StatelessWidget {
  const _LocationPicker({
    required this.pin,
    required this.hasError,
    required this.onTap,
  });

  final LatLng? pin;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pinned = pin != null;

    return Semantics(
      button: true,
      label: pinned ? 'تغيير الموقع المحدد' : 'فتح الخريطة لتحديد الموقع',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.field),
          splashColor: AppColors.accentSoft,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceField,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(
                color: hasError ? AppColors.danger : AppColors.fieldBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    color: pinned
                        ? AppColors.accentSoft
                        : const Color(0x0FFFFFFF),
                  ),
                  child: Icon(
                    pinned ? Icons.place_rounded : Icons.map_outlined,
                    size: 20,
                    color: pinned ? AppColors.accent : AppColors.textFaint,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pinned ? 'تم تحديد الموقع' : 'افتح الخريطة وحدد مكانك',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pinned
                            ? formatLatLng(pin!.latitude, pin!.longitude)
                            : 'اضغط بصباعك على النقطة الصحيحة',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textFaint,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  pinned ? Icons.edit_location_alt_outlined : Icons.chevron_left,
                  size: 20,
                  color: AppColors.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
