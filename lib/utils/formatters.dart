import 'package:intl/intl.dart';

final jpyFormat = NumberFormat('#,###', 'ja');
final dateFormat = DateFormat.yMd('ja');

String formatJpy(int amount) => '¥${jpyFormat.format(amount)}';
String formatDate(DateTime date) => dateFormat.format(date);

String ratioLabel(double ratio) {
  return '${(ratio * 100).round()}%';
}

/// Returns a description of the ratio for display.
/// 100% → おごり, 0% → 立て替え, otherwise empty.
String ratioDescription(double ratio, String payerName) {
  if (ratio >= 1.0) return '$payerNameさんのおごり';
  if (ratio <= 0.0) return '$payerNameさんが立て替え';
  return '';
}
