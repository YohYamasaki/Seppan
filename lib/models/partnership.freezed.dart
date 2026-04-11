// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'partnership.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Partnership {

 String get id; String get user1Id; String? get user2Id; String get inviteCode; String get status; DateTime get createdAt;
/// Create a copy of Partnership
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PartnershipCopyWith<Partnership> get copyWith => _$PartnershipCopyWithImpl<Partnership>(this as Partnership, _$identity);

  /// Serializes this Partnership to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Partnership&&(identical(other.id, id) || other.id == id)&&(identical(other.user1Id, user1Id) || other.user1Id == user1Id)&&(identical(other.user2Id, user2Id) || other.user2Id == user2Id)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,user1Id,user2Id,inviteCode,status,createdAt);

@override
String toString() {
  return 'Partnership(id: $id, user1Id: $user1Id, user2Id: $user2Id, inviteCode: $inviteCode, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PartnershipCopyWith<$Res>  {
  factory $PartnershipCopyWith(Partnership value, $Res Function(Partnership) _then) = _$PartnershipCopyWithImpl;
@useResult
$Res call({
 String id, String user1Id, String? user2Id, String inviteCode, String status, DateTime createdAt
});




}
/// @nodoc
class _$PartnershipCopyWithImpl<$Res>
    implements $PartnershipCopyWith<$Res> {
  _$PartnershipCopyWithImpl(this._self, this._then);

  final Partnership _self;
  final $Res Function(Partnership) _then;

/// Create a copy of Partnership
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? user1Id = null,Object? user2Id = freezed,Object? inviteCode = null,Object? status = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user1Id: null == user1Id ? _self.user1Id : user1Id // ignore: cast_nullable_to_non_nullable
as String,user2Id: freezed == user2Id ? _self.user2Id : user2Id // ignore: cast_nullable_to_non_nullable
as String?,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Partnership].
extension PartnershipPatterns on Partnership {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Partnership value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Partnership() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Partnership value)  $default,){
final _that = this;
switch (_that) {
case _Partnership():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Partnership value)?  $default,){
final _that = this;
switch (_that) {
case _Partnership() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String user1Id,  String? user2Id,  String inviteCode,  String status,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Partnership() when $default != null:
return $default(_that.id,_that.user1Id,_that.user2Id,_that.inviteCode,_that.status,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String user1Id,  String? user2Id,  String inviteCode,  String status,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Partnership():
return $default(_that.id,_that.user1Id,_that.user2Id,_that.inviteCode,_that.status,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String user1Id,  String? user2Id,  String inviteCode,  String status,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Partnership() when $default != null:
return $default(_that.id,_that.user1Id,_that.user2Id,_that.inviteCode,_that.status,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Partnership implements Partnership {
  const _Partnership({required this.id, required this.user1Id, this.user2Id, required this.inviteCode, this.status = 'pending', required this.createdAt});
  factory _Partnership.fromJson(Map<String, dynamic> json) => _$PartnershipFromJson(json);

@override final  String id;
@override final  String user1Id;
@override final  String? user2Id;
@override final  String inviteCode;
@override@JsonKey() final  String status;
@override final  DateTime createdAt;

/// Create a copy of Partnership
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PartnershipCopyWith<_Partnership> get copyWith => __$PartnershipCopyWithImpl<_Partnership>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PartnershipToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Partnership&&(identical(other.id, id) || other.id == id)&&(identical(other.user1Id, user1Id) || other.user1Id == user1Id)&&(identical(other.user2Id, user2Id) || other.user2Id == user2Id)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,user1Id,user2Id,inviteCode,status,createdAt);

@override
String toString() {
  return 'Partnership(id: $id, user1Id: $user1Id, user2Id: $user2Id, inviteCode: $inviteCode, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PartnershipCopyWith<$Res> implements $PartnershipCopyWith<$Res> {
  factory _$PartnershipCopyWith(_Partnership value, $Res Function(_Partnership) _then) = __$PartnershipCopyWithImpl;
@override @useResult
$Res call({
 String id, String user1Id, String? user2Id, String inviteCode, String status, DateTime createdAt
});




}
/// @nodoc
class __$PartnershipCopyWithImpl<$Res>
    implements _$PartnershipCopyWith<$Res> {
  __$PartnershipCopyWithImpl(this._self, this._then);

  final _Partnership _self;
  final $Res Function(_Partnership) _then;

/// Create a copy of Partnership
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? user1Id = null,Object? user2Id = freezed,Object? inviteCode = null,Object? status = null,Object? createdAt = null,}) {
  return _then(_Partnership(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user1Id: null == user1Id ? _self.user1Id : user1Id // ignore: cast_nullable_to_non_nullable
as String,user2Id: freezed == user2Id ? _self.user2Id : user2Id // ignore: cast_nullable_to_non_nullable
as String?,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
