import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:ndef_codec/ndef_codec.dart';

/// Kayıt tipi seçici + basit sihirbaz.
abstract final class RecordTypeSheet {
  /// Seçici sayfayı açar. Kullanıcı vazgeçerse null döner.
  ///
  /// Çoğu sihirbaz tek kayıt döndürür; vCard sihirbazı iPhone uyumluluğu
  /// açıksa vCard + bağlantı kaydından oluşan iki elemanlı liste döndürür.
  static Future<List<NdefContent>?> show(BuildContext context) =>
      Navigator.of(context).push<List<NdefContent>>(
        MaterialPageRoute(builder: (_) => const _RecordTypePage()),
      );

  /// Var olan bir kaydı düzenlemek için uygun editörü açar.
  static Future<NdefContent?> edit(BuildContext context, NdefContent content) {
    switch (content) {
      case TextContent(:final text):
        return Navigator.of(context).push<NdefContent>(
          MaterialPageRoute(
            builder: (_) => _RecordInputPage(
              config: _EditorConfig.text(),
              initialValue: text,
            ),
          ),
        );
      case UriContent(:final uri):
        final launch = _editorForUri(uri);
        return Navigator.of(context).push<NdefContent>(
          MaterialPageRoute(
            builder: (_) => _RecordInputPage(
              config: launch.config,
              initialValue: launch.initialValue,
            ),
          ),
        );
      case VCardContent():
        return Navigator.of(context).push<NdefContent>(
          MaterialPageRoute(builder: (_) => _VCardInputPage(initial: content)),
        );
      case WifiContent():
        return Navigator.of(context).push<NdefContent>(
          MaterialPageRoute(builder: (_) => _WifiInputPage(initial: content)),
        );
      default:
        return Future<NdefContent?>.value(null);
    }
  }

  static _EditorLaunch _editorForUri(String uri) {
    if (uri.startsWith('tel:')) {
      return _EditorLaunch(_EditorConfig.phone(), uri.substring(4));
    }
    if (uri.startsWith('sms:')) {
      return _EditorLaunch(_EditorConfig.sms(), uri.substring(4));
    }
    if (uri.startsWith('mailto:')) {
      return _EditorLaunch(_EditorConfig.email(), uri.substring(7));
    }
    if (uri.startsWith('geo:')) {
      return _EditorLaunch(_EditorConfig.geo(), uri.substring(4));
    }

    const googleReviewSuffix = ' yorum';
    const googleReviewPrefix = 'https://www.google.com/search?q=';
    if (uri.startsWith(googleReviewPrefix) &&
        uri.endsWith(Uri.encodeQueryComponent(googleReviewSuffix))) {
      final query = Uri.decodeQueryComponent(
        uri.substring(googleReviewPrefix.length),
      );
      return _EditorLaunch(
        _EditorConfig.googleReview(),
        query.substring(0, query.length - googleReviewSuffix.length),
      );
    }

    const searchPrefix = 'https://www.google.com/search?q=';
    if (uri.startsWith(searchPrefix)) {
      return _EditorLaunch(
        _EditorConfig.search(),
        Uri.decodeQueryComponent(uri.substring(searchPrefix.length)),
      );
    }

    const mapsPrefix = 'https://maps.google.com/?q=';
    if (uri.startsWith(mapsPrefix)) {
      return _EditorLaunch(
        _EditorConfig.address(),
        Uri.decodeQueryComponent(uri.substring(mapsPrefix.length)),
      );
    }

    const playStorePrefix = 'https://play.google.com/store/apps/details?id=';
    if (uri.startsWith(playStorePrefix)) {
      return _EditorLaunch(
        _EditorConfig.playStore(),
        Uri.decodeQueryComponent(uri.substring(playStorePrefix.length)),
      );
    }

    const instagramPrefix = 'https://instagram.com/';
    if (uri.startsWith(instagramPrefix)) {
      return _EditorLaunch(
        _EditorConfig.instagram(),
        uri.substring(instagramPrefix.length),
      );
    }

    if (uri.startsWith('bitcoin:')) {
      return _EditorLaunch(
        _EditorConfig.bitcoin(),
        uri.substring('bitcoin:'.length),
      );
    }

    if (uri.startsWith('ethereum:')) {
      return _EditorLaunch(
        _EditorConfig.ethereum(),
        uri.substring('ethereum:'.length),
      );
    }

    return _EditorLaunch(_EditorConfig.url(), uri);
  }
}

