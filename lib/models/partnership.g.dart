// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'partnership.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Partnership _$PartnershipFromJson(Map<String, dynamic> json) => _Partnership(
  id: json['id'] as String,
  user1Id: json['user1_id'] as String,
  user2Id: json['user2_id'] as String?,
  status: json['status'] as String? ?? 'pending',
  createdAt: DateTime.parse(json['created_at'] as String),
  user1EcdhPub: json['user1_ecdh_pub'] as String?,
  user2EcdhPub: json['user2_ecdh_pub'] as String?,
  wrappedPartnershipKey: json['wrapped_partnership_key'] as String?,
);

Map<String, dynamic> _$PartnershipToJson(_Partnership instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user1_id': instance.user1Id,
      'user2_id': instance.user2Id,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
      'user1_ecdh_pub': instance.user1EcdhPub,
      'user2_ecdh_pub': instance.user2EcdhPub,
      'wrapped_partnership_key': instance.wrappedPartnershipKey,
    };
