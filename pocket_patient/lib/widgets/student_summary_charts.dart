import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/student_summary.dart';

const _scarlet = Color(0xFFCC0033);

/// Renders the full chart set for a [StudentSummary]: overview stats, score
/// trend, category radar (or bar fallback), response-time trend. Shared by
/// the student's own dashboard (Week 13) and the professor's per-student
/// drill-down (Week 14) — same charts, different data source.
class StudentSummaryCharts extends StatelessWidget {
  final StudentSummary summary;

  const StudentSummaryCharts({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.completedCases == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          children: [
            Icon(Icons.query_stats_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No completed cases yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _OverviewStats(summary: summary),
        const SizedBox(height: 16),
        _ScoreTrendCard(summary: summary),
        const SizedBox(height: 16),
        _CategoryRadarCard(summary: summary),
        const SizedBox(height: 16),
        _ResponseTimeTrendCard(summary: summary),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Overview stats
// ---------------------------------------------------------------------------

class _OverviewStats extends StatelessWidget {
  final StudentSummary summary;

  const _OverviewStats({required this.summary});

  @override
  Widget build(BuildContext context) {
    final avgResponseLabel = summary.avgResponseTimeSec != null
        ? _formatDuration(summary.avgResponseTimeSec!)
        : '—';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _StatTile(
          label: 'Cases completed',
          value: '${summary.completedCases}',
          icon: Icons.check_circle_outline,
        ),
        _StatTile(
          label: 'Average score',
          value: summary.avgScore != null ? '${summary.avgScore!.round()}%' : '—',
          icon: Icons.grade_outlined,
        ),
        _StatTile(
          label: 'Avg response time',
          value: avgResponseLabel,
          icon: Icons.timer_outlined,
        ),
        _StatTile(
          label: 'Current streak',
          value: '${summary.currentStreak}',
          icon: Icons.local_fire_department_outlined,
        ),
      ],
    );
  }

  static String _formatDuration(double seconds) {
    if (seconds < 60) return '${seconds.round()}s';
    final minutes = seconds / 60;
    if (minutes < 60) return '${minutes.round()}m';
    final hours = minutes / 60;
    return '${hours.toStringAsFixed(1)}h';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: _scarlet, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score trend line chart
// ---------------------------------------------------------------------------

class _ScoreTrendCard extends StatelessWidget {
  final StudentSummary summary;

  const _ScoreTrendCard({required this.summary});

  static Color _bandColor(double score) {
    if (score > 70) return Colors.green[600]!;
    if (score >= 50) return Colors.amber[700]!;
    return Colors.red[600]!;
  }

  @override
  Widget build(BuildContext context) {
    final cases = summary.scoresByCase;
    final points = <FlSpot>[
      for (var i = 0; i < cases.length; i++)
        if (cases[i].score != null) FlSpot((i + 1).toDouble(), cases[i].score!),
    ];

    return _ChartCard(
      title: 'Score trend',
      child: points.isEmpty
          ? _EmptyChartMessage()
          : SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: const FlGridData(horizontalInterval: 25),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 25,
                        getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: summary.avgScore != null
                      ? ExtraLinesData(horizontalLines: [
                          HorizontalLine(
                            y: summary.avgScore!,
                            color: Colors.grey[500]!,
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              labelResolver: (line) => 'avg ${line.y.round()}',
                            ),
                          ),
                        ])
                      : const ExtraLinesData(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      isCurved: true,
                      color: _scarlet,
                      barWidth: 2,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 4,
                          color: _bandColor(spot.y),
                          strokeWidth: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category radar chart + weak areas
// ---------------------------------------------------------------------------

class _CategoryRadarCard extends StatelessWidget {
  final StudentSummary summary;

  const _CategoryRadarCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final categories = summary.scoresByCategory.keys.toList()..sort();

    return _ChartCard(
      title: 'Performance by category',
      child: Column(
        children: [
          if (categories.length < 3)
            _CategoryBarFallback(summary: summary, categories: categories)
          else
            SizedBox(
              height: 240,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  tickCount: 4,
                  ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
                  radarBorderData: BorderSide(color: Colors.grey[300]!),
                  gridBorderData: BorderSide(color: Colors.grey[200]!, width: 1),
                  titleTextStyle: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  getTitle: (index, angle) => RadarChartTitle(text: categories[index]),
                  dataSets: [
                    RadarDataSet(
                      fillColor: _scarlet.withValues(alpha: 0.15),
                      borderColor: _scarlet,
                      entryRadius: 3,
                      borderWidth: 2,
                      dataEntries: [
                        for (final c in categories)
                          RadarEntry(value: summary.scoresByCategory[c]!.avgScore),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (summary.weakCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Weak areas',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            ),
            const SizedBox(height: 8),
            ...summary.weakCategories.take(3).map((cat) {
              final score = summary.scoresByCategory[cat]?.avgScore;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cat,
                            style: TextStyle(fontSize: 13, color: Colors.red[900])),
                      ),
                      if (score != null)
                        Text('${score.round()}%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700])),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Radar charts with fewer than 3 axes don't read as a meaningful shape —
/// fall back to a simple bar-per-category list instead.
class _CategoryBarFallback extends StatelessWidget {
  final StudentSummary summary;
  final List<String> categories;

  const _CategoryBarFallback({required this.summary, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: categories.map((c) {
        final score = summary.scoresByCategory[c]!.avgScore;
        final isWeak = summary.weakCategories.contains(c);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c, style: const TextStyle(fontSize: 13)),
                  Text('${score.round()}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isWeak ? Colors.red[700] : Colors.grey[800])),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (score / 100).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(isWeak ? Colors.red[400]! : _scarlet),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Response time trend
// ---------------------------------------------------------------------------

class _ResponseTimeTrendCard extends StatelessWidget {
  final StudentSummary summary;

  const _ResponseTimeTrendCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final points = summary.responseTimeTrend
        .where((p) => p.avgLatencySec != null)
        .toList();

    if (points.isEmpty) {
      return _ChartCard(title: 'Response time trend', child: _EmptyChartMessage());
    }

    final minutes = points.map((p) => p.avgLatencySec! / 60).toList();
    final maxY = (minutes.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1, double.infinity);

    final trend = _trendLabel(minutes);

    return _ChartCard(
      title: 'Response time trend',
      trailing: trend,
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY.toDouble(),
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, meta) => Text('${v.toInt()}m',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(x: points[i].caseNumber, barRods: [
                  BarChartRodData(
                    toY: minutes[i],
                    color: _scarlet,
                    width: 14,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trendLabel(List<double> minutes) {
    if (minutes.length < 2) return const SizedBox.shrink();
    final mid = minutes.length ~/ 2;
    final firstHalf = minutes.sublist(0, mid);
    final secondHalf = minutes.sublist(mid);
    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    const epsilon = 0.5; // minutes — ignore noise below this
    if (secondAvg < firstAvg - epsilon) {
      return _TrendChip(label: 'Getting faster', icon: Icons.trending_down, color: Colors.green[700]!);
    }
    if (secondAvg > firstAvg + epsilon) {
      return _TrendChip(label: 'Slowing down', icon: Icons.trending_up, color: Colors.red[700]!);
    }
    return _TrendChip(label: 'Steady', icon: Icons.trending_flat, color: Colors.grey[600]!);
  }
}

class _TrendChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _TrendChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card chrome
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _ChartCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text('Not enough data yet.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ),
    );
  }
}
