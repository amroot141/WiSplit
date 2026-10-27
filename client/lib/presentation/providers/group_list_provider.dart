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
}

final groupListProvider =
    StateNotifierProvider<GroupListNotifier, List<GroupModel>>((ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return GroupListNotifier(repository);
});
