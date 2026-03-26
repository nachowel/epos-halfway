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
    super.key,
  });

  final int totalAmountMinor;
  final PaymentSubmitCallback onSubmit;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;
  String? _errorMessage;
  late final TextEditingController _receivedController;

  @override
  void initState() {
    super.initState();
    _receivedController = TextEditingController(
      text: (widget.totalAmountMinor / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int receivedMinor = _paymentMethod == PaymentMethod.card
        ? widget.totalAmountMinor
        : _parseReceivedMinor(_receivedController.text);
    final int changeMinor = receivedMinor - widget.totalAmountMinor;
    final bool isPayEnabled =
        !_isSubmitting &&
        (_paymentMethod == PaymentMethod.card || changeMinor >= 0);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        AppStrings.paymentTitle,
        style: TextStyle(fontSize: AppSizes.fontMd),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              CurrencyFormatter.fromMinor(widget.totalAmountMinor),
              style: const TextStyle(
                fontSize: AppSizes.fontLg,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            SegmentedButton<PaymentMethod>(
              selected: <PaymentMethod>{_paymentMethod},
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: AppSizes.fontSm),
                ),
              ),
              segments: const <ButtonSegment<PaymentMethod>>[
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
            const SizedBox(height: AppSizes.spacingMd),
            if (_paymentMethod == PaymentMethod.cash) ...<Widget>[
              TextField(
                controller: _receivedController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: AppSizes.fontSm),
                decoration: const InputDecoration(
                  labelText: AppStrings.receivedAmount,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.spacingSm),
              Text(
                '${AppStrings.change}: ${CurrencyFormatter.fromMinor(changeMinor)}',
                style: TextStyle(
                  fontSize: AppSizes.fontSm,
                  color: changeMinor < 0 ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSizes.spacingSm),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        SizedBox(
          height: AppSizes.minTouch,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text(
              AppStrings.cancel,
              style: TextStyle(fontSize: AppSizes.fontSm),
            ),
          ),
        ),
        SizedBox(
          height: AppSizes.minTouch,
          child: ElevatedButton(
            onPressed: isPayEnabled ? _submit : null,
            child: _isSubmitting
                ? const CircularProgressIndicator(color: AppColors.surface)
                : const Text(
                    AppStrings.pay,
                    style: TextStyle(fontSize: AppSizes.fontSm),
                  ),
          ),
        ),
      ],
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

  int _parseReceivedMinor(String rawValue) {
    final String normalized = rawValue.trim().replaceAll(',', '.');
    final double? parsed = double.tryParse(normalized);
    if (parsed == null) {
      return 0;
    }
    return (parsed * 100).round();
  }
}
