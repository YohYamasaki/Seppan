import 'package:freezed_annotation/freezed_annotation.dart';

part 'partnership.freezed.dart';
part 'partnership.g.dart';

@freezed
abstract class Partnership with _$Partnership {
  const factory Partnership({
    required String id,
    required String user1Id,
    String? user2Id,
    required String inviteCode,
    @Default('pending') String status,
    required DateTime createdAt,
  }) = _Partnership;

  factory Partnership.fromJson(Map<String, dynamic> json) =>
      _$PartnershipFromJson(json);
}
