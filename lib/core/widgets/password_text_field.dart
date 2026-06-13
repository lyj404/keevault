import 'package:flutter/material.dart';
import 'password_strength_indicator.dart';

class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool autofocus;
  final bool showPrefixIcon;
  final bool showStrengthIndicator;
  final ValueChanged<String>? onFieldSubmitted;

  const PasswordTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.validator,
    this.autofocus = false,
    this.showPrefixIcon = true,
    this.showStrengthIndicator = false,
    this.onFieldSubmitted,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscure = true;
  late TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    if (widget.showStrengthIndicator) {
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    if (widget.showStrengthIndicator) {
      _controller.removeListener(_onTextChanged);
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          obscureText: _obscure,
          autofocus: widget.autofocus,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.showPrefixIcon ? const Icon(Icons.lock_outline_rounded) : null,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (widget.showStrengthIndicator)
          PasswordStrengthIndicator(password: _controller.text),
      ],
    );
  }
}
