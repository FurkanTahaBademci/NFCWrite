import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Araçların gruplandığı kategori.
enum ToolCategory { safe, content, configuration, irreversible }

/// Bir aracın tanımı.
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

  /// Kararlı anahtar — rota parametresi ve kayıt tutmada kullanılır.
  final String id;

  final String title;
  final String description;
  final IconData icon;
  final ToolCategory category;
  final RiskLevel risk;

  /// `.claude/tracks/T4-tools.md` içindeki görev kodu.
  final String taskId;

  /// Uygulandı mı? false ise arayüzde "yakında" olarak gösterilir.
  final bool implemented;

  /// Uzman modu kapalıyken gizlensin mi?
  final bool expertOnly;
}

/// Uygulamadaki tüm araçlar.
///
/// **Tek doğruluk kaynağı.** Yeni araç buraya eklenir; ızgara ve rotalar
/// otomatik olarak güncellenir.
abstract final class ToolCatalog {
  static const List<ToolDefinition> all = [
    // --- Güvenli ---
    ToolDefinition(
      id: 'memory_dump',
      title: 'Bellek dökümü',
      description: 'Etiketin tüm belleğini oku ve kaydet',
      icon: Icons.download_outlined,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.9',
      implemented: true,
    ),
    ToolDefinition(
      id: 'read_counter',
      title: 'Sayaç oku',
      description: 'NFC okuma sayacını göster',
      icon: Icons.numbers,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.11',
      implemented: true,
    ),
    ToolDefinition(
      id: 'verify_signature',
      title: 'Orijinallik doğrula',
      description: 'ECC imzasını üreticinin anahtarıyla doğrula',
      icon: Icons.verified_outlined,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.12',
    ),

    // --- İçerik ---
    ToolDefinition(
      id: 'copy_tag',
      title: 'Etiketi kopyala',
      description: 'Bir etiketi okuyup diğerine yaz',
      icon: Icons.copy_all_outlined,
      category: ToolCategory.content,
      risk: RiskLevel.caution,
      taskId: 'T4.15',
      implemented: true,
    ),
    ToolDefinition(
      id: 'erase_tag',
      title: 'Etiketi temizle',
      description: 'NDEF içeriğini sil',
      icon: Icons.cleaning_services_outlined,
      category: ToolCategory.content,
      risk: RiskLevel.caution,
      taskId: 'T4.14',
      implemented: true,
    ),
    ToolDefinition(
      id: 'factory_reset',
      title: 'Fabrika sıfırlama',
      description: 'Tüm kullanıcı sayfalarını sıfırla',
      icon: Icons.restart_alt,
      category: ToolCategory.content,
      risk: RiskLevel.warning,
      taskId: 'T4.16',
      implemented: true,
    ),
    ToolDefinition(
      id: 'restore_dump',
      title: 'Dökümü geri yükle',
      description: 'Kaydedilmiş bir dökümü etikete yaz',
      icon: Icons.restore,
      category: ToolCategory.content,
      risk: RiskLevel.warning,
      taskId: 'T4.17',
      implemented: true,
    ),

    // --- Yapılandırma ---
    ToolDefinition(
      id: 'format_tag',
      title: 'Biçimlendir',
      description: 'Etiketi NDEF olarak biçimlendir',
      icon: Icons.auto_fix_high_outlined,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.19',
      implemented: true,
    ),
    ToolDefinition(
      id: 'set_password',
      title: 'Şifre koy',
      description: 'Etiketi şifre ile koru',
      icon: Icons.password,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.21',
      implemented: true,
    ),
    ToolDefinition(
      id: 'remove_password',
      title: 'Şifre kaldır',
      description: 'Mevcut şifre korumasını kaldır',
      icon: Icons.lock_open_outlined,
      category: ToolCategory.configuration,
      risk: RiskLevel.caution,
      taskId: 'T4.22',
      implemented: true,
    ),
    ToolDefinition(
      id: 'configure_mirror',
      title: 'UID yansıtma',
      description: 'UID / sayacı NDEF içine yansıt',
      icon: Icons.flip_to_front,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.25',
      implemented: true,
    ),
    ToolDefinition(
      id: 'configure_counter',
      title: 'Sayaç ayarla',
      description: 'NFC okuma sayacını aç / kapat',
      icon: Icons.speed,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.26',
      implemented: true,
    ),

    // --- Geri alınamaz ---
    ToolDefinition(
      id: 'make_read_only',
      title: 'Salt-okunur yap',
      description: 'Etiketi kalıcı olarak yazmaya kapat',
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
      description: 'Seçili sayfaları kalıcı olarak kilitle',
      icon: Icons.grid_off,
      category: ToolCategory.irreversible,
      risk: RiskLevel.danger,
      taskId: 'T4.28',
      expertOnly: true,
    ),
    ToolDefinition(
      id: 'lock_configuration',
      title: 'Yapılandırmayı dondur',
      description: 'CFGLCK — ayarlar bir daha değiştirilemez',
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
      description: 'Etikete doğrudan hex komut gönder',
      icon: Icons.terminal,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.31',
      implemented: true,
      expertOnly: true,
    ),
    ToolDefinition(
      id: 'mifare_keys',
      title: 'MIFARE anahtar taraması',
      description: 'Bilinen anahtarlarla sektörleri dene',
      icon: Icons.vpn_key_outlined,
      category: ToolCategory.safe,
      risk: RiskLevel.safe,
      taskId: 'T4.32',
      implemented: true,
      expertOnly: true,
    ),
    ToolDefinition(
      id: 'mifare_clone',
      title: 'Magic kart klonla',
      description: 'Bir MIFARE Classic kartı magic karta kopyala (blok 0 dahil)',
      icon: Icons.content_copy,
      category: ToolCategory.content,
      risk: RiskLevel.warning,
      taskId: 'T4.18',
      implemented: true,
      expertOnly: true,
    ),
    ToolDefinition(
      id: 'mifare_write_block',
      title: 'Sektör 0 / blok yaz',
      description: 'Tek bir MIFARE Classic bloğunu yaz (UID/blok 0 dahil)',
      icon: Icons.edit_note,
      category: ToolCategory.configuration,
      risk: RiskLevel.warning,
      taskId: 'T4.33',
      implemented: true,
      expertOnly: true,
    ),
  ];

  /// Kategoriye göre araçları döndürür.
  static List<ToolDefinition> byCategory(
    ToolCategory category, {
    required bool expertMode,
  }) => all
      .where(
        (tool) => tool.category == category && (expertMode || !tool.expertOnly),
      )
      .toList(growable: false);

  /// Id ile araç bulur.
  static ToolDefinition? byId(String id) {
    for (final tool in all) {
      if (tool.id == id) return tool;
    }
    return null;
  }
}
