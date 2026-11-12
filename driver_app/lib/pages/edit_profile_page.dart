import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/driver_profile.dart';
import '../services/driver_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/brand_header.dart';
import '../widgets/glass_surface.dart';
import '../widgets/profile_form.dart';

/// Transparent system bars with light icons over the dark canvas.
const _overlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// "تعديل معلومات الحساب": the same form the driver registered with, filled in.
///
/// The email is shown but locked — it is the account identity, and changing it
/// from here would silently break the sign-in the driver remembers. Everything
/// the customer sees (name, phone, water grade, load, price, base point) is
/// editable.
///
/// Pops with `true` after a successful save so the caller can confirm it with a
/// message; the profile stream keeps the rest of the app in sync on its own.
class EditProfilePage extends StatefulWidget {
  /// Creates the edit page for [profile].
  const EditProfilePage({super.key, required this.profile});

  /// The profile being edited.
  final DriverProfile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileFormController _form =
      ProfileFormController.fromProfile(widget.profile);

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final point = _form.location;
    if (point == null) {
      setState(() {
        _error = 'حدد موقع القاعدة على الخريطة قبل ما تسجل.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await DriverStore.saveProfile(
        widget.profile.copyWith(
          firstName: _form.firstName,
          lastName: _form.lastName,
          phone: _form.phone,
          lat: point.latitude,
          lng: point.longitude,
          waterType: _form.waterType,
          volumeM3: _form.volumeM3,
          price: _form.price,
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('EditProfilePage.save: $error');
      if (mounted) {
        setState(() {
          _error = 'ما قدرناش نسجلو التعديلات. تحقق من الاتصال و عاود.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: GradientBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.md,
                    AppSpace.lg,
                    AppSpace.sm,
                  ),
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معلومات الحساب',
                              style: text.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'الزبون يشوف هذي المعلومات',
                              style: text.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      AppSpace.sm,
                      AppSpace.lg,
                      AppSpace.xxl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlassSurface(
                              blur: AppGlass.sheetBlur,
                              tint: AppColors.surfaceSheet,
                              radius: AppRadius.sheet,
                              padding: const EdgeInsets.all(AppSpace.xl),
                              child: Form(
                                key: _formKey,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                child: ProfileFormFields(
                                  controller: _form,
                                  emailLocked: true,
                                  onWaterType: (value) =>
                                      setState(() => _form.waterType = value),
                                  onLocation: (point) =>
                                      setState(() => _form.location = point),
                                ),
                              ),
                            ),
                            InlineError(message: _error),
                            const SizedBox(height: AppSpace.xl),
                            PrimaryButton(
                              label: 'سجّل التعديلات',
                              icon: Icons.save_rounded,
                              busy: _busy,
                              onPressed: _save,
                            ),
                            const SizedBox(height: AppSpace.md),
                            SecondaryButton(
                              label: 'خلّي كيفما كان',
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
