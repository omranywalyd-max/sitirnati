import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A password input with a show/hide control.
///
/// The toggle is an [IconButton], which is a 48dp target with its own tooltip
/// and screen-reader label — the eye icon alone would be an unlabelled control.
class PasswordField extends StatefulWidget {
  /// Creates a password field.
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
  });

  /// Text controller.
  final TextEditingController controller;

  /// Floating label.
  final String label;

  /// Placeholder.
  final String hint;

  /// Validator, run by the surrounding [Form].
  final FormFieldValidator<String> validator;

  /// Keyboard action of the field.
  final TextInputAction textInputAction;

  /// Called when the keyboard action is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Autofill hints, so a password manager can fill the form.
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_visible,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _visible = !_visible),
          tooltip: _visible ? 'خبّي كلمة السر' : 'ورّي كلمة السر',
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      validator: widget.validator,
    );
  }
}
