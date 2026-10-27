import 'package:flutter/material.dart';

import '../rupiah.dart';

/// Kartu saldo gradien teal — persis BalanceCard di demo Swift.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.title, required this.amount});

  final String title;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A7363), Color(0xFF084A52)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet,
                size: 18, color: Colors.white70),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ]),
          const SizedBox(height: 9),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(amount.rupiah,
                style: const TextStyle(
                    fontSize: 31, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
