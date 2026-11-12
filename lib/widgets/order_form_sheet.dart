import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/order.dart';
import '../models/truck.dart';
import '../pages/map_picker_page.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_buttons.dart';
import 'glass_surface.dart';

/// Opens the order form for [truck] and resolves with the placed order, or
/// `null` when the customer closes it.
Future<Order?> showOrderFormSheet(BuildContext context, Truck truck) {
  return showModalBottomSheet<Order>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC000000),
    builder: (_) => OrderFormSheet(truck: truck),
  );
}

/// The order form: who is asking, where, and how to reach them, plus the map
/// pin that tells the driver where to stop.
///
/// The submit button stays disabled until a location is pinned, and every
/// validation message sits directly under its field.
class OrderFormSheet extends StatefulWidget {
  /// Creates the order form for [truck].
  const OrderFormSheet({super.key, required this.truck});

  /// Driver being ordered from.
  final Truck truck;

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

  void _submit() {
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
    HapticFeedback.mediumImpact();

    final order = Order(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      truckId: widget.truck.id,
      driverName: widget.truck.driverName,
      waterType: widget.truck.waterType,
      volumeM3: widget.truck.volumeM3,
      price: widget.truck.price,
      customerName: _nameController.text.trim(),
      phone: digitsOnly(_phoneController.text),
      placeName: _placeController.text.trim(),
      lat: _pin!.latitude,
      lng: _pin!.longitude,
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pop(order);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final truck = widget.truck;
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

                  // Who the order is going to.
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('طلب من', style: text.bodySmall),
                            const SizedBox(height: 2),
                            Text(truck.driverName, style: text.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              '${truck.waterType} · '
                              '${formatVolume(truck.volumeM3)} · '
                              '${formatDzd(truck.price)} دج',
                              style: text.bodySmall,
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
                    validator: (value) {
                      final place = value?.trim() ?? '';
                      if (place.isEmpty) {
                        return 'اكتب اسم المكان باش السائق يلقاك.';
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
                    label: 'ابعث الطلب للسائق',
                    icon: Icons.send_rounded,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'الطلبية تتسجل في «طلبياتي» على هذا الهاتف بحالة مُرسل.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
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
                    color: pinned ? AppColors.accentSoft : const Color(0x0FFFFFFF),
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
