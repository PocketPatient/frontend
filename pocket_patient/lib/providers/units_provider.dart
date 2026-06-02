import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';
import '../providers/auth_provider.dart';

final unitsProvider =
    AsyncNotifierProvider.family<UnitsNotifier, List<Unit>, String>(
  UnitsNotifier.new,
);

class UnitsNotifier extends FamilyAsyncNotifier<List<Unit>, String> {
  String get _courseId => arg;

  @override
  Future<List<Unit>> build(String arg) async {
    return await ref.read(apiServiceProvider).getUnits(arg);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(apiServiceProvider).getUnits(_courseId));
  }

  Future<void> releaseUnit(String unitId) async {
    final updated =
        await ref.read(apiServiceProvider).releaseUnit(_courseId, unitId);
    _replace(updated);
  }

  Future<void> closeUnit(String unitId) async {
    final updated =
        await ref.read(apiServiceProvider).closeUnit(_courseId, unitId);
    _replace(updated);
  }

  void _replace(Unit updated) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((u) => u.id == updated.id ? updated : u).toList(),
    );
  }
}
