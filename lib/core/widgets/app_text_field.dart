import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';
import 'app_text.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool isPassword;
  final String? errorMessage;
  final void Function(String)? onChanged;
  final Widget? prefixIcon;
  final Widget? trailingLabelWidget;
  final bool isRequired;

  const AppTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.isPassword = false,
    this.errorMessage,
    this.onChanged,
    this.prefixIcon,
    this.trailingLabelWidget,
    this.isRequired = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.errorMessage != null && widget.errorMessage!.isNotEmpty;
    final bool isFocused = _focusNode.hasFocus;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: RichText(
                text: TextSpan(
                  text: widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Roboto',
                  ),
                  children: [
                    if (widget.isRequired)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.trailingLabelWidget != null) widget.trailingLabelWidget!,
          ],
        ),
        const SizedBox(height: AppSizes.spacingS),
        SizedBox(
          height: AppSizes.inputHeight,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: _obscureText,
            onChanged: widget.onChanged,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            cursorColor: Theme.of(context).colorScheme.primary,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              prefixIcon: widget.prefixIcon,
              suffixIcon:
                  widget.isPassword
                      ? IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      )
                      : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: BorderSide(
                  color:
                      hasError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outline,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: BorderSide(
                  color:
                      hasError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              fillColor: Theme.of(context).colorScheme.surface,
              filled: true,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 16,
                ),
                SizedBox(width: 4),
                Expanded(
                  child: AppText(
                    widget.errorMessage!,
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
