// lib/features/templates/template_picker_screen.dart
import 'package:flutter/material.dart';
import '../processing/processing_screen.dart';
import '../history/history_list_screen.dart';

class TemplateSpec {
  final String key; // 'fish' | 'pencil' | 'icecream'
  final String title; // ชื่อไทยโชว์บนการ์ด
  final String templateAssetPath; // ภาพตัวอย่าง (ถ้ามี)
  const TemplateSpec({
    required this.key,
    required this.title,
    required this.templateAssetPath,
  });
}

const kTemplates = <TemplateSpec>[
  TemplateSpec(
    key: 'fish',
    title: 'ปลา',
    templateAssetPath: 'assets/templates/fish.png',
  ),
  TemplateSpec(
    key: 'pencil',
    title: 'ดินสอ',
    templateAssetPath: 'assets/templates/pencil.png',
  ),
  TemplateSpec(
    key: 'icecream',
    title: 'ไอศกรีม',
    templateAssetPath: 'assets/templates/template_icecream.png',
  ),
];

class TemplatePickerScreen extends StatefulWidget {
  const TemplatePickerScreen({super.key});

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> {
  String? _selectedKey;

  String _extractProfileKey(Map<String, dynamic>? p) {
    final k = p?['key'] ?? p?['id'] ?? p?['profileKey'] ?? p?['name'] ?? '';
    return k.toString();
  }

  void _onSelect(String key) => setState(() => _selectedKey = key);

  String _titleForKey(String key) {
    final hit = kTemplates.where((e) => e.key == key);
    if (hit.isNotEmpty) return hit.first.title;
    switch (key) {
      case 'fish':
        return 'ปลา';
      case 'pencil':
        return 'ดินสอ';
      case 'icecream':
        return 'ไอศกรีม';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final profile = (args?['profile'] as Map?)?.cast<String, dynamic>();
    final profileKey = _extractProfileKey(profile);

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface.withOpacity(0.98),

      // ---------- AppBar (สองชั้น: บน=title/ปุ่ม, ล่าง=chip โปรไฟล์ + subtitle) ----------
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        centerTitle: false,
        toolbarHeight: 56,
        title: Text(
          'เลือกเทมเพลต',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'ดูประวัติการประเมิน',
            onPressed: () {
              if (profileKey.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ยังไม่มีโปรไฟล์/คีย์โปรไฟล์')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryListScreen(profileKey: profileKey),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(profileKey.isNotEmpty ? 64 : 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profileKey.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        InputChip(
                          avatar: const Icon(Icons.badge_outlined, size: 18),
                          label: Text(
                            'โปรไฟล์: $profileKey',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: null, // แสดงอย่างเดียว
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'แตะเพื่อเลือก 1 แบบสำหรับการประเมิน',
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ---------- Body ----------
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        child: GridView.builder(
          itemCount: kTemplates.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.80,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, i) {
            final t = kTemplates[i];
            final isSel = t.key == _selectedKey;
            return _TemplateCard(
              spec: t,
              selected: isSel,
              onTap: () => _onSelect(t.key),
            );
          },
        ),
      ),

      // ---------- Bottom Button ----------
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: _PrimaryButton(
          enabled: (_selectedKey ?? '').isNotEmpty,
          icon: Icons.photo_camera_back_outlined,
          label: (_selectedKey ?? '').isEmpty
              ? 'ไปเลือก/ถ่ายรูป'
              : 'ไปเลือก/ถ่ายรูป – ${_titleForKey(_selectedKey!)}',
          onPressed: () {
            final key = _selectedKey!;
            final title = _titleForKey(key);
            final maskPath = 'assets/masks/${key}_mask.png';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProcessingScreen(
                  maskAssetPath: maskPath,
                  templateName: title,
                ),
                settings: RouteSettings(
                  arguments: {'profile': profile, 'template': key},
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ======= การ์ดเทมเพลต (gradient + เงานุ่ม + ติ๊กมุม) =======
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final TemplateSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final borderColor = selected ? cs.primary : cs.outlineVariant;
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: selected
          ? [
              cs.primaryContainer.withOpacity(0.55),
              cs.surfaceContainerHighest.withOpacity(0.65),
            ]
          : [
              cs.surfaceContainerLowest,
              cs.surfaceContainerHighest.withOpacity(0.45),
            ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: bgGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(selected ? 0.18 : 0.08),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ภาพตัวอย่าง (ขอบมน + พื้นขาว + ขอบบาง)
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      spec.templateAssetPath,
                      fit: BoxFit.contain,
                      width: 130,
                      height: 100,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        size: 44,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ชื่อเทมเพลต (หนา + กึ่งกลาง)
                Text(
                  spec.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // pill รอง (ดูสะอาด)
                Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12.withOpacity(0.3)),
                  ),
                  child: Text(
                    spec.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const Spacer(),
              ],
            ),

            // ติ๊กแสดงสถานะเลือก (มุมขวาบน)
            Positioned(
              right: 0,
              top: 0,
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ปุ่มหลัก (รองรับ disabled + สไตล์กลมมน + ยกนูนเล็กน้อย)
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final btn = ElevatedButton.icon(
      icon: Icon(icon),
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        elevation: enabled ? 2 : 0,
        shadowColor: cs.primary.withOpacity(0.25),
        backgroundColor: enabled ? cs.primary : cs.surfaceVariant,
        foregroundColor: enabled
            ? cs.onPrimary
            : cs.onSurface.withOpacity(0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
        overflow: TextOverflow.ellipsis,
      ),
    );

    // กรอบ gradient อ่อน ๆ เมื่อ enabled ให้ดูพรีเมียม
    if (!enabled) return btn;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.18), cs.primary.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: btn,
    );
  }
}
