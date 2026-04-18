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

  // My avatar is always larger than partner's, so users can tell at a
  // glance which side represents themselves.
  static const double _myRadius = 32;
  static const double _partnerRadius = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Glow/border color based on each side's state.
    // balance > 0 → I'm plus (green), partner is minus (red)
    // balance < 0 → I'm minus (red), partner is plus (green)
    // balance = 0 → no glow
    final Color? myGlowColor = balance > 0
        ? Colors.green
        : balance < 0
        ? Colors.red
        : null;
    final Color? partnerGlowColor = balance > 0
        ? Colors.red
        : balance < 0
        ? Colors.green
        : null;

    return MainCard(
      header: Text('支払い状況', style: theme.textTheme.displayMedium),
      child: Column(
        children: [
          // Dual avatar row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // My side
              Expanded(
                child: Column(
                  children: [
                    _StyledAvatar(
                      iconId: myIconId,
                      radius: _myRadius,
                      glowColor: myGlowColor,
                    ),
                    const Gap(6),
                    Text(
                      myName,
                      style: theme.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Center: amount with +/- sign
              Expanded(
                flex: 2,
                child: _buildCenterSection(context, colorScheme),
              ),

              // Partner side
              Expanded(
                child: Column(
                  children: [
                    _StyledAvatar(
                      iconId: partnerIconId,
                      radius: _partnerRadius,
                      glowColor: partnerGlowColor,
                    ),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: _statusColor(colorScheme).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
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

    // Positive balance = partner owes me → + in success color (green).
    // Negative balance = I owe partner → - in error color.
    final amountColor = balance > 0 ? Colors.green : colorScheme.error;
    final sign = balance > 0 ? '+' : '-';

    return Center(
      child: Text(
        '$sign${formatJpy(balance.abs())}',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme colorScheme) {
    if (balance == 0) return colorScheme.tertiary;
    if (balance > 0) return Colors.green;
    return colorScheme.error;
  }

  String get _statusMessage {
    if (balance == 0) return '精算済みです';
    if (balance > 0) {
      return '$myNameさんが${formatJpy(balance)}多く支払っています';
    }
    return '$myNameさんが${formatJpy(balance.abs())}分支払ってください';
  }
}

/// Avatar with an optional glowing border.
class _StyledAvatar extends StatelessWidget {
  const _StyledAvatar({
    required this.iconId,
    required this.radius,
    this.glowColor,
  });

  final int iconId;
  final double radius;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final hasGlow = glowColor != null;
    return Container(
      padding: hasGlow ? const EdgeInsets.all(2) : null,
      decoration: hasGlow
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: glowColor!.withValues(alpha: 0.5),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.12),
                  blurRadius: 10,
                ),
              ],
            )
          : null,
      child: AvatarIcon(iconId: iconId, radius: radius),
    );
  }
}
