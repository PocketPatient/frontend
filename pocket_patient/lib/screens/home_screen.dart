import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_session.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/completed_sessions_provider.dart';
import '../providers/courses_provider.dart';
import '../providers/session_provider.dart';
import '../providers/units_provider.dart';
import '../widgets/offline_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Week 12: tab scaffolding for Phase 3 analytics — Tab 2 is a
    // placeholder until the dashboards land. FAB only makes sense on the
    // cases/courses tab, so track the index to hide it on Tab 2.
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final coursesAsync = ref.watch(coursesProvider);
    final isProfessor = user?.role == 'professor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Patient v2'),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: isProfessor ? 'Courses' : 'Cases'),
            Tab(text: isProfessor ? 'Class Analytics' : 'Dashboard'),
          ],
        ),
      ),
      body: OfflineBannerScaffold(child: Column(children: [
        // Professor account pending verification banner
        if (isProfessor && user?.isVerified == false)
          Material(
            color: Colors.amber[700],
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your professor account is pending verification. '
                        'Some features may be restricted.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  // Refresh courses, then invalidate each course's unit
                  // provider so stale unit counts don't linger after
                  // professor changes.
                  final oldCourses =
                      ref.read(coursesProvider).valueOrNull ?? [];
                  for (final c in oldCourses) {
                    ref.invalidate(unitsProvider(c.id));
                  }
                  await ref.read(coursesProvider.notifier).refresh();
                },
                child: coursesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Could not load courses',
                            style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () =>
                              ref.read(coursesProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (courses) => _CourseList(
                    courses: courses,
                    isProfessor: isProfessor,
                    userName: user?.displayName ?? user?.email ?? '',
                  ),
                ),
              ),
              const _AnalyticsPlaceholder(),
            ],
          ),
        ),
      ])),
      floatingActionButton: _tabController.index != 0
          ? null
          : (isProfessor
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/create-course'),
                  backgroundColor: const Color(0xFFCC0033),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('New course'),
                )
              : FloatingActionButton.extended(
                  onPressed: () => context.push('/enroll'),
                  backgroundColor: const Color(0xFFCC0033),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Join course'),
                )),
    );
  }
}

class _AnalyticsPlaceholder extends StatelessWidget {
  const _AnalyticsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Analytics coming soon',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  final List<Course> courses;
  final bool isProfessor;
  final String userName;

  const _CourseList({
    required this.courses,
    required this.isProfessor,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
            child: Column(
              children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  isProfessor
                      ? "You haven't created any courses yet."
                      : "You're not enrolled in any courses yet.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  isProfessor
                      ? 'Tap "New course" to get started.'
                      : 'Tap "Join course" and enter your class code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: courses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              isProfessor ? 'Your courses' : 'Enrolled courses',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }
        return _CourseCard(
            course: courses[index - 1], isProfessor: isProfessor);
      },
    );
  }
}

class _CourseCard extends ConsumerWidget {
  final Course course;
  final bool isProfessor;

  const _CourseCard({required this.course, required this.isProfessor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Students: watch released unit count and completed session count
    final releasedCount = isProfessor
        ? 0
        : (ref.watch(unitsProvider(course.id)).valueOrNull ?? []).length;
    final completedCount = isProfessor
        ? 0
        : (ref.watch(completedSessionsProvider(course.id)).valueOrNull ?? [])
            .length;
    final session = isProfessor
        ? null
        : ref.watch(sessionProvider(course.id)).valueOrNull;
    final hasActiveCase = session?.isActive == true;
    final waitLevel = session?.waitLevel ?? WaitLevel.none;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: isProfessor
            ? () => context.push('/course/${course.id}', extra: course)
            : () => context.push('/chat/${course.id}', extra: course),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    course.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!course.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Inactive',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                  ),
              ],
            ),
            if (course.semester != null) ...[
              const SizedBox(height: 4),
              Text(
                course.semester!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                // Class code (professor sees it to share)
                if (isProfessor) ...[
                  _InfoChip(
                    icon: Icons.tag,
                    label: course.classCode,
                    onTap: () {
                      // Copy to clipboard
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${course.classCode} copied to clipboard')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.people_outline,
                    label: '${course.studentCount} student${course.studentCount == 1 ? '' : 's'}',
                  ),
                ] else ...[
                  _InfoChip(
                    icon: Icons.layers_outlined,
                    label: releasedCount == 0
                        ? 'No units active'
                        : '$releasedCount unit${releasedCount == 1 ? '' : 's'} active',
                    color: releasedCount > 0 ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  if (hasActiveCase) ...[
                    const _InfoChip(
                      icon: Icons.chat_bubble_outline,
                      label: 'Case in progress',
                      color: Colors.orange,
                    ),
                    if (waitLevel != WaitLevel.none) ...[
                      const SizedBox(width: 8),
                      _WaitDot(level: waitLevel),
                    ],
                  ] else
                    _InfoChip(
                      icon: Icons.check_circle_outline,
                      label: completedCount == 0
                          ? 'No cases done'
                          : '$completedCount completed',
                      color: completedCount > 0 ? Colors.blue : Colors.grey,
                    ),
                ],
              ],
            ),
          // Info message for students
          if (!isProfessor) ...[
            const SizedBox(height: 10),
            Text(
              hasActiveCase
                  ? (waitLevel == WaitLevel.red
                      ? 'Your patient is waiting.'
                      : 'Case in progress — tap to continue.')
                  : releasedCount == 0
                      ? 'No active units — check back later.'
                      : 'Your patient will reach out soon.',
              style: TextStyle(
                  color: waitLevel == WaitLevel.red
                      ? Colors.red[700]
                      : Colors.grey[500],
                  fontSize: 12,
                  fontWeight: waitLevel == WaitLevel.red
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontStyle: FontStyle.italic),
            ),
          ],
          ],
        ),
        ),
      ),
    );
  }
}

/// Response-time awareness dot (Week 10). Amber ≥12h, orange ≥24h, red ≥48h
/// since the patient's last message went unanswered.
class _WaitDot extends StatelessWidget {
  final WaitLevel level;

  const _WaitDot({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      WaitLevel.amber => Colors.amber[700]!,
      WaitLevel.orange => Colors.orange[800]!,
      WaitLevel.red => Colors.red[700]!,
      WaitLevel.none => Colors.transparent,
    };
    final label = switch (level) {
      WaitLevel.amber => 'Waiting 12h+',
      WaitLevel.orange => 'Waiting 24h+',
      WaitLevel.red => 'Waiting 48h+',
      WaitLevel.none => '',
    };
    return Semantics(
      label: label,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: effectiveColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: effectiveColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: chip);
    }
    return chip;
  }
}