final class _EditorLaunch {
  const _EditorLaunch(this.config, this.initialValue);

  final _EditorConfig config;
  final String initialValue;
}

class _RecordTypePage extends StatefulWidget {
  const _RecordTypePage();

  @override
  State<_RecordTypePage> createState() => _RecordTypePageState();
}

class _RecordTypePageState extends State<_RecordTypePage> {
  final TextEditingController _searchController = TextEditingController();
  _RecordTypeCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _allOptions(context);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = options
        .where((option) {
          final categoryMatches =
              _selectedCategory == null || option.category == _selectedCategory;
          if (!categoryMatches) return false;
          if (query.isEmpty) return true;

          final haystack =
              '${option.title} ${option.subtitle} ${option.searchTerms.join(' ')}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);

    final grouped = <_RecordTypeCategory, List<_RecordTypeOption>>{};
    for (final option in filtered) {
      grouped
          .putIfAbsent(option.category, () => <_RecordTypeOption>[])
          .add(option);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt tipi seçin')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Kayıt tipi ara (metin, telefon, vCard...)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tüm tipler'),
                  selected: _selectedCategory == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                ..._RecordTypeCategory.values.map((category) {
                  final selected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(category.label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = selected ? null : category;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Aramana uygun kayıt tipi bulunamadı.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    children: _RecordTypeCategory.values
                        .where(grouped.containsKey)
                        .expand((category) {
                          final categoryOptions = grouped[category]!;
                          return [
                            _CategoryHeader(label: category.label),
                            ...categoryOptions.map(
                              (option) => ListTile(
                                leading: Icon(option.icon),
                                title: Text(option.title),
                                subtitle: Text(option.subtitle),
                                onTap: option.onTap,
                              ),
                            ),
                          ];
                        })
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }

  List<_RecordTypeOption> _allOptions(BuildContext context) => [
    _RecordTypeOption(
      category: _RecordTypeCategory.basic,
      icon: Icons.text_fields,
      title: 'Metin',
      subtitle: 'Düz metin kaydı',
      searchTerms: const <String>['text', 'yazi'],
      onTap: () => _openEditor(context, _EditorConfig.text()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.basic,
      icon: Icons.link,
      title: 'Bağlantı / URL',
      subtitle: 'Web adresi, telefon, e-posta',
      searchTerms: const <String>['url', 'link', 'web'],
      onTap: () => _openEditor(context, _EditorConfig.url()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.basic,
      icon: Icons.search,
      title: 'Arama',
      subtitle: 'Google arama bağlantısı oluşturur',
      searchTerms: const <String>['google', 'query', 'arama'],
      onTap: () => _openEditor(context, _EditorConfig.search()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.call_outlined,
      title: 'Telefon',
      subtitle: 'Arama için tel: kaydı',
      searchTerms: const <String>['tel', 'call', 'arama'],
      onTap: () => _openEditor(context, _EditorConfig.phone()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.sms_outlined,
      title: 'SMS',
      subtitle: 'Mesaj için sms: kaydı',
      searchTerms: const <String>['mesaj', 'text'],
      onTap: () => _openEditor(context, _EditorConfig.sms()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.email_outlined,
      title: 'E-posta',
      subtitle: 'Mail için mailto: kaydı',
      searchTerms: const <String>['mail', 'email'],
      onTap: () => _openEditor(context, _EditorConfig.email()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.location,
      icon: Icons.place_outlined,
      title: 'Konum',
      subtitle: 'Harita için geo: kaydı',
      searchTerms: const <String>['geo', 'harita', 'adres'],
      onTap: () => _openEditor(context, _EditorConfig.geo()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.location,
      icon: Icons.map_outlined,
      title: 'Adres',
      subtitle: 'Harita sorgusu olarak açılır',
      searchTerms: const <String>['maps', 'konum', 'adres'],
      onTap: () => _openEditor(context, _EditorConfig.address()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.web,
      icon: Icons.video_collection_outlined,
      title: 'YouTube videosu',
      subtitle: 'Video bağlantısı oluşturur',
      searchTerms: const <String>['youtube', 'video'],
      onTap: () => _openEditor(context, _EditorConfig.youtube()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.web,
      icon: Icons.apps_outlined,
      title: 'Play Store uygulaması',
      subtitle: 'Uygulama sayfasını açar',
      searchTerms: const <String>['play', 'store', 'app'],
      onTap: () => _openEditor(context, _EditorConfig.playStore()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.web,
      icon: Icons.alternate_email,
      title: 'Instagram profili',
      subtitle: 'Kullanıcı adına göre profil bağlantısı',
      searchTerms: const <String>['instagram', 'social', 'profil'],
      onTap: () => _openEditor(context, _EditorConfig.instagram()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.web,
      icon: Icons.rate_review_outlined,
      title: 'Google İşletme Yorumu',
      subtitle: 'İşletmeyi arattırıp yorum ekranını açar',
      searchTerms: const <String>[
        'google',
        'yorum',
        'review',
        'işletme',
        'business',
      ],
      onTap: () => _openEditor(context, _EditorConfig.googleReview()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.payment,
      icon: Icons.currency_bitcoin,
      title: 'Bitcoin ödeme',
      subtitle: 'bitcoin: URI kaydı',
      searchTerms: const <String>['bitcoin', 'btc', 'kripto'],
      onTap: () => _openEditor(context, _EditorConfig.bitcoin()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.payment,
      icon: Icons.token,
      title: 'Ethereum ödeme',
      subtitle: 'ethereum: URI kaydı',
      searchTerms: const <String>['ethereum', 'eth', 'kripto'],
      onTap: () => _openEditor(context, _EditorConfig.ethereum()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.badge_outlined,
      title: 'vCard (Kişi kartı)',
      subtitle: 'Ad, telefon, e-posta, şirket ve daha fazlası',
      searchTerms: const <String>['kartvizit', 'contact', 'vcard'],
      onTap: () => _openVCardEditor(context),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.network,
      icon: Icons.wifi,
      title: 'Wi-Fi ağı',
      subtitle: 'Dokunan telefon ağa bağlanmayı önerir',
      searchTerms: const <String>['wifi', 'wi-fi', 'ag', 'ağ', 'kablosuz'],
      onTap: () => _openWifiEditor(context),
    ),
  ];

  Future<void> _openEditor(BuildContext context, _EditorConfig config) async {
    final content = await Navigator.of(context).push<NdefContent>(
      MaterialPageRoute(builder: (_) => _RecordInputPage(config: config)),
    );
    if (content == null || !context.mounted) return;
    Navigator.of(context).pop(<NdefContent>[content]);
  }

  Future<void> _openVCardEditor(BuildContext context) async {
    final contents = await Navigator.of(context).push<List<NdefContent>>(
      MaterialPageRoute(builder: (_) => const _VCardInputPage()),
    );
    if (contents == null || !context.mounted) return;
    Navigator.of(context).pop(contents);
  }

  Future<void> _openWifiEditor(BuildContext context) async {
    final content = await Navigator.of(context).push<NdefContent>(
      MaterialPageRoute(builder: (_) => const _WifiInputPage()),
    );
    if (content == null || !context.mounted) return;
    Navigator.of(context).pop(<NdefContent>[content]);
  }
}

enum _RecordTypeCategory {
  basic('Temel'),
  contact('İletişim'),
  location('Konum'),
  web('Web ve Uygulama'),
  network('Ağ'),
  payment('Ödeme');

  const _RecordTypeCategory(this.label);
  final String label;
}

final class _RecordTypeOption {
  const _RecordTypeOption({
    required this.category,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.searchTerms,
    required this.onTap,
  });

  final _RecordTypeCategory category;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> searchTerms;
  final VoidCallback onTap;
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _RecordInputPage extends StatefulWidget {
  const _RecordInputPage({required this.config, this.initialValue = ''});

  final _EditorConfig config;
  final String initialValue;

  @override
  State<_RecordInputPage> createState() => _RecordInputPageState();
}

class _RecordInputPageState extends State<_RecordInputPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.config.title)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: widget.config.keyboardType,
              maxLines: widget.config.keyboardType == TextInputType.url ? 1 : 4,
              minLines: 1,
              decoration: InputDecoration(
                labelText: widget.config.label,
                hintText: widget.config.hint,
                prefixIcon: Icon(widget.config.icon),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Ekle'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(widget.config.build(value));
  }
}

/// Wi-Fi agi sihirbazi.
///
/// Uretilen kayit `application/vnd.wfa.wsc` MIME'idir; Android etikete
/// dokunuldugunda aga baglanmayi onerir. iOS yalnizca Kisayollar
/// uzerinden destekler — bu yuzden ekranda kisa bir not var.
class _WifiInputPage extends StatefulWidget {
  const _WifiInputPage({this.initial});

  final WifiContent? initial;

  @override
  State<_WifiInputPage> createState() => _WifiInputPageState();
}

class _WifiInputPageState extends State<_WifiInputPage> {
  late final TextEditingController _ssid;
  late final TextEditingController _password;
  late WifiAuthType _auth;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _ssid = TextEditingController(text: initial?.ssid ?? '');
    _password = TextEditingController(text: initial?.password ?? '');
    _auth = initial?.auth ?? WifiAuthType.wpa2Personal;
  }

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi ağı')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _ssid,
            autofocus: true,
            maxLength: WifiWscCodec.maxSsidBytes,
            decoration: const InputDecoration(
              labelText: 'Ağ adı (SSID)',
              helperText: 'Büyük/küçük harf duyarlıdır',
              prefixIcon: Icon(Icons.wifi),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: AppSpacing.md),

          DropdownButtonFormField<WifiAuthType>(
            initialValue: _auth,
            decoration: const InputDecoration(
              labelText: 'Güvenlik',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
            items: [
              for (final type in WifiAuthType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _auth = value;
                _error = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),

          if (_auth.requiresPassword)
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              maxLength: WifiWscCodec.maxPasswordLength,
              decoration: InputDecoration(
                labelText: 'Parola',
                helperText:
                    'En az ${WifiWscCodec.minPasswordLength} karakter',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
            )
          else
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_open_outlined),
              title: Text('Açık ağ — parola yazılmaz'),
            ),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Parola etikete düz metin olarak yazılır. Etiketi '
                      'okuyan herkes ağ parolasını görebilir.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final ssid = _ssid.text.trim();
    if (ssid.isEmpty) {
      setState(() => _error = 'Ağ adı boş olamaz');
      return;
    }

    final password = _password.text;
    final passwordError = WifiWscCodec.validatePassword(password, _auth);
    if (passwordError != null) {
      setState(() => _error = passwordError);
      return;
    }

    Navigator.of(context).pop(
      WifiContent(
        ssid: ssid,
        password: _auth.requiresPassword ? password : '',
        auth: _auth,
      ),
    );
  }
}

class _VCardInputPage extends StatefulWidget {
  const _VCardInputPage({this.initial});

  final VCardContent? initial;

  @override
  State<_VCardInputPage> createState() => _VCardInputPageState();
}

class _VCardInputPageState extends State<_VCardInputPage> {
  // iOS arka plan NFC okuması MIME vCard kayıtlarını yok sayar; bu anahtar
  // açıkken karta ikinci bir URI kaydı (VCardShareLink) eklenir.
  bool _iphoneCompat = true;

  bool get _isEditing => widget.initial != null;

  late final TextEditingController _fullName;
  late final TextEditingController _givenName;
  late final TextEditingController _familyName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _organization;
  late final TextEditingController _title;
  late final TextEditingController _address;
  late final TextEditingController _url;
  late final TextEditingController _socialUrls;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _fullName = TextEditingController(text: initial?.formattedName ?? '');
    _givenName = TextEditingController(text: initial?.givenName ?? '');
    _familyName = TextEditingController(text: initial?.familyName ?? '');
    _phone = TextEditingController(text: _firstOrNull(initial?.phones) ?? '');
    _email = TextEditingController(text: _firstOrNull(initial?.emails) ?? '');
    _organization = TextEditingController(text: initial?.organization ?? '');
    _title = TextEditingController(text: initial?.title ?? '');
    _address = TextEditingController(text: initial?.address ?? '');
    _url = TextEditingController(text: initial?.url ?? '');
    _socialUrls = TextEditingController(
      text: (initial?.socialUrls ?? const <String>[]).join('\n'),
    );
    _note = TextEditingController(text: initial?.note ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _givenName.dispose();
    _familyName.dispose();
    _phone.dispose();
    _email.dispose();
    _organization.dispose();
    _title.dispose();
    _address.dispose();
    _url.dispose();
    _socialUrls.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('vCard oluştur')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _fullName,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tam ad *',
              hintText: 'Furkan Bademci',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _givenName,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Ad',
              hintText: 'Furkan',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _familyName,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Soyad',
              hintText: 'Bademci',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phone,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              hintText: '+905551112233',
              prefixIcon: Icon(Icons.call_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _email,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              hintText: 'örnek@alan.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _organization,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Şirket',
              hintText: 'NFC Toolkit',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Unvan',
              hintText: 'Mobile Developer',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _address,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Adres',
              hintText: 'İstanbul, Türkiye',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _url,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Web sitesi',
              hintText: 'https://örnek.com',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _socialUrls,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Sosyal medya linkleri',
              hintText:
                  'https://instagram.com/kullanici\nhttps://linkedin.com/in/kullanici',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'Ek bilgi',
            ),
          ),
          if (!_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: SwitchListTile(
                value: _iphoneCompat,
                onChanged: (value) => setState(() => _iphoneCompat = value),
                title: const Text('iPhone uyumluluğu'),
                subtitle: const Text(
                  'iPhone\'lar vCard kaydını arka planda okumaz. Bu seçenek '
                  'karta ek bir bağlantı kaydı yazar; iPhone bağlantıyı açar '
                  've kişi "Kişilere Ekle" olarak sunulur. Kişi verisi kartta '
                  'kalır, sunucuya gönderilmez.',
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('Ekle')),
          ),
        ],
      ),
    ),
  );

  void _submit() {
    final formattedName = _fullName.text.trim();
    if (formattedName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tam ad zorunlu')));
      return;
    }

    final phone = _phone.text.trim();
    final email = _email.text.trim();

    final content = VCardContent(
      formattedName: formattedName,
      givenName: _nullIfBlank(_givenName.text),
      familyName: _nullIfBlank(_familyName.text),
      phones: phone.isEmpty ? const <String>[] : <String>[phone],
      emails: email.isEmpty ? const <String>[] : <String>[email],
      organization: _nullIfBlank(_organization.text),
      title: _nullIfBlank(_title.text),
      address: _nullIfBlank(_address.text),
      url: _nullIfBlank(_url.text),
      socialUrls: _splitLines(_socialUrls.text),
      note: _nullIfBlank(_note.text),
    );

    if (_isEditing) {
      // Düzenleme akışı tek kayıt bekler (route tipi NdefContent).
      Navigator.of(context).pop(content);
      return;
    }

    // Record stacking: Android ilk kaydı (vCard) Kişiler'e açar, iOS
    // desteklemediği vCard'ı atlayıp bağlantı kaydını bildirim yapar.
    Navigator.of(context).pop(<NdefContent>[
      content,
      if (_iphoneCompat) UriContent(VCardShareLink.build(content)),
    ]);
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _firstOrNull(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    return values.first;
  }

  List<String> _splitLines(String value) {
    return value
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}

final class _EditorConfig {
  const _EditorConfig({
    required this.title,
    required this.label,
    required this.icon,
    required this.build,
    this.hint,
    this.keyboardType,
  });

  final String title;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final NdefContent Function(String value) build;

  factory _EditorConfig.text() => _EditorConfig(
    title: 'Metin kaydı',
    label: 'Metin',
    icon: Icons.text_fields,
    build: (value) => TextContent(text: value),
  );

  factory _EditorConfig.url() => const _EditorConfig(
    title: 'Bağlantı kaydı',
    label: 'URL',
    hint: 'https://örnek.com',
    icon: Icons.link,
    keyboardType: TextInputType.url,
    build: UriContent.new,
  );

  factory _EditorConfig.search() => _EditorConfig(
    title: 'Arama kaydı',
    label: 'Arama metni',
    hint: 'nfc toolkit',
    icon: Icons.search,
    build: (value) => UriContent(
      'https://www.google.com/search?q=${Uri.encodeQueryComponent(value)}',
    ),
  );

  factory _EditorConfig.phone() => _EditorConfig(
    title: 'Telefon kaydı',
    label: 'Telefon numarası',
    hint: '+905551112233',
    icon: Icons.call_outlined,
    keyboardType: TextInputType.phone,
    build: (value) => UriContent('tel:$value'),
  );

  factory _EditorConfig.sms() => _EditorConfig(
    title: 'SMS kaydı',
    label: 'Telefon numarası',
    hint: '+905551112233',
    icon: Icons.sms_outlined,
    keyboardType: TextInputType.phone,
    build: (value) => UriContent('sms:$value'),
  );

  factory _EditorConfig.email() => _EditorConfig(
    title: 'E-posta kaydı',
    label: 'E-posta adresi',
    hint: 'örnek@alan.com',
    icon: Icons.email_outlined,
    keyboardType: TextInputType.emailAddress,
    build: (value) => UriContent('mailto:$value'),
  );

  factory _EditorConfig.geo() => _EditorConfig(
    title: 'Konum kaydı',
    label: 'Enlem,Boylam',
    hint: '41.0082,28.9784',
    icon: Icons.place_outlined,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    build: (value) => UriContent('geo:$value'),
  );

  factory _EditorConfig.address() => _EditorConfig(
    title: 'Adres kaydı',
    label: 'Adres veya yer',
    hint: 'Kadıköy İstanbul',
    icon: Icons.map_outlined,
    build: (value) => UriContent(
      'https://maps.google.com/?q=${Uri.encodeQueryComponent(value)}',
    ),
  );

  factory _EditorConfig.youtube() => const _EditorConfig(
    title: 'YouTube videosu',
    label: 'Video URL',
    hint: 'https://www.youtube.com/watch?v=...',
    icon: Icons.video_collection_outlined,
    keyboardType: TextInputType.url,
    build: UriContent.new,
  );

  factory _EditorConfig.playStore() => _EditorConfig(
    title: 'Play Store uygulaması',
    label: 'Paket adı',
    hint: 'com.example.app',
    icon: Icons.apps_outlined,
    build: (value) => UriContent(
      'https://play.google.com/store/apps/details?id=${Uri.encodeQueryComponent(value)}',
    ),
  );

  factory _EditorConfig.instagram() => _EditorConfig(
    title: 'Instagram profili',
    label: 'Kullanıcı adı',
    hint: 'kullanıcıadı',
    icon: Icons.alternate_email,
    build: (value) => UriContent('https://instagram.com/$value'),
  );

  factory _EditorConfig.googleReview() => _EditorConfig(
    title: 'Google İşletme Yorumu',
    label: 'İşletme adı',
    hint: 'Örnek Kafe, Kadıköy',
    icon: Icons.rate_review_outlined,
    build: (value) => UriContent(
      'https://www.google.com/search?q=${Uri.encodeQueryComponent('$value yorum')}',
    ),
  );

  factory _EditorConfig.bitcoin() => _EditorConfig(
    title: 'Bitcoin ödeme kaydı',
    label: 'BTC adresi',
    hint: 'bc1q...',
    icon: Icons.currency_bitcoin,
    build: (value) => UriContent('bitcoin:$value'),
  );

  factory _EditorConfig.ethereum() => _EditorConfig(
    title: 'Ethereum ödeme kaydı',
    label: 'ETH adresi',
    hint: '0x...',
    icon: Icons.token,
    build: (value) => UriContent('ethereum:$value'),
  );
}
