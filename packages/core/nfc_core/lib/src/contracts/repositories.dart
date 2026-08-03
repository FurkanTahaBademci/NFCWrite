import '../entities/app_settings.dart';
import '../entities/storage_entities.dart';
import '../result.dart';

/// Tarama gecmisi deposu.
abstract interface class HistoryRepository {
  /// Yeni bir tarama kaydeder ve kimligiyle birlikte dondurur.
  Future<Result<ScanRecord>> add(ScanRecord record);

  /// Filtreye uyan kayitlari dondurur (yeniden eskiye).
  Future<Result<List<ScanRecord>>> query(HistoryQuery query);

  /// Tek kayit getirir. Yoksa `Ok(null)`.
  Future<Result<ScanRecord?>> findById(int id);

  /// Bir UID'ye ait en son kaydi getirir.
  Future<Result<ScanRecord?>> findLatestByUid(String uidHex);

  /// Takma ad atar. Ayni UID'li tum kayitlari gunceller.
  Future<Result<void>> setAlias({required String uidHex, String? alias});

  Future<Result<void>> delete(int id);

  Future<Result<void>> deleteMany(List<int> ids);

  Future<Result<void>> clear();

  /// Toplam kayit sayisi.
  Future<Result<int>> count();

  /// Gecmis degistikce yayin yapar — liste ekrani bunu dinler.
  Stream<void> get changes;
}

/// Bellek dokumu arsivi.
abstract interface class DumpRepository {
  Future<Result<TagDump>> add(TagDump dump);

  Future<Result<List<TagDump>>> listAll({String? uidHex, int limit = 100});

  Future<Result<TagDump?>> findById(int id);

  Future<Result<void>> rename({required int id, required String label});

  Future<Result<void>> delete(int id);

  Future<Result<void>> clear();

  /// Dokumu dosyaya yazar ve dosya yolunu dondurur.
  ///
  /// [asBinary] true ise ham `.bin`, false ise ust veriyle birlikte `.json`.
  Future<Result<String>> exportToFile(int id, {bool asBinary = false});

  /// Dosyadan dokum ice aktarir.
  Future<Result<TagDump>> importFromFile(String path);

  Stream<void> get changes;
}

/// Yazma sablonlari deposu.
abstract interface class TemplateRepository {
  Future<Result<WriteTemplate>> add(WriteTemplate template);

  Future<Result<List<WriteTemplate>>> listAll();

  Future<Result<WriteTemplate?>> findById(int id);

  Future<Result<void>> update(WriteTemplate template);

  /// Kullanim sayacini bir artirir.
  Future<Result<void>> markUsed(int id);

  Future<Result<void>> delete(int id);

  Stream<void> get changes;
}

/// Uygulama ayarlari deposu.
abstract interface class SettingsRepository {
  /// Su anki ayarlar. Senkron erisim icin baslangicta yuklenir.
  AppSettings get current;

  /// Ayarlari diskten yukler. Uygulama acilisinda bir kez cagrilir.
  Future<Result<AppSettings>> load();

  /// Ayarlari kaydeder.
  Future<Result<void>> save(AppSettings settings);

  /// Ayarlar degistikce yayin yapar.
  Stream<AppSettings> get changes;
}
