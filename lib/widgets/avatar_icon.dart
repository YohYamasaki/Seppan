import 'package:flutter/material.dart';

import '../config/theme.dart';

class AvatarIcon extends StatelessWidget {
  const AvatarIcon({
    super.key,
    required this.iconId,
    this.radius = 24,
  });

  final int iconId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: seppanBrandColor.withValues(alpha: 0.2),
      backgroundImage: AssetImage('assets/avatar_icons/avatar$iconId.png'),
    );
  }
}
