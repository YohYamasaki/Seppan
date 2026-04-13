import 'package:freezed_annotation/freezed_annotation.dart';

part 'partnership.freezed.dart';
part 'partnership.g.dart';

@freezed
abstract class Partnership with _$Partnership {
  const factory Partnership({
    required String id,
    required String user1Id,
    String? user2Id,
    @Default('pending') String status,
    required DateTime createdAt,
    String? user1EcdhPub,
    String? user2EcdhPub,
    String? wrappedPartnershipKey,
  }) = _Partnership;

  factory Partnership.fromJson(Map<String, dynamic> json) =>
      _$PartnershipFromJson(json);
}
