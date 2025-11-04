// lib/data/repositories/history_repo.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

import '../models/history_record.dart';

class HistoryRepo {
  HistoryRepo._();
  static final HistoryRepo I = HistoryRepo._();

  /// ที่เก็บหลัก: <app-docs>/histories/
  Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/histories');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// โฟลเดอร์ของโปรไฟล์: <base>/<profileKey>/
  Future<Directory> _ensureProfileDir(String profileKey) async {
    final key = (profileKey.trim().isEmpty) ? 'anonymous' : profileKey.trim();
    final base = await _baseDir();
    final dir = Directory('${base.path}/$key');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// บันทึกภาพตัวอย่าง (PNG) แล้วคืน path
  Future<String> saveImageBytes(
    Uint8List bytes, {
    required String profileKey,
  }) async {
    final dir = await _ensureProfileDir(profileKey);
    final filename = 'preview_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// NEW: แทนที่ NaN/Infinity → 0.0 ใน Map ก่อนเขียนไฟล์
  Map<String, dynamic> _sanitize(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v is double) {
        out[k] = (v.isNaN || v.isInfinite) ? 0.0 : v;
      } else if (v is Map) {
        out[k] = _sanitize(v.cast<String, dynamic>());
      } else if (v is List) {
        out[k] = v.map((e) {
          if (e is double) return (e.isNaN || e.isInfinite) ? 0.0 : e;
          if (e is Map) return _sanitize(e.cast<String, dynamic>());
          return e;
        }).toList();
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  /// เพิ่มประวัติ (เขียนเป็นไฟล์ .json ชื่อ = id)
  Future<void> add(String profileKey, HistoryRecord record) async {
    final dir = await _ensureProfileDir(profileKey);
    final file = File('${dir.path}/${record.id}.json');

    final map = record.toMap();
    map['profileKey'] = record.profileKey.isNotEmpty
        ? record.profileKey
        : profileKey;

    final safeMap = _sanitize(map);
    final jsonText = const JsonEncoder.withIndent('  ').convert(safeMap);
    await file.writeAsString(jsonText, flush: true);
  }

  /// อ่านรายการของโปรไฟล์ทั้งหมด (ล่าสุดมาก่อน)
  Future<List<HistoryRecord>> listByProfile(String profileKey) async {
    final dir = await _ensureProfileDir(profileKey);
    if (!await dir.exists()) return <HistoryRecord>[];

    final files = dir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();

    final list = <HistoryRecord>[];
    for (final f in files) {
      try {
        final text = await f.readAsString();
        final map = jsonDecode(text) as Map<String, dynamic>;
        list.add(HistoryRecord.fromMap(map));
      } catch (_) {
        // ข้ามไฟล์เสีย/อ่านไม่ได้
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// ลบประวัติทั้งหมดของโปรไฟล์ (รวมรูป)
  Future<void> clearByProfile(String profileKey) async {
    final dir = await _ensureProfileDir(profileKey);
    if (await dir.exists()) {
      for (final f in dir.listSync(followLinks: false)) {
        try {
          if (f is File) await f.delete();
        } catch (_) {}
      }
    }
  }

  /// ลบทีละรายการ
  Future<bool> deleteRecord(String profileKey, String recordId) async {
    final dir = await _ensureProfileDir(profileKey);
    final file = File('${dir.path}/$recordId.json');
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// (Debug) คืน path โฟลเดอร์ของโปรไฟล์ไว้ print ตรวจสอบ
  Future<String> debugProfileDirPath(String profileKey) async {
    final d = await _ensureProfileDir(profileKey);
    return d.path;
  }
}
