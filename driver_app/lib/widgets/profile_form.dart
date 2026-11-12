import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/driver_profile.dart';
import '../pages/map_picker_page.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'glass_surface.dart';
import 'password_field.dart';
import 'segmented_tabs.dart';

/// Holds the text controllers and the two non-text choices of the driver
/// profile form.
///
/// One object for the whole form means the sign-up screen and the "edit my
/// account" screen are literally the same form, so a field added to one is
/// never missing from the other. The page owns the [Form] key and calls
/// [validate] on submit; the fields themselves are rendered by
/// [ProfileFormFields].
class ProfileFormController {
  /// Creates the controller, optionally seeded from an existing profile.
  ProfileFormController({
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    int litres = 10000,
    int price = 3000,
    this.waterType = WaterTypes.drinking,
    this.location,
  })  : firstNameField = TextEditingController(text: firstName),
        lastNameField = TextEditingController(text: lastName),
        emailField = TextEditingController(text: email),
        phoneField = TextEditingController(text: phone),
        litresField = TextEditingController(text: litres.toString()),
        priceField = TextEditingController(text: price.toString());

  /// Builds a controller from a saved profile.
  factory ProfileFormController.fromProfile(DriverProfile profile) {
    return ProfileFormController(
      firstName: profile.firstName,
      lastName: profile.lastName,
      email: profile.email,
      phone: profile.phone,
      litres: profile.volumeM3 * 1000,
      price: profile.price,
      waterType: profile.waterType,
      location: profile.hasBase ? LatLng(profile.lat, profile.lng) : null,
    );
  }

  /// Given name.
  final TextEditingController firstNameField;

  /// Family name.
  final TextEditingController lastNameField;

  /// Sign-in email. Read-only on the edit screen: it is the account identity.
  final TextEditingController emailField;

  /// Contact phone.
  final TextEditingController phoneField;

  /// Load size, typed in litres.
  final TextEditingController litresField;

  /// Price per load, in dinars.
  final TextEditingController priceField;

  /// One of [WaterTypes].
  String waterType;

  /// The driver's base point, or `null` until the map has been used.
  LatLng? location;

  /// Trimmed given name.
  String get firstName => firstNameField.text.trim();

  /// Trimmed family name.
  String get lastName => lastNameField.text.trim();

  /// Trimmed email.
  String get email => emailField.text.trim();

  /// Digits-only phone.
  String get phone => digitsOnly(phoneField.text);

  /// Load size in litres, rounded to the nearest 1 000.
  int get litres {
    final parsed = int.tryParse(digitsOnly(litresField.text)) ?? 0;
    return ((parsed / 1000).round() * 1000).clamp(1000, 40000);
  }

  /// Load size in cubic metres, which is what Firestore stores.
  int get volumeM3 => litres ~/ 1000;

  /// Price in dinars.
  int get price => int.tryParse(digitsOnly(priceField.text)) ?? 0;

  /// The label a driver reads back before saving: `10 000 لتر · 3 000 دج`.
  String get summary =>
      '${formatLitres(litres)} · ${formatDzd(price)} دج';

  /// Releases the six controllers.
  void dispose() {
    firstNameField.dispose();
    lastNameField.dispose();
    emailField.dispose();
    phoneField.dispose();
    litresField.dispose();
    priceField.dispose();
  }
}

/// A required two-letter-or-more name.
String? validateName(String? value, String field) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return 'اكتب $field.';
  if (trimmed.length < 2) return '$field قصير بزاف.';
  return null;
}

/// A syntactically valid email address.
String? validateEmail(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return 'اكتب الإيميل.';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(trimmed);
  return ok ? null : 'الإيميل ماشي صحيح. مثال: ali@mail.com';
}

/// An Algerian mobile number.
String? validatePhone(String? value) {
  final digits = digitsOnly(value ?? '');
  if (digits.isEmpty) return 'اكتب رقم الهاتف.';
  if (!isValidAlgerianMobile(digits)) {
    return 'الرقم لازم يبدا بـ 05 ولا 06 ولا 07 و يكون 10 أرقام.';
  }
  return null;
}

/// A password Firebase will accept.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'اكتب كلمة السر.';
  if (password.length < 6) return 'كلمة السر لازم 6 حروف ولا أكثر.';
  return null;
}

/// A confirmation that matches [password].
String? validatePasswordConfirm(String? value, String password) {
  if ((value ?? '').isEmpty) return 'عاود اكتب كلمة السر.';
  if (value != password) return 'كلمتين السر ما يتشابهوش.';
  return null;
}

/// A plausible tanker load.
String? validateLitres(String? value) {
  final litres = int.tryParse(digitsOnly(value ?? '')) ?? 0;
  if (litres == 0) return 'اكتب كمية الماء.';
  if (litres < 1000) return 'أقل كمية 1 000 لتر.';
  if (litres > 40000) return 'أكثر كمية 40 000 لتر.';
  return null;
}

/// A plausible price.
String? validatePrice(String? value) {
  final price = int.tryParse(digitsOnly(value ?? '')) ?? 0;
  if (price == 0) return 'اكتب السعر.';
  if (price < 100) return 'السعر قليل بزاف.';
  if (price > 100000) return 'السعر كبير بزاف.';
  return null;
}

/// The profile form itself: identity, contact, the offer and the base point.
///
/// Every field is full width. Two names side by side would fit on a normal
/// phone, but not at a 1.6 text scale, and a form that reflows is worth more
/// than one that is 40dp shorter.
class ProfileFormFields extends StatelessWidget {
  /// Creates the form fields.
  const ProfileFormFields({
    super.key,
    required this.controller,
    required this.onWaterType,
    required this.onLocation,
    this.emailLocked = false,
    this.showPasswordSection = false,
    this.passwordField,
    this.confirmField,
  });

