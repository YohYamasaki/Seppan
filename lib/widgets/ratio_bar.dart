import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../utils/formatters.dart';
import 'avatar_icon.dart';

/// A visual bar showing the expense burden split between two people.
///
/// When [interactive] is true (default false), the divider is larger.
/// When false, the divider is smaller to signal read-only state.
class RatioBar extends StatelessWidget {
  const RatioBar({
    super.key,
    required this.myPercent,
    required this.myName,
    required this.myIconId,
    required this.partnerName,
    required this.partnerIconId,
    this.amount,
    this.interactive = false,
  });

  final double myPercent;
  final String myName;
  final int myIconId;
  final String partnerName;
  final int partnerIconId;
  final int? amount;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final partnerPercent = 1 - myPercent;
    final atEdge = myPercent <= 0.05 || myPercent >= 0.95;
    final gap = atEdge ? 0.0 : (interactive ? 4.0 : 3.0);
    final innerR = Radius.circular(atEdge ? 24 : 3);
    // Smaller divider for read-only
    final dividerWidth = interactive ? 4.0 : 3.0;
    final dividerExtend = interactive ? 3.0 : 1.0;

    return LayoutBuilder(builder: (context, constraints) {
      final barWidth = constraints.maxWidth;
      final myW = barWidth * myPercent;

      return Column(
        children: [
          // Avatars + names above segments
          SizedBox(
            height: 52,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: myW.clamp(0.0, barWidth),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarIcon(iconId: myIconId, radius: 12),
                        const Gap(2),
                        Text(myName,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: myW.clamp(0.0, barWidth),
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarIcon(iconId: partnerIconId, radius: 12),
                        const Gap(2),
                        Text(partnerName,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(6),
          // Bar
          SizedBox(
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Left bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: (myW - gap).clamp(0.0, barWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.horizontal(
                        left: const Radius.circular(24),
                        right: innerR,
                      ),
                    ),
                  ),
                ),
                // Right bar
                Positioned(
                  left: (myW + gap).clamp(0.0, barWidth),
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.horizontal(
                        left: innerR,
                        right: const Radius.circular(24),
                      ),
                    ),
                  ),
                ),
                // Divider
                if (!atEdge)
                  Positioned(
                    left: myW - dividerWidth / 2,
                    top: -dividerExtend,
                    bottom: -dividerExtend,
                    width: dividerWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(dividerWidth / 2),
                      ),
                    ),
                  ),
                // My % text
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: myW.clamp(0.0, barWidth),
                  child: Center(
                    child: Opacity(
                      opacity: myPercent >= 0.15 ? 1.0 : 0.0,
                      child: Text(
                        '${(myPercent * 100).round()}%',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                // Partner % text
                Positioned(
                  left: myW.clamp(0.0, barWidth),
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: partnerPercent >= 0.15 ? 1.0 : 0.0,
                      child: Text(
                        '${(partnerPercent * 100).round()}%',
                        style: TextStyle(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Amounts below (optional)
          if (amount != null && amount! > 0) ...[
            const Gap(8),
            SizedBox(
              height: 22,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: myW.clamp(0.0, barWidth),
                    child: Center(
                      child: Text(
                        formatJpy((amount! * myPercent).round()),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  Positioned(
                    left: myW.clamp(0.0, barWidth),
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        formatJpy(
                            (amount! * partnerPercent).round()),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}
