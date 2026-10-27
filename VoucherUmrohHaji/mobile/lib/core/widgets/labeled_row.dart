import 'package:flutter/material.dart';

/// Baris "label ..... value" seperti LabeledContent di SwiftUI.
class LabeledRow extends StatelessWidget {
  const LabeledRow(this.label, this.value, {super.key, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value,
              style: valueStyle ??
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