  /// Controllers and current choices.
  final ProfileFormController controller;

  /// Called when the water grade changes.
  final ValueChanged<String> onWaterType;

  /// Called with the point picked on the map.
  final ValueChanged<LatLng> onLocation;

  /// Whether the email is the account identity and cannot be edited.
  final bool emailLocked;

  /// Whether the two password fields belong to this form (sign-up only).
  final bool showPasswordSection;

  /// Password controller, required when [showPasswordSection] is true.
  final TextEditingController? passwordField;

  /// Confirmation controller, required when [showPasswordSection] is true.
  final TextEditingController? confirmField;

  Future<void> _pickLocation(BuildContext context) async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (_) => MapPickerPage(initial: controller.location),
      ),
    );
    if (picked != null) onLocation(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final point = controller.location;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(
          icon: Icons.person_outline_rounded,
          label: 'المعلومات الشخصية',
        ),
        TextFormField(
          controller: controller.firstNameField,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          decoration: const InputDecoration(
            labelText: 'الاسم',
            hintText: 'مثلاً كريم',
          ),
          validator: (value) => validateName(value, 'الاسم'),
        ),
        const SizedBox(height: AppSpace.md),
        TextFormField(
          controller: controller.lastNameField,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.familyName],
          decoration: const InputDecoration(
            labelText: 'اللقب',
            hintText: 'مثلاً بن عمر',
          ),
          validator: (value) => validateName(value, 'اللقب'),
        ),
        const SizedBox(height: AppSpace.md),
        TextFormField(
          controller: controller.emailField,
          readOnly: emailLocked,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'الإيميل',
            hintText: 'ali@mail.com',
            helperText: emailLocked ? 'الإيميل مربوط بالحساب، ما يتبدلش.' : null,
            suffixIcon: emailLocked
                ? const Icon(Icons.lock_outline_rounded, size: 18)
                : null,
          ),
          validator: validateEmail,
        ),
        const SizedBox(height: AppSpace.md),
        TextFormField(
          controller: controller.phoneField,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: const InputDecoration(
            labelText: 'رقم الهاتف',
            hintText: '0550123456',
            helperText: 'الزبون يعيّطلك على هذا الرقم.',
          ),
          validator: validatePhone,
        ),
        if (showPasswordSection &&
            passwordField != null &&
            confirmField != null) ...[
          const SizedBox(height: AppSpace.xl),
          const _SectionLabel(
            icon: Icons.lock_outline_rounded,
            label: 'كلمة السر',
          ),
          PasswordField(
            controller: passwordField!,
            label: 'كلمة السر',
            hint: '6 حروف ولا أكثر',
            textInputAction: TextInputAction.next,
            validator: validatePassword,
          ),
          const SizedBox(height: AppSpace.md),
          PasswordField(
            controller: confirmField!,
            label: 'عاود كلمة السر',
            hint: 'نفس الكلمة',
            textInputAction: TextInputAction.next,
            validator: (value) =>
                validatePasswordConfirm(value, passwordField!.text),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        const _SectionLabel(
          icon: Icons.local_shipping_outlined,
          label: 'الصهريج و السعر',
        ),
        Text(
          'نوع الماء',
          style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.sm),
        SegmentedTabs(
          labels: WaterTypes.all,
          index: WaterTypes.all.indexOf(controller.waterType).clamp(0, 1),
          onChanged: (index) => onWaterType(WaterTypes.all[index]),
          semanticLabel: 'نوع الماء',
        ),
        const SizedBox(height: AppSpace.md),
        TextFormField(
          controller: controller.litresField,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration: const InputDecoration(
            labelText: 'كمية الماء',
            hintText: '10000',
            suffixText: 'لتر',
            helperText: 'من 1 000 حتى 40 000 لتر.',
          ),
          validator: validateLitres,
        ),
        const SizedBox(height: AppSpace.md),
        TextFormField(
          controller: controller.priceField,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'السعر',
            hintText: '3000',
            suffixText: 'دج',
            helperText: 'السعر الكامل للصهريج.',
          ),
          validator: validatePrice,
        ),
        const SizedBox(height: AppSpace.xl),
        const _SectionLabel(
          icon: Icons.place_outlined,
          label: 'موقع القاعدة',
        ),
        Text(
          'نقطة انطلاقك. منها نحسبو المسافة بيناتك و بين الزبون.',
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpace.md),
        GlassSurface(
          onTap: () => _pickLocation(context),
          semanticLabel: point == null
              ? 'حدد موقعك على الخريطة'
              : 'موقعك محدد، بدّلو من الخريطة',
          tint: point == null ? AppColors.surfaceField : AppColors.accentSoft,
          rim: point == null ? AppColors.fieldBorder : AppColors.accent,
          blur: AppGlass.cardBlur,
          shadow: false,
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Icon(
                point == null
                    ? Icons.add_location_alt_outlined
                    : Icons.place_rounded,
                size: 22,
                color: point == null ? AppColors.textFaint : AppColors.accent,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point == null ? 'ما حددتش الموقع' : 'الموقع محدد',
                      style: text.titleMedium?.copyWith(
                        fontSize: 15,
                        color: point == null
                            ? AppColors.textPrimary
                            : AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      point == null
                          ? 'اضغط باش تفتح الخريطة و تحدد نقطتك.'
                          : formatLatLng(point.latitude, point.longitude),
                      style: text.bodySmall,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
        if (point == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              'لازم تحدد الموقع قبل ما تسجل.',
              style: text.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
      ],
    );
  }
}

/// A small heading that separates the form into readable blocks.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.accent),
          const SizedBox(width: AppSpace.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
