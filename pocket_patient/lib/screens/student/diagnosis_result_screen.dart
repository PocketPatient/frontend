import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/diagnosis_result.dart';

/// Full-screen result shown after a correct diagnosis.
/// Navigation: pushed via context.push('/diagnosis-result/:courseId', extra: result)
class DiagnosisResultScreen extends StatelessWidget {
  final DiagnosisResult result;
  final String courseId;

  const DiagnosisResultScreen({
    super.key,
    required this.result,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    final reveal = result.reveal;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
        title: const Text('Case Complete'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green[200]!, width: 2),
                ),
                child: Icon(Icons.check_circle_outline_rounded,
                    size: 52, color: Colors.green[600]),
              ),
              const SizedBox(height: 16),
              Text(
                'Correct Diagnosis!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
              ),

              // Reveal section
              if (reveal != null) ...[
                const SizedBox(height: 28),
                _SectionCard(
                  title: 'Diagnosis Revealed',
                  icon: Icons.local_hospital_outlined,
                  iconColor: const Color(0xFFCC0033),
                  children: [
                    _RevealRow(
                      label: 'Condition',
                      value: reveal.diseaseName,
                      bold: true,
                    ),
                    if (reveal.dsmCode != null) ...[
                      const SizedBox(height: 6),
                      _RevealRow(
                        label: 'DSM Code',
                        value: reveal.dsmCode!,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _RevealRow(
                      label: 'Unit',
                      value: reveal.unitLabel,
                    ),
                  ],
                ),
              ],

              // Score section
              if (score != null) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Your Score',
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFFCC0033),
                  children: [
                    // Total score highlight
                    if (score.totalScore != null) ...[
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '${score.totalScore!.toStringAsFixed(1)} pts',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: _scoreColor(score.totalScore!),
                              ),
                            ),
                            Text(
                              'Total Score',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                    ],
                    // Sub-scores
                    if (score.rubricScore != null)
                      _ScoreRow(
                        label: 'Clinical Reasoning',
                        value: score.rubricScore!,
                      ),
                    if (score.responseTimeScore != null) ...[
                      const SizedBox(height: 6),
                      _ScoreRow(
                        label: 'Response Time',
                        value: score.responseTimeScore!,
                      ),
                    ],
                    // Your diagnosis submitted
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    _RevealRow(
                        label: 'You submitted', value: score.primaryDx),
                    if (score.differentials.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _RevealRow(
                        label: 'Differentials',
                        value: score.differentials.join(', '),
                      ),
                    ],
                  ],
                ),

                // Feedback
                if (score.feedbackText != null && score.feedbackText!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Feedback',
                    icon: Icons.comment_outlined,
                    iconColor: Colors.blue[600]!,
                    children: [
                      Text(
                        score.feedbackText!,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.5),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 32),

              // Back to home
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Pop back to home, clearing the chat stack
                    context.go('/home');
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text(
                    'Back to Cases',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0033),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green[700]!;
    if (score >= 60) return Colors.orange[700]!;
    return Colors.red[600]!;
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _RevealRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _RevealRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[900],
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double value;

  const _ScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
