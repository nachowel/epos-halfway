import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/exit_safety.dart';
import '../providers/auth_provider.dart';

/// Dialog widget keys used by tests and by assistive callers.
const ValueKey<String> kLogoutSimpleDialogKey = ValueKey<String>(
  'logout_confirmation_simple_dialog',
);
const ValueKey<String> kLogoutWarnDialogKey = ValueKey<String>(
  'logout_confirmation_warn_dialog',
);
const ValueKey<String> kLogoutBlockedDialogKey = ValueKey<String>(
  'logout_confirmation_blocked_dialog',
);
const ValueKey<String> kLogoutCancelButtonKey = ValueKey<String>(
  'logout_confirmation_cancel',
);
const ValueKey<String> kLogoutConfirmButtonKey = ValueKey<String>(
  'logout_confirmation_confirm',
);
const ValueKey<String> kLogoutBlockedAcknowledgeKey = ValueKey<String>(
  'logout_confirmation_blocked_acknowledge',
);

/// Centralised exit/logout gate. EVERY logout entry point in the app MUST
/// funnel through this handler so that the risk rules are applied uniformly.
///
/// Contract:
///   * Re-validates shift + open/sent orders against the freshest source
///     (DB-backed repositories via [ExitSafetyService]).
///   * If any OPEN (draft) or SENT transactions exist, OR if verification
///     fails → blocking dialog; logout is refused.
///   * If only an active shift exists → warning dialog; user must deliberately
///     confirm.
///   * If nothing is active → simple confirm dialog.
///   * Cancel is always the default focused + Enter-activated action.
///   * Escape routes to the same Cancel action (never silent-dismiss).
Future<void> handleLogoutRequest(BuildContext context, WidgetRef ref) async {
  final ExitSafetyEvaluation evaluation = await ref
      .read(exitSafetyServiceProvider)
      .evaluate(currentUser: ref.read(authNotifierProvider).currentUser);
  _debugLogoutDialogLog('evaluation level=${evaluation.level.name}');

  if (!context.mounted) {
    return;
  }

  switch (evaluation.level) {
    case ExitSafetyLevel.blocked:
      await _showBlockedDialog(context, evaluation);
      return;
    case ExitSafetyLevel.warnOnly:
      final bool confirmed =
          await _showWarnDialog(context, evaluation) ?? false;
      if (!confirmed) return;
      break;
    case ExitSafetyLevel.noRisk:
      final bool confirmed = await _showSimpleDialog(context) ?? false;
      if (!confirmed) return;
      break;
  }

  if (!context.mounted) {
    return;
  }
  ref.read(authNotifierProvider.notifier).logout();
  context.go('/login');
}

// ---------------------------------------------------------------------------
// Dialog variants
// ---------------------------------------------------------------------------

Future<bool?> _showSimpleDialog(BuildContext context) {
  _debugLogoutDialogLog('show simple dialog');
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _KeyboardSafeDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        child: AlertDialog(
          key: kLogoutSimpleDialogKey,
          title: const Text('Exit'),
          content: const Text('Are you sure you want to exit?'),
          actions: <Widget>[
            _CancelButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            _LogoutDialogButton(
              buttonKey: kLogoutConfirmButtonKey,
              focusDebugLabel: 'confirm',
              onPressed: () => Navigator.of(dialogContext).pop(true),
              label: 'Exit',
            ),
          ],
        ),
      );
    },
  ).then((bool? result) {
    _debugLogoutDialogLog('dismiss simple dialog result=$result');
    return result;
  });
}

Future<bool?> _showWarnDialog(
  BuildContext context,
  ExitSafetyEvaluation evaluation,
) {
  _debugLogoutDialogLog('show warn dialog');
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final List<String> bullets = _warnBullets(evaluation);
      return _KeyboardSafeDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        child: AlertDialog(
          key: kLogoutWarnDialogKey,
          title: const Text('Active operations detected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('You have active operations:'),
              const SizedBox(height: 8),
              for (final String line in bullets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $line'),
                ),
              const SizedBox(height: 12),
              const Text('Exiting may interrupt workflow.'),
              const SizedBox(height: 12),
              const Text('Are you sure you want to continue?'),
            ],
          ),
          actions: <Widget>[
            _CancelButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            _LogoutDialogButton(
              buttonKey: kLogoutConfirmButtonKey,
              focusDebugLabel: 'confirm',
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              label: 'Exit',
            ),
          ],
        ),
      );
    },
  ).then((bool? result) {
    _debugLogoutDialogLog('dismiss warn dialog result=$result');
    return result;
  });
}

