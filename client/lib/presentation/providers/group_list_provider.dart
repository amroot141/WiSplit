import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/group_model.dart';
import '../../data/repositories/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) => GroupRepository());

class GroupListNotifier extends StateNotifier<List<GroupModel>> {
  final GroupRepository _repository;

  GroupListNotifier(this._repository) : super([]) {
    loadGroups();
  }

  Future<void> loadGroups() async {
    final groups = await _repository.getAllGroups();
    state = groups;
  }

  Future<GroupModel> createGroup({
    required String name,
    String description = '',
    String currency = 'INR',
    required String createdBy,
    required List<String> members,
  }) async {
    final newGroup = GroupModel(
      id: const Uuid().v4(),
      name: name,
      description: description,
      currency: currency,
      createdBy: createdBy,
      members: members,
      createdAt: DateTime.now(),
    );

    await _repository.saveGroup(newGroup);
    state = [newGroup, ...state];
    return newGroup;
  }

  Future<void> deleteGroup(String groupId) async {
    await _repository.deleteGroup(groupId);
    state = state.where((g) => g.id != groupId).toList();
  }

  Future<void> addMemberToGroup(String groupId, String newMemberName) async {
    final trimmed = newMemberName.trim();
    if (trimmed.isEmpty) return;

    final groupIndex = state.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) return;

    final group = state[groupIndex];
    if (group.members.any((m) => m.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }

    final updatedMembers = [...group.members, trimmed];
    final updatedGroup = group.copyWith(members: updatedMembers);

    await _repository.saveGroup(updatedGroup);
    final updatedList = List<GroupModel>.from(state);
    updatedList[groupIndex] = updatedGroup;
    state = updatedList;
  }

  Future<GroupModel?> joinGroupByInviteCode({
    required String code,
    required String memberName,
    required String currentUserId,
  }) async {
    final joined = await _repository.joinGroupByInviteCode(
      code: code,
      memberName: memberName,
      currentUserId: currentUserId,
    );

    if (joined != null) {
      final existingIndex = state.indexWhere((g) => g.id == joined.id);
      if (existingIndex >= 0) {
        final updatedList = List<GroupModel>.from(state);
        updatedList[existingIndex] = joined;
        state = updatedList;
      } else {
        state = [joined, ...state];
      }
    }
    return joined;
  }

  Future<void> refreshGroupsFromCloud() async {
    await _repository.syncAllGroups();
    final groups = await _repository.getAllGroups();
    state = groups;
  }
}

final groupListProvider =
    StateNotifierProvider<GroupListNotifier, List<GroupModel>>((ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return GroupListNotifier(repository);
});
