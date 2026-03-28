import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/payment.dart';

typedef PaymentSubmitCallback =
    Future<String?> Function(PaymentMethod paymentMethod);

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    required this.totalAmountMinor,
    required this.onSubmit,
    this.isSubmissionBlocked = false,
    this.blockedMessage,
    super.key,
  });

  final int totalAmountMinor;
  final PaymentSubmitCallback onSubmit;
  final bool isSubmissionBlocked;
  final String? blockedMessage;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  static const List<int> _commonQuickCashAmountsMinor = <int>[
    1000,
    2000,
    3000,
    4000,
    5000,
  ];

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;
  String? _errorMessage;
  late final TextEditingController _receivedController;

  @override
  void initState() {
    super.initState();
    _receivedController = TextEditingController(
      text: CurrencyFormatter.toEditableMajorInput(widget.totalAmountMinor),
    );
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double dialogWidth = math.min(screenSize.width * 0.78, 900);
    final bool isInteractionBlocked = widget.isSubmissionBlocked;
    final int receivedMinor = _receivedMinor;
    final int changeMinor = receivedMinor - widget.totalAmountMinor;
    final bool isPayEnabled =
        !_isSubmitting &&
        !isInteractionBlocked &&
        (_paymentMethod == PaymentMethod.card || changeMinor >= 0);
    final List<int> quickCashAmountsMinor = _buildQuickCashAmountsMinor();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingLg,
        vertical: AppSizes.spacingLg,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(320, screenSize.height - 48),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacingXl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    AppStrings.paymentTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppSizes.fontMd,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingSm),
                  Text(
                    CurrencyFormatter.fromMinor(widget.totalAmountMinor),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingXl),
                  SizedBox(
                    height: 56,
                    child: SegmentedButton<PaymentMethod>(
                      selected: <PaymentMethod>{_paymentMethod},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll<Size>(
                          Size.fromHeight(56),
                        ),
                        textStyle: const WidgetStatePropertyAll<TextStyle>(
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.surface;
                            }
                            return AppColors.primary;
                          },
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.primary;
                            }
                            return AppColors.surfaceMuted;
                          },
                        ),
                        side: const WidgetStatePropertyAll<BorderSide>(
                          BorderSide(color: AppColors.border),
                        ),
                      ),
                      segments: <ButtonSegment<PaymentMethod>>[
                        ButtonSegment(
                          value: PaymentMethod.cash,
                          label: Text(AppStrings.cash),
                        ),
                        ButtonSegment(
                          value: PaymentMethod.card,
                          label: Text(AppStrings.card),
                        ),
                      ],
                      onSelectionChanged: (Set<PaymentMethod> selected) {
                        if (selected.isEmpty) {
                          return;
                        }
                        setState(() {
                          _paymentMethod = selected.first;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                  if (_paymentMethod == PaymentMethod.cash) ...<Widget>[
                    const SizedBox(height: AppSizes.spacingXl),
                    Text(
                      AppStrings.receivedAmount,
                      style: const TextStyle(
                        fontSize: AppSizes.fontMd,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacingSm),
                    TextField(
                      key: const ValueKey<String>(
                        'payment-received-amount-field',
                      ),
                      controller: _receivedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: CurrencyFormatter.toEditableMajorInput(
                          widget.totalAmountMinor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacingMd,
                          vertical: AppSizes.spacingMd,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSizes.spacingMd),
                    Wrap(
                      spacing: AppSizes.spacingMd,
                      runSpacing: AppSizes.spacingMd,
                      children: <Widget>[
                        _QuickAmountButton(
                          key: const ValueKey<String>('quick-cash-exact'),
                          label: 'Exact',
                          onPressed: () =>
                              _setReceivedAmountMinor(widget.totalAmountMinor),
                        ),
                        for (final int amountMinor in quickCashAmountsMinor)
                          _QuickAmountButton(
                            key: ValueKey<String>('quick-cash-$amountMinor'),
                            label: _quickAmountLabel(amountMinor),
                            onPressed: () =>
                                _setReceivedAmountMinor(amountMinor),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spacingLg),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacingMd,
                        vertical: AppSizes.spacingMd,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: Text(
                        '${AppStrings.change}: ${CurrencyFormatter.fromMinor(changeMinor)}',
                        style: TextStyle(
                          fontSize: 20,
                          color: changeMinor < 0
                              ? AppColors.error
                              : AppColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: AppSizes.spacingMd),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: AppSizes.fontMd,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (isInteractionBlocked) ...<Widget>[
                    const SizedBox(height: AppSizes.spacingMd),
                    Text(
                      widget.blockedMessage ??
                          AppStrings.salesLockedAdminCloseRequired,
                      style: const TextStyle(
                        fontSize: AppSizes.fontMd,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.spacingXl),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusLg,
                                ),
                              ),
                            ),
                            child: Text(
                              AppStrings.cancel,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacingMd),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isPayEnabled ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusLg,
                                ),
                              ),
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.surfaceMuted,
                              disabledForegroundColor: AppColors.textSecondary,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: AppColors.surface,
                                    ),
                                  )
                                : Text(
                                    AppStrings.pay,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final String? error = await widget.onSubmit(_paymentMethod);
    if (!mounted) {
      return;
    }

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  int get _receivedMinor {
    if (_paymentMethod == PaymentMethod.card) {
      return widget.totalAmountMinor;
    }
    return CurrencyFormatter.tryParseEditableMajorInput(
          _receivedController.text,
        ) ??
        0;
  }

  void _setReceivedAmountMinor(int amountMinor) {
    final String nextValue = CurrencyFormatter.toEditableMajorInput(
      amountMinor,
    );
    _receivedController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
    setState(() {
      _errorMessage = null;
    });
  }

  List<int> _buildQuickCashAmountsMinor() {
    final List<int> quickAmountsMinor = <int>[
      _nextRoundedCashAmountMinor(widget.totalAmountMinor),
    ];

    for (final int amountMinor in _commonQuickCashAmountsMinor) {
      if (amountMinor > widget.totalAmountMinor &&
          !quickAmountsMinor.contains(amountMinor)) {
        quickAmountsMinor.add(amountMinor);
      }
    }

    int candidateMinor = ((quickAmountsMinor.last + 999) ~/ 1000) * 1000;
    if (candidateMinor <= quickAmountsMinor.last) {
      candidateMinor += 1000;
    }
    while (quickAmountsMinor.length < 5) {
      if (!quickAmountsMinor.contains(candidateMinor)) {
        quickAmountsMinor.add(candidateMinor);
      }
      candidateMinor += 1000;
    }

    return quickAmountsMinor;
  }

  int _nextRoundedCashAmountMinor(int totalAmountMinor) {
    int roundedMinor = ((totalAmountMinor + 499) ~/ 500) * 500;
    if (roundedMinor <= totalAmountMinor) {
      roundedMinor += 500;
    }
    return roundedMinor;
  }

  String _quickAmountLabel(int amountMinor) => '£${amountMinor ~/ 100}';
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(80, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppSizes.fontMd,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
