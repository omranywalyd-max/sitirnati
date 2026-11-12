import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/driver_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/brand_header.dart';
import '../widgets/glass_surface.dart';
import '../widgets/password_field.dart';
import 'sign_up_page.dart';

/// Transparent system bars with light icons over the dark canvas.
const _overlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// The driver's door: email and password, or the Google account on the phone.
///
/// There is no separate "login mode" toggle to hunt for — the page is a single
/// sign-in form, and the sign-up is one clearly labelled action underneath,
/// because a driver opening this app is far more often coming back than
/// arriving for the first time.
///
/// The page never navigates on success: it signs in, and the root gate above it
/// swaps the whole tree to the home screen. That keeps one source of truth for
/// "is there a session" instead of two competing ones.
class AuthPage extends StatefulWidget {
  /// Creates the sign-in page.
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _googleBusy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _googleBusy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DriverAuth.signIn(
        email: _email.text,
        password: _password.text,
      );
      // The gate above replaces this page; nothing to do here.
    } on DriverAuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      debugPrint('AuthPage.signIn: $error');
      if (mounted) {
        setState(() => _error = 'ما قدرناش ندخلوك. تحقق من الاتصال و عاود.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy || _googleBusy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await DriverAuth.signInWithGoogle();
    } on DriverAuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      debugPrint('AuthPage.google: $error');
      if (mounted) {
        setState(() => _error = 'ما قدرناش ندخلوك بحساب Google. جرّب بالإيميل.');
      }
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _openSignUp() async {
    if (_busy || _googleBusy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SignUpPage.create()),
    );
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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.xxl,
                  AppSpace.xl,
                  AppSpace.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandLockup(),
                      const SizedBox(height: AppSpace.xxl),
                      GlassSurface(
                        blur: AppGlass.sheetBlur,
                        tint: AppColors.surfaceSheet,
                        radius: AppRadius.sheet,
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('دخول السائق', style: text.headlineSmall),
                              const SizedBox(height: AppSpace.xs),
                              Text(
                                'دخّل بالإيميل و كلمة السر، ولا بحساب Google.',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: AppSpace.xl),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enabled: !_busy && !_googleBusy,
                                decoration: const InputDecoration(
                                  labelText: 'الإيميل',
                                  hintText: 'ali@mail.com',
                                ),
                                validator: (value) {
                                  final email = (value ?? '').trim();
                                  if (email.isEmpty) return 'اكتب الإيميل.';
                                  if (!email.contains('@')) {
                                    return 'الإيميل ماشي صحيح.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpace.md),
                              PasswordField(
                                controller: _password,
                                label: 'كلمة السر',
                                hint: '••••••',
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: (value) =>
                                    (value ?? '').isEmpty
                                        ? 'اكتب كلمة السر.'
                                        : null,
                                onSubmitted: (_) => _submit(),
                              ),
                              InlineError(message: _error),
                              const SizedBox(height: AppSpace.xl),
                              PrimaryButton(
                                label: 'دخول',
                                icon: Icons.login_rounded,
                                busy: _busy,
                                onPressed: _googleBusy ? null : _submit,
                              ),
                              const OrDivider(label: 'ولا'),
                              _GoogleButton(
                                busy: _googleBusy,
                                onPressed: _busy ? null : _google,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      GlassSurface(
                        onTap: _openSignUp,
                        semanticLabel: 'أنشئ حساب سائق جديد',
                        tint: const Color(0x0FFFFFFF),
                        rim: AppColors.glassBorder,
                        shadow: false,
                        radius: AppRadius.field,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg,
                          vertical: AppSpace.md,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 19,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Flexible(
                              child: Text(
                                'ما عندكش حساب؟ أنشئ حساب جديد',
                                textAlign: TextAlign.center,
                                style: text.labelLarge?.copyWith(
                                  fontSize: 14,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      Text(
                        'الحساب مخصص لسائقي صهاريج الماء. '
                        'بعد ما تدخل، تسجل معلوماتك و تصهريجك و موقعك.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Google action: the same glass as a secondary button, with the letter
/// mark so it is recognisable before the label is read.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'الدخول بحساب Google',
      child: GlassSurface(
        radius: AppRadius.field,
        padding: EdgeInsets.zero,
        tint: AppGlass.controlTint,
        rim: AppColors.glassBorder,
        shadow: false,
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: kButtonHeight,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  const _GoogleMark(),
                const SizedBox(width: AppSpace.sm + 2),
                Flexible(
                  child: Text(
                    'الدخول بحساب Google',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textFaint,
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

/// The Google letter mark: a white disc with the blue `G`.
///
/// Drawn from a glyph rather than shipped as an image, so it stays crisp at any
/// text scale and adds nothing to the APK.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF3F3F5),
          shape: BoxShape.circle,
        ),
        child: const Text(
          'G',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
            height: 1.05,
          ),
        ),
      ),
    );
  }
}
