import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/category.dart';
import '../models/partnership.dart';
import '../models/profile.dart';
import '../repositories/partnership_repository.dart';
import 'auth_provider.dart';

part 'partnership_provider.g.dart';

@riverpod
PartnershipRepository partnershipRepository(Ref ref) {
  return PartnershipRepository();
}

@riverpod
Future<Partnership?> activePartnership(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  try {
    return await ref.watch(partnershipRepositoryProvider).getActivePartnership(user.id);
  } catch (_) {
    return null;
  }
}

@riverpod
Future<Profile?> partnerProfile(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  final partnership = await ref.watch(activePartnershipProvider.future);
  if (user == null || partnership == null) return null;
  final partnerId = partnership.user1Id == user.id
      ? partnership.user2Id
      : partnership.user1Id;
  if (partnerId == null) return null;
  try {
    return await ref.watch(profileRepositoryProvider).getProfile(partnerId);
  } catch (_) {
    return null;
  }
}

@riverpod
Stream<Partnership> partnershipStream(Ref ref, String partnershipId) {
  return ref.watch(partnershipRepositoryProvider).watchPartnership(partnershipId);
}

@riverpod
Future<List<Category>> categories(Ref ref) async {
  final partnership = await ref.watch(activePartnershipProvider.future);
  if (partnership == null) return [];
  return ref.watch(partnershipRepositoryProvider).getCategories(partnership.id);
}
