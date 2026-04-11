import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../utils/formatters.dart';
import 'avatar_icon.dart';
import 'main_card.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.myName,
    required this.myIconId,
    required this.partnerName,
    required this.partnerIconId,
    required this.balance,
  });

  final String myName;
  final int myIconId;
  final String partnerName;
  final int partnerIconId;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MainCard(
      header: Text('支払い状況', style: theme.textTheme.displayMedium),
      child: Column(
        children: [
          // Dual avatar row
          Row(
            children: [
              // My side
              Expanded(
                child: Column(
                  children: [
                    AvatarIcon(iconId: myIconId, radius: 28),
                    const Gap(6),
                    Text(
                      myName,
                      style: theme.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Center: arrow + amount
              Expanded(
                flex: 2,
                child: _buildCenterSection(context, colorScheme),
              ),

              // Partner side
              Expanded(
                child: Column(
                  children: [
                    AvatarIcon(iconId: partnerIconId, radius: 28),
                    const Gap(6),
                    Text(
                      partnerName,
                      style: theme.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),

          // Status message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _statusColor(colorScheme).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _statusColor(colorScheme),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSection(BuildContext context, ColorScheme colorScheme) {
    if (balance == 0) {
      return Column(
        children: [
          Icon(Icons.check_circle, color: colorScheme.tertiary, size: 32),
          const Gap(4),
          Text(
            'ぴったり!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.tertiary,
            ),
          ),
        ],
      );
    }

    // Arrow points from debtor → creditor
    final amountColor = balance > 0 ? colorScheme.primary : colorScheme.error;
    final arrowIcon =
        balance > 0 ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded;

    return Column(
      children: [
        Text(
          formatJpy(balance.abs()),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
        const Gap(2),
        Icon(arrowIcon, color: amountColor, size: 28),
      ],
    );
  }

  Color _statusColor(ColorScheme colorScheme) {
    if (balance == 0) return colorScheme.tertiary;
    if (balance > 0) return colorScheme.primary;
    return colorScheme.error;
  }

  String get _statusMessage {
    if (balance == 0) return '精算済みです';
    if (balance > 0) {
      return '$partnerNameさんが${formatJpy(balance)}支払ってください';
    }
    return '$myNameさんが${formatJpy(balance.abs())}支払ってください';
  }
}