Future<void> _showBlockedDialog(
  BuildContext context,
  ExitSafetyEvaluation evaluation,
) {
  _debugLogoutDialogLog('show blocked dialog');
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final List<String> bullets = _blockedBullets(evaluation);
      return _KeyboardSafeDialog(
        // In the blocked dialog the only available action is the acknowledge
        // button, so Escape/Enter both resolve to it.
        onCancel: () => Navigator.of(dialogContext).pop(),
        child: AlertDialog(
          key: kLogoutBlockedDialogKey,
          title: const Text('Exit unavailable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('You cannot exit until these issues are resolved:'),
              const SizedBox(height: 8),
              for (final String line in bullets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $line'),
                ),
              const SizedBox(height: 12),
              const Text('Please resolve open and sent orders before exiting.'),
            ],
          ),
          actions: <Widget>[
            _LogoutDialogButton(
              buttonKey: kLogoutBlockedAcknowledgeKey,
              focusDebugLabel: 'blocked_acknowledge',
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              label: 'OK',
            ),
          ],
        ),
      );
    },
  ).then((_) {
    _debugLogoutDialogLog('dismiss blocked dialog');
  });
}

// ---------------------------------------------------------------------------
// Copy helpers
// ---------------------------------------------------------------------------

List<String> _warnBullets(ExitSafetyEvaluation e) {
  final List<String> out = <String>[];
  if (e.hasActiveShift) out.add('Shift is still active');
  if (e.verificationFailed) out.add('Order status could not be verified.');
  return out;
}

List<String> _blockedBullets(ExitSafetyEvaluation e) {
  final List<String> out = <String>[];
  if (e.hasOpenOrders) {
    out.add('Open orders exist (${e.openOrderCount})');
  }
  if (e.hasSentOrders) {
    out.add('Sent orders exist (${e.sentOrderCount})');
  }
  if (e.verificationFailed) {
    out.add('Order status could not be verified.');
  }
  if (out.isEmpty) {
    // Defensive fallback — we only reach the blocked branch with at least one
    // blocking reason, but never emit an empty reason list.
    out.add('Order status could not be verified.');
  }
  return out;
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// Wraps a dialog so that:
///   * Escape → runs [onCancel] (never silent-dismisses).
///   * Enter at the dialog scope also routes to Cancel — a belt-and-braces
///     guard so that even if focus ever escapes the cancel button, Enter
///     cannot silently traverse to a non-Cancel action.
class _KeyboardSafeDialog extends StatelessWidget {
  const _KeyboardSafeDialog({required this.child, required this.onCancel});

  final Widget child;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape):
            _DismissLogoutDialogIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _DismissLogoutDialogIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter):
            _DismissLogoutDialogIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DismissLogoutDialogIntent:
              CallbackAction<_DismissLogoutDialogIntent>(
                onInvoke: (_DismissLogoutDialogIntent intent) {
                  onCancel();
                  return null;
                },
              ),
        },
        child: child,
      ),
    );
  }
}

class _DismissLogoutDialogIntent extends Intent {
  const _DismissLogoutDialogIntent();
}

/// Cancel button used across all variants. Owns the focus node so the default
/// focused action is stable and observable in widget tests.
class _CancelButton extends StatefulWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'logout_cancel_button',
  )..addListener(_handleFocusChange);

  @override
  void initState() {
    super.initState();
    _debugLogoutDialogLog('mount cancel button');
  }

  void _handleFocusChange() {
    _debugLogoutDialogLog('focus cancel=${_focusNode.hasFocus}');
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _debugLogoutDialogLog('dispose cancel button');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: kLogoutCancelButtonKey,
      focusNode: _focusNode,
      autofocus: true,
      onPressed: widget.onPressed,
      child: const Text('Cancel'),
    );
  }
}

class _LogoutDialogButton extends StatefulWidget {
  const _LogoutDialogButton({
    required this.buttonKey,
    required this.focusDebugLabel,
    required this.onPressed,
    required this.label,
    this.autofocus = false,
    this.style,
  });

  final Key buttonKey;
  final String focusDebugLabel;
  final VoidCallback onPressed;
  final String label;
  final bool autofocus;
  final ButtonStyle? style;

  @override
  State<_LogoutDialogButton> createState() => _LogoutDialogButtonState();
}

class _LogoutDialogButtonState extends State<_LogoutDialogButton> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'logout_${widget.focusDebugLabel}_button',
    )..addListener(_handleFocusChange);
    _debugLogoutDialogLog('mount ${widget.focusDebugLabel} button');
  }

  void _handleFocusChange() {
    _debugLogoutDialogLog(
      'focus ${widget.focusDebugLabel}=${_focusNode.hasFocus}',
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _debugLogoutDialogLog('dispose ${widget.focusDebugLabel} button');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      child: TextButton(
        key: widget.buttonKey,
        style: widget.style,
        onPressed: widget.onPressed,
        child: Text(widget.label),
      ),
    );
  }
}

void _debugLogoutDialogLog(String message) {
  if (kDebugMode) {
    debugPrint('[UI_STABILITY][LogoutDialog] $message');
  }
}
