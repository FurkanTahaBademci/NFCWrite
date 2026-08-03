import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Araclarin gruplandigi kategori.
enum ToolCategory { safe, content, configuration, irreversible }

/// Bir aracin tanimi.
///
/// Yeni arac eklerken `.claude/templates/new_tool.md` sablonunu izle.
@immutable
final class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.risk,
    required this.taskId,
    this.implemented = false,
    this.expertOnly = false,
  });

  /// Kararli anahtar — rota parametresi ve kayit tutmada kullanilir.
  final String id;

  final String title;
  final String description;
  final IconData icon;
  final ToolCategory category;
  final RiskLevel risk;

  /// `.claude/tracks/T4-tools.md` icindeki gorev kodu.
  final String taskId;

  /// Uygulandi mi? false ise arayuzde "yakinda" olarak gosterilir.
  final bool implemented;

  /// Uzman modu kapaliyken gizlensin mi?
  final bool expertOnly;
}

/// Uygulamadaki tum araclar.
///
/// **Tek dogruluk kaynagi.** Yeni arac buraya eklenir; izgara ve rotalar
/// otomatik olarak gunceller.
abstract final class ToolCatalog {
  static const List<ToolDefinition> all = [
    // --- Guvenli ---
    ToolDefinition(
      id: 'memory_dump',
      title: 'Bellek dokumu',
      description: 'Etiketin tum bellegini oku ve kaydet',
      icon: Icons.download_outlined,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.9',
    ),
    ToolDefinition(
      id: 'read_counter',
      title: 'Sayac oku',
      description: 'NFC okuma sayacini goster',
      icon: Icons.numbers,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.11',
    ),
    ToolDefinition(
      id: 'verify_signature',
      title: 'Orijinallik dogrula',
      description: 'ECC imzasini ureticinin anahtariyla dogrula',
      icon: Icons.verified_outlined,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.12',
    ),

    // --- Icerik ---
    ToolDefinition(
      id: 'copy_tag',
      title: 'Etiketi kopyala',
      description: 'Bir etiketi okuyup digerine yaz',
      icon: Icons.copy_all_outlined,
      category: ToolCategory.content,
      risk: RiskLevel.caution,
      taskId: 'T4.15',
    ),
    ToolDefinition(
      id: 'erase_tag',
      title: 'Etiketi temizle',
      description: 'NDEF icerigini sil',
      icon: Icons.cleaning_services_outlined,
      category: ToolCategory.content,
      risk: RiskLevel.caution,
      taskId: 'T4.14',
      implemented: true,
    ),
    ToolDefinition(
      id: 'factory_reset',
      title: 'Fabrika sifirlama',
      description: 'Tum kullanici sayfalarini sifirla',
      icon: Icons.restart_alt,
      category: ToolCategory.content,
      risk: RiskLevel.warning,
      taskId: 'T4.16',
    ),
    ToolDefinition(
      id: 'restore_dump',
      title: 'Dokumu geri yukle',
      description: 'Kaydedilmis bir dokumu etikete yaz',
      icon: Icons.restore,
      category: ToolCategory.content,
      risk: RiskLevel.warning,
      taskId: 'T4.17',
    ),

    // --- Yapilandirma ---
    ToolDefinition(
      id: 'format_tag',
      title: 'Bicimlendir',
      description: 'Etiketi NDEF olarak bicimlendir',
      icon: Icons.auto_fix_high_outlined,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.19',
    ),
    ToolDefinition(
      id: 'set_password',
      title: 'Sifre koy',
      description: 'Etiketi sifre ile koru',
      icon: Icons.password,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.21',
    ),
    ToolDefinition(
      id: 'remove_password',
      title: 'Sifre kaldir',
      description: 'Mevcut sifre korumasini kaldir',
      icon: Icons.lock_open_outlined,
      category: ToolCategory.configuration,
      risk: RiskLevel.caution,
      taskId: 'T4.22',
    ),
    ToolDefinition(
      id: 'configure_mirror',
      title: 'UID yansitma',
      description: 'UID / sayaci NDEF icine yansit',
      icon: Icons.flip_to_front,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.25',
    ),
    ToolDefinition(
      id: 'configure_counter',
      title: 'Sayac ayarla',
      description: 'NFC okuma sayacini ac / kapat',
      icon: Icons.speed,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.26',
    ),

    // --- Geri alinamaz ---
    ToolDefinition(
      id: 'make_read_only',
      title: 'Salt-okunur yap',
      description: 'Etiketi kalici olarak yazmaya kapat',
      icon: Icons.lock_outline,
      category: ToolCategory.irreversible,
      risk: RiskLevel.danger,
      taskId: 'T4.27',
      implemented: true,
      expertOnly: true,
    ),
    ToolDefinition(
      id: 'lock_pages',
      title: 'Sayfa kilitle',
      description: 'Secili sayfalari kalici olarak kilitle',
      icon: Icons.grid_off,
      category: ToolCategory.irreversible,
      risk: RiskLevel.danger,
      taskId: 'T4.28',
      expertOnly: true,
    ),
    ToolDefinition(
      id: 'lock_configuration',
      title: 'Yapilandirmayi dondur',
      description: 'CFGLCK — ayarlar bir daha degistirilemez',
      icon: Icons.ac_unit,
      category: ToolCategory.irreversible,
      risk: RiskLevel.danger,
      taskId: 'T4.30',
      expertOnly: true,
    ),

    // --- Uzman ---
    ToolDefinition(
      id: 'raw_console',
      title: 'Ham komut konsolu',
      description: 'Etikete dogrudan hex komut gonder',
      icon: Icons.terminal,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.31',
      implemented: true,
      expertOnly: true,
    ),
    ToolDefinition(
      id: 'mifare_keys',
      title: 'MIFARE anahtar taramasi',
      description: 'Bilinen anahtarlarla sektorleri dene',
      icon: Icons.vpn_key_outlined,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.32',
      expertOnly: true,
    ),
  ];

  /// Kategoriye gore araclari dondurur.
  static List<ToolDefinition> byCategory(
    ToolCategory category, {
    required bool expertMode,
  }) => all
      .where(
        (tool) => tool.category == category && (expertMode || !tool.expertOnly),
      )
      .toList(growable: false);

  /// Id ile arac bulur.
  static ToolDefinition? byId(String id) {
    for (final tool in all) {
      if (tool.id == id) return tool;
    }
    return null;
  }
}
