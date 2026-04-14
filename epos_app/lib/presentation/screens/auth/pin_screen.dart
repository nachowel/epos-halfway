import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_image_preload_provider.dart';

const ValueKey<String> kPinScreenInputKey = ValueKey<String>(
  'pin_screen_input',
);
const ValueKey<String> kPinScreenSignInButtonKey = ValueKey<String>(
  'pin_screen_sign_in',
);
const ValueKey<String> kPinScreenMainLayoutKey = ValueKey<String>(
  'pin_screen_main_layout',
);
const ValueKey<String> kPinScreenErrorBannerKey = ValueKey<String>(
  'pin_screen_error_banner',
);
const ValueKey<String> kPinScreenKeypadClearKey = ValueKey<String>(
  'pin_screen_keypad_clear',
);
const ValueKey<String> kPinScreenKeypadBackspaceKey = ValueKey<String>(
  'pin_screen_keypad_backspace',
);

ValueKey<String> pinScreenKeypadDigitKey(String digit) =>
    ValueKey<String>('pin_screen_keypad_digit_$digit');

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode(debugLabel: 'pin_screen_input');

  @override
  void initState() {
    super.initState();
    _debugPinUiLog('mounted');
    _pinFocusNode.addListener(_logFocusChange);
  }

  @override
  void dispose() {
    _pinFocusNode
      ..removeListener(_logFocusChange)
      ..dispose();
    _pinController.dispose();
    _debugPinUiLog('disposed');
    super.dispose();
  }

  void _logFocusChange() {
    _debugPinUiLog('focus=${_pinFocusNode.hasFocus}');
  }

  Future<void> _login() async {
    final String pin = _pinController.text.trim();
    if (pin.isEmpty) {
      _showMessage(AppStrings.enterPin);
      return;
    }

    final user = await ref
        .read(authNotifierProvider.notifier)
        .loginWithPin(pin);
    if (!mounted) {
      return;
    }
    if (user == null) {
      final String error =
          ref.read(authNotifierProvider).errorMessage ?? AppStrings.loginFailed;
      _showMessage(error);
      return;
    }

    unawaited(
      ref.read(catalogImagePreloadServiceProvider).preloadCatalogImages(),
    );

    context.go(_postLoginRoute(user));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _appendDigit(String digit) {
    _setPinValue('${_pinController.text}$digit');
  }

  void _backspace() {
    final String current = _pinController.text;
    if (current.isEmpty) {
      _pinFocusNode.requestFocus();
      return;
    }
    _setPinValue(current.substring(0, current.length - 1));
  }

  void _clearPin() {
    _setPinValue('');
  }

  void _setPinValue(String next) {
    _pinController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    if (_pinFocusNode.canRequestFocus && !_pinFocusNode.hasFocus) {
      _pinFocusNode.requestFocus();
    }
  }

  String _postLoginRoute(User user) {
    switch (user.role) {
      case UserRole.admin:
        return '/admin';
      case UserRole.cashier:
        return '/pos';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authNotifierProvider);
    final bool isDisabled = authState.isLoading || authState.isLocked;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7EC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFF6E8),
              Color(0xFFF9F4EC),
              Color(0xFFEAF7F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spacingLg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1E2CC)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x1A7A4B00),
                        blurRadius: 36,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      key: kPinScreenMainLayoutKey,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          flex: 12,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 390),
                              child: _LoginPanel(
                                authState: authState,
                                controller: _pinController,
                                focusNode: _pinFocusNode,
                                isDisabled: isDisabled,
                                onSubmitted: (_) => _login(),
                                onSignIn: _login,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.spacingLg),
                        Expanded(
                          flex: 9,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 330),
                              child: _PinKeypad(
                                enabled: !isDisabled,
                                onDigit: _appendDigit,
                                onBackspace: _backspace,
                                onClear: _clearPin,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.authState,
    required this.controller,
    required this.focusNode,
    required this.isDisabled,
    required this.onSubmitted,
    required this.onSignIn,
  });

  final AuthState authState;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDisabled;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BrandHeader(isLocked: authState.isLocked),
          const SizedBox(height: AppSizes.spacingMd), // medium: header → input
          _PinInput(
            controller: controller,
            focusNode: focusNode,
            enabled: !isDisabled,
            onSubmitted: onSubmitted,
          ),
          const SizedBox(height: AppSizes.spacingLg), // large: input → button
          SizedBox(
            height: 46,
            child: ElevatedButton(
              key: kPinScreenSignInButtonKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                foregroundColor: AppColors.textOnPrimary,
                disabledBackgroundColor: AppColors.borderStrong,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              onPressed: isDisabled ? null : onSignIn,
              child: Text(
                authState.isLoading
                    ? AppStrings.loading
                    : AppStrings.loginButton,
              ),
            ),
          ),
          if (authState.errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSizes.spacingSm),
            DecoratedBox(
              key: kPinScreenErrorBannerKey,
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: AppColors.danger),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacingMd,
                  vertical: 6,
                ),
                child: Text(
                  authState.errorMessage!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.dangerStrong,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isLocked});

  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D8),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.coffee_rounded,
            size: 24,
            color: Color(0xFF8A5A1F),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'HALFWAY CAFE',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Color(0xFF6E4417),
          ),
        ),
        const SizedBox(height: 4), // small: title → subtitle
        const Text(
          'Staff Login',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4), // small: subtitle → description
        Text(
          isLocked
              ? 'Sign in is temporarily locked.'
              : 'Enter your PIN to continue.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _PinInput extends StatelessWidget {
  const _PinInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (BuildContext context, Widget? child) {
        final bool isFocused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isFocused
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? AppColors.primary : const Color(0xFFD4BFA3),
              width: isFocused ? 2.5 : 1.2,
            ),
            boxShadow: isFocused
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x302AA79B),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Color(0x182AA79B),
                      blurRadius: 0,
                      spreadRadius: 1,
                    ),
                  ]
                : const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A6E4417),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: TextField(
        key: kPinScreenInputKey,
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: false,
        showCursor: true,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 6,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSizes.spacingLg,
            vertical: 16,
          ),
        ),
        obscureText: true,
        obscuringCharacter: '•',
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        autocorrect: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Digit grid: 1–9
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.72,
          children: <Widget>[
            for (final String digit in <String>[
              '1',
              '2',
              '3',
              '4',
              '5',
              '6',
              '7',
              '8',
              '9',
            ])
              _KeypadButton(
                key: pinScreenKeypadDigitKey(digit),
                label: digit,
                enabled: enabled,
                onPressed: () => onDigit(digit),
              ),
          ],
        ),
        const SizedBox(height: 14), // extra gap before bottom row
        // Bottom row: Clear / 0 / Back (secondary, slightly smaller)
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.92,
          children: <Widget>[
            _KeypadButton(
              key: kPinScreenKeypadClearKey,
              label: 'Clear',
              enabled: enabled,
              onPressed: onClear,
              isSecondary: true,
            ),
            _KeypadButton(
              key: pinScreenKeypadDigitKey('0'),
              label: '0',
              enabled: enabled,
              onPressed: () => onDigit('0'),
            ),
            _KeypadButton(
              key: kPinScreenKeypadBackspaceKey,
              label: 'Back',
              enabled: enabled,
              onPressed: onBackspace,
              isSecondary: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.isSecondary = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = OutlinedButton.styleFrom(
      minimumSize: const Size(60, 60),
      maximumSize: const Size(double.infinity, 68),
      padding: const EdgeInsets.symmetric(vertical: 2),
      side: BorderSide(
        color: isSecondary ? AppColors.borderStrong : const Color(0xFFE4D0B0),
      ),
      backgroundColor: isSecondary
          ? AppColors.surface
          : const Color(0xFFFFF7EA),
      foregroundColor: AppColors.textPrimary,
      disabledForegroundColor: AppColors.textMuted,
      disabledBackgroundColor: AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TextStyle(
        fontSize: isSecondary ? 13 : 18,
        fontWeight: FontWeight.w700,
      ),
    );

    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: Text(label),
    );
  }
}

void _debugPinUiLog(String message) {
  if (kDebugMode) {
    debugPrint('[UI_STABILITY][PinScreen] $message');
  }
}
