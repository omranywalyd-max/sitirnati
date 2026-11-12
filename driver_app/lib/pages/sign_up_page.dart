import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/driver_profile.dart';
import '../services/driver_auth.dart';
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

/// The driver's registration form, in two flavours.
///
/// * [SignUpPage.create] — a brand-new driver: identity, contact, the offer and
///   the base point, plus the email and password that become the account.
/// * [SignUpPage.complete] — a driver who already signed in (typically with
///   Google) but has no profile document yet. Same form, no password, email
///   locked, because the account already exists.
///
/// Both write exactly one document, `drivers/{uid}`, through [DriverStore]. The
/// gate above this page watches that document, so a successful save swaps the
/// screen without any navigation of our own.
class SignUpPage extends StatefulWidget {
  /// Registration of a new account.
  const SignUpPage.create({super.key})
      : uid = null,
        initialEmail = '',
        initialFirstName = '',
        initialLastName = '',
        canPop = true;

  /// Completion of an account that has no profile yet.
  const SignUpPage.complete({
    super.key,
    required this.uid,
    required this.initialEmail,
    this.initialFirstName = '',
    this.initialLastName = '',
  }) : canPop = false;

  /// Firebase Auth uid, or `null` when this page also creates the account.
  final String? uid;

  /// Email to prefill; the account's address in completion mode.
  final String initialEmail;

  /// Name prefill, taken from the Google account when there is one.
  final String initialFirstName;

  /// Family-name prefill.
  final String initialLastName;

  /// Whether this page was pushed and should pop on success.
  final bool canPop;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  late final ProfileFormController _form = ProfileFormController(
    firstName: widget.initialFirstName,
    lastName: widget.initialLastName,
    email: widget.initialEmail,
  );

  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  /// Whether the page also creates the account.
  bool get _creating => widget.uid == null;

  @override
  void dispose() {
    _form.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      var uid = widget.uid;
      if (uid == null) {
        final user = await DriverAuth.signUp(
          email: _form.email,
          password: _password.text,
        );
        uid = user.uid;
      }

      final now = DateTime.now();
      await DriverStore.saveProfile(
        DriverProfile(
          uid: uid,
          firstName: _form.firstName,
          lastName: _form.lastName,
          email: _form.email,
          phone: _form.phone,
          lat: point.latitude,
          lng: point.longitude,
          waterType: _form.waterType,
          volumeM3: _form.volumeM3,
          price: _form.price,
          // A driver who just registered wants work: the switch starts on and
          // they can turn it off from the home screen.
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (!mounted) return;
      if (widget.canPop && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      // In completion mode the profile stream above swaps the screen.
    } on DriverAuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      debugPrint('SignUpPage: $error');
      if (mounted) {
        setState(() {
          _error = _creating
              ? 'الحساب ما تسجلش. تحقق من الاتصال و عاود.'
              : 'معلوماتك ما تسجلتش. تحقق من الاتصال و عاود.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تخرج من الحساب؟'),
        content: const Text(
          'معلوماتك ما تسجلتش بعد. إذا خرجت، ترجع للدخول و تعاود من الأول.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
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
            child: const Text('نكمل'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('اخرج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DriverAuth.signOut();
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
                      if (widget.canPop)
                        GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'رجوع',
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      else
                        const SizedBox(width: 44),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _creating ? 'حساب سائق جديد' : 'كمّل معلوماتك',
                              style: text.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _creating
                                  ? 'خطوة وحدة و تبدا تستقبل الطلبات'
                                  : 'باقي معلومات الصهريج و الموقع',
                              style: text.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!widget.canPop)
                        GlassIconButton(
                          icon: Icons.logout_rounded,
                          tooltip: 'تسجيل الخروج',
                          tone: AppColors.textSecondary,
                          onPressed: _signOut,
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
                                  emailLocked: !_creating,
                                  showPasswordSection: _creating,
                                  passwordField: _password,
                                  confirmField: _confirm,
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
                              label: _creating
                                  ? 'أنشئ الحساب'
                                  : 'سجّل معلوماتي',
                              icon: Icons.check_rounded,
                              busy: _busy,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: AppSpace.md),
                            Text(
                              _creating
                                  ? 'بعد ما تسجل، تقدر تبدل معلوماتك في أي وقت '
                                      'من القائمة.'
                                  : 'هذي المعلومات هي لي يشوفها الزبون: '
                                      'اسمك، نوع الماء، الكمية و السعر.',
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(height: 1.6),
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
