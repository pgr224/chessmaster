import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Post-game analysis chart showing evaluation over time.
/// Uses fl_chart LineChart to visualize engine eval swings through the game.
class PostGameAnalysisChart extends StatelessWidget {
  final List<double>
      evalHistory; // eval scores per move (positive = white advantage)
  final int totalMoves;
  final double accuracy;
  final int mistakes;
  final int blunders;
  final int bestMoves;

  const PostGameAnalysisChart({
    super.key,
    required this.evalHistory,
    required this.totalMoves,
    this.accuracy = 0.0,
    this.mistakes = 0,
    this.blunders = 0,
    this.bestMoves = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (evalHistory.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyCard.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.skyBlue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics_rounded,
                    color: AppTheme.skyBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'GAME ANALYSIS',
                style: GoogleFonts.fredoka(
                  color: AppTheme.skyBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // The chart
          SizedBox(
            height: 160,
            child: _buildChart(),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('Accuracy', '${accuracy.toStringAsFixed(1)}%',
                  AppTheme.accentCyan),
              _miniStat('Best', '$bestMoves', AppTheme.goldPrimary),
              _miniStat('Mistakes', '$mistakes', AppTheme.lavender),
              _miniStat('Blunders', '$blunders', AppTheme.accentRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Clamp eval values for display
    final clampedEvals = evalHistory.map((e) => e.clamp(-5.0, 5.0)).toList();

    // Find min and max for proper Y-axis scaling
    double minY = -3.0;
    double maxY = 3.0;
    for (final e in clampedEvals) {
      if (e < minY) minY = e - 0.5;
      if (e > maxY) maxY = e + 0.5;
    }
    minY = minY.clamp(-6.0, -1.0);
    maxY = maxY.clamp(1.0, 6.0);

    final spots = List.generate(clampedEvals.length, (i) {
      return FlSpot(i.toDouble(), clampedEvals[i]);
    });

    // Create gradient areas for white/black advantage
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            if (value == 0) {
              return FlLine(
                color: Colors.white.withOpacity(0.3),
                strokeWidth: 1.5,
              );
            }
            return FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: _calculateInterval(clampedEvals.length),
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt() + 1}',
                  style:
                      GoogleFonts.jura(color: AppTheme.textMuted, fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 2,
              getTitlesWidget: (value, meta) {
                String label;
                if (value == 0) {
                  label = '=';
                } else if (value > 0) {
                  label = '+${value.toInt()}';
                } else {
                  label = '${value.toInt()}';
                }
                return Text(
                  label,
                  style:
                      GoogleFonts.jura(color: AppTheme.textMuted, fontSize: 9),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (clampedEvals.length - 1).toDouble().clamp(1, double.infinity),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final moveNum = spot.x.toInt() + 1;
                final eval = spot.y;
                final evalStr = eval >= 0
                    ? '+${eval.toStringAsFixed(1)}'
                    : eval.toStringAsFixed(1);
                return LineTooltipItem(
                  'Move $moveNum\n$evalStr',
                  GoogleFonts.fredoka(
                    color: eval >= 0 ? Colors.white : AppTheme.accentRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            gradient: LinearGradient(
              colors: [
                AppTheme.accentCyan.withOpacity(0.8),
                AppTheme.skyBlue.withOpacity(0.8),
              ],
            ),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final eval = spot.y;
                Color dotColor;
                if (index > 0) {
                  final prevEval = clampedEvals[index - 1];
                  final diff = eval - prevEval;
                  if (diff.abs() > 1.5) {
                    dotColor =
                        diff < 0 ? AppTheme.accentRed : AppTheme.goldPrimary;
                  } else {
                    dotColor = AppTheme.skyBlue;
                  }
                } else {
                  dotColor = AppTheme.skyBlue;
                }
                return FlDotCirclePainter(
                  radius: 2.5,
                  color: dotColor,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.accentCyan.withOpacity(0.15),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
              cutOffY: 0,
              applyCutOffY: true,
            ),
            aboveBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppTheme.accentRed.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
              cutOffY: 0,
              applyCutOffY: true,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateInterval(int dataLength) {
    if (dataLength <= 10) return 1;
    if (dataLength <= 20) return 2;
    if (dataLength <= 40) return 5;
    return 10;
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.fredoka(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.baloo2(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navyCard.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded,
              color: AppTheme.textMuted, size: 28),
          const SizedBox(width: 12),
          Text(
            'Analysis data not available for this game.',
            style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
