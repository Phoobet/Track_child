// lib/features/history/history_chart_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/models/history_record.dart';
import '../../data/repositories/history_repo.dart';

class HistoryChartScreen extends StatefulWidget {
  const HistoryChartScreen({super.key, required this.profileKey});
  final String profileKey;

  @override
  State<HistoryChartScreen> createState() => _HistoryChartScreenState();
}

class _HistoryChartScreenState extends State<HistoryChartScreen> {
  late Future<List<HistoryRecord>> _future;
  String _tpl = 'all'; // all | fish | pencil | icecream

  @override
  void initState() {
    super.initState();
    _future = HistoryRepo.I.listByProfile(widget.profileKey);
  }

  // ---------- helpers ----------
  String _tplTh(String k) {
    switch (k) {
      case 'fish':
        return 'ปลา';
      case 'pencil':
        return 'ดินสอ';
      case 'icecream':
        return 'ไอศกรีม';
      default:
        return k;
    }
  }

  List<HistoryRecord> _filterAndSort(List<HistoryRecord> all) {
    final list =
        all
            .where(
              (e) => _tpl == 'all'
                  ? true
                  : e.templateKey.toLowerCase().contains(_tpl),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // เก่า→ใหม่
    return list;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('กราฟดัชนี (Index)')),
      body: SafeArea(
        child: FutureBuilder<List<HistoryRecord>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data ?? [];
            final items = _filterAndSort(all);

            // header: ตัวกรอง + ค่า diff ล่าสุด
            final latest = items.isNotEmpty ? items.last.zSum : 0.0;
            final prev = items.length > 1 ? items[items.length - 2].zSum : 0.0;
            final diff = latest - prev;

            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                // ===== แถวชิปแบบเลื่อนแนวนอน + ป้าย diff =====
                Row(
                  children: [
                    // ชิปเลื่อนแนวนอน
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            _TplChip(
                              label: 'ทั้งหมด',
                              selected: _tpl == 'all',
                              onTap: () => setState(() => _tpl = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _TplChip(
                              label: _tplTh('fish'),
                              selected: _tpl == 'fish',
                              onTap: () => setState(() => _tpl = 'fish'),
                            ),
                            const SizedBox(width: 8),
                            _TplChip(
                              label: _tplTh('pencil'),
                              selected: _tpl == 'pencil',
                              onTap: () => setState(() => _tpl = 'pencil'),
                            ),
                            const SizedBox(width: 8),
                            _TplChip(
                              label: _tplTh('icecream'),
                              selected: _tpl == 'icecream',
                              onTap: () => setState(() => _tpl = 'icecream'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ป้าย diff ย่อได้ ป้องกัน overflow
                    Flexible(
                      flex: 0,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _DiffPill(value: diff),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // การ์ดกราฟ
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('ยังไม่มีข้อมูลในเทมเพลตนี้'),
                          ),
                        )
                      : _IndexBarChartWithThumbnails(items: items),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// Widget กราฟแท่ง + “รูป thumbnail ใต้แท่ง”
// ================================================================
class _IndexBarChartWithThumbnails extends StatelessWidget {
  const _IndexBarChartWithThumbnails({required this.items});
  final List<HistoryRecord> items;

  int _thumbStep() {
    // อยากได้รูปไม่เกิน ~10 รูปต่อจอ
    final step = (items.length / 10).ceil();
    return step.clamp(1, 6);
  }

  List<BarChartGroupData> _groups() {
    final gs = <BarChartGroupData>[];
    for (int i = 0; i < items.length; i++) {
      final cur = items[i].zSum;
      final prev = i > 0 ? items[i - 1].zSum : 0.0;
      gs.add(
        BarChartGroupData(
          x: i,
          barsSpace: 10,
          barRods: [
            BarChartRodData(
              toY: prev,
              width: 10,
              color: const Color(0xFFB8AEEA),
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: cur,
              width: 10,
              color: const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    return gs;
  }

  ({double minY, double maxY}) _range() {
    double lo = 0, hi = 0;
    for (int i = 0; i < items.length; i++) {
      final c = items[i].zSum;
      final p = i > 0 ? items[i - 1].zSum : 0.0;
      if (i == 0) lo = hi = c;
      lo = [lo, c, p].reduce((a, b) => a < b ? a : b);
      hi = [hi, c, p].reduce((a, b) => a > b ? a : b);
    }
    final pad = (hi - lo).abs() * 0.15 + 1.0;
    return (minY: lo - pad, maxY: hi + pad);
  }

  @override
  Widget build(BuildContext context) {
    final r = _range();
    final cs = Theme.of(context).colorScheme;
    final step = _thumbStep();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // กันล้นขอบล่าง
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // legend
          Row(
            children: [
              _legendDot(const Color(0xFF7C4DFF)),
              const SizedBox(width: 6),
              const Text('ล่าสุด'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFFB8AEEA)),
              const SizedBox(width: 6),
              const Text('ก่อนหน้า'),
              const Spacer(),
              Text(
                'ล่าสุด: ${items.last.zSum.toStringAsFixed(3)}   '
                'ก่อนหน้า: ${items.length > 1 ? items[items.length - 2].zSum.toStringAsFixed(3) : "-"}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ทำให้เลื่อนแนวนอนได้
          LayoutBuilder(
            builder: (context, c) {
              // ความกว้างขั้นต่ำต่อกลุ่ม ~48px ป้องกัน RIGHT overflow
              final targetWidth = (items.length * 48).toDouble();
              final chartWidth = targetWidth < c.maxWidth
                  ? c.maxWidth
                  : targetWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: BarChart(
                      BarChartData(
                        minY: r.minY,
                        maxY: r.maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: (r.maxY - r.minY) / 6,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: cs.outlineVariant.withOpacity(.5),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, meta) => Text(
                                v.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              // เผื่อที่ให้รูป + วันที่ + textScale สูง
                              reservedSize: 64,
                              getTitlesWidget: (val, meta) {
                                final i = val.toInt();
                                if (i < 0 || i >= items.length) {
                                  return const SizedBox.shrink();
                                }
                                final rec = items[i];
                                final dt =
                                    '${rec.createdAt.month}/${rec.createdAt.day}';
                                final p = rec.imagePath;
                                final has =
                                    p != null &&
                                    p.isNotEmpty &&
                                    File(p).existsSync();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: has
                                              ? Image.file(
                                                  File(p!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _imgPh(),
                                                )
                                              : _imgPh(),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dt,
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        barGroups: _groups(),

                        // แตะแท่ง เพื่อดูรูปใหญ่ + รายละเอียด
                        barTouchData: BarTouchData(
                          enabled: true,
                          handleBuiltInTouches: false,
                          touchCallback: (event, resp) {
                            if (!event.isInterestedForInteractions ||
                                resp == null)
                              return;
                            final i = resp.spot?.touchedBarGroupIndex ?? -1;
                            if (i < 0 || i >= items.length) return;
                            final rec = items[i];
                            showModalBottomSheet(
                              context: context,
                              showDragHandle: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (_) => _PreviewSheet(rec: rec),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
  );

  Widget _imgPh() => Container(
    color: const Color(0xFFF2F2F2),
    child: const Icon(Icons.image_not_supported_outlined, size: 12),
  );
}

// ---------- ป้าย Diff ย่อได้ เพื่อกัน overflow ----------
class _DiffPill extends StatelessWidget {
  const _DiffPill({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: up ? const Color(0xFFE9FFE8) : const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        (up ? '▲ ' : '▼ ') + value.toStringAsFixed(2),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: up ? const Color(0xFF1B8A3A) : const Color(0xFFB3261E),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------- แผ่นล่างแสดงรูปใหญ่ + ค่ารายละเอียด ----------
class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.rec});
  final HistoryRecord rec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded),
              const SizedBox(width: 8),
              Text(
                'รายละเอียดดัชนี',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Index ${rec.zSum.toStringAsFixed(3)}',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rec.imagePath != null && File(rec.imagePath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(rec.imagePath!),
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'วันที่: ${rec.createdAt}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'H=${rec.h.toStringAsFixed(3)}   '
            'C=${rec.c.toStringAsFixed(3)}   '
            'Blank=${rec.blank.toStringAsFixed(3)}   '
            'COTL=${rec.cotl.toStringAsFixed(3)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------- small chip ----------
class _TplChip extends StatelessWidget {
  const _TplChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: cs.secondaryContainer,
      side: BorderSide(color: cs.outlineVariant),
      labelStyle: TextStyle(
        color: selected ? cs.onSecondaryContainer : cs.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
