import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:ndef_codec/ndef_codec.dart';

/// Kayit tipi secici + basit sihirbaz.
///
/// **Iskelet.** Su an yalnizca metin ve baglanti kaydi olusturulabiliyor.
/// 26 kayit tipinin tamami ve kategorili/aranabilir secici T3'un isi:
/// `.claude/tracks/T3-write.md` gorev T3.35 ve T3.36.
abstract final class RecordTypeSheet {
  /// Secici sayfayi acar. Kullanici vazgecerse null doner.
  static Future<NdefContent?> show(BuildContext context) =>
      Navigator.of(context).push<NdefContent>(
        MaterialPageRoute(builder: (_) => const _RecordTypePage()),
      );
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
    final filtered = options.where((option) {
      final categoryMatches =
          _selectedCategory == null || option.category == _selectedCategory;
      if (!categoryMatches) return false;
      if (query.isEmpty) return true;

      final haystack =
          '${option.title} ${option.subtitle} ${option.searchTerms.join(' ')}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);

    final grouped = <_RecordTypeCategory, List<_RecordTypeOption>>{};
    for (final option in filtered) {
      grouped.putIfAbsent(option.category, () => <_RecordTypeOption>[]).add(
        option,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kayit tipi secin')),
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
                hintText: 'Kayit tipi ara (metin, telefon, vcard...)',
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
                  label: const Text('Tum tipler'),
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
                        'Aramana uygun kayit tipi bulunamadi.',
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
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(
              'Diger kayit tipleri (WiFi, Bluetooth, uygulama…) '
              'T3 is kolunda ekleniyor.',
              textAlign: TextAlign.center,
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
      subtitle: 'Duz metin kaydi',
      searchTerms: const <String>['text', 'yazi'],
      onTap: () => _openEditor(context, _EditorConfig.text()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.basic,
      icon: Icons.link,
      title: 'Baglanti / URL',
      subtitle: 'Web adresi, telefon, e-posta',
      searchTerms: const <String>['url', 'link', 'web'],
      onTap: () => _openEditor(context, _EditorConfig.url()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.call_outlined,
      title: 'Telefon',
      subtitle: 'Arama icin tel: kaydi',
      searchTerms: const <String>['tel', 'call', 'arama'],
      onTap: () => _openEditor(context, _EditorConfig.phone()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.sms_outlined,
      title: 'SMS',
      subtitle: 'Mesaj icin sms: kaydi',
      searchTerms: const <String>['mesaj', 'text'],
      onTap: () => _openEditor(context, _EditorConfig.sms()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.email_outlined,
      title: 'E-posta',
      subtitle: 'Mail icin mailto: kaydi',
      searchTerms: const <String>['mail', 'email'],
      onTap: () => _openEditor(context, _EditorConfig.email()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.location,
      icon: Icons.place_outlined,
      title: 'Konum',
      subtitle: 'Harita icin geo: kaydi',
      searchTerms: const <String>['geo', 'harita', 'adres'],
      onTap: () => _openEditor(context, _EditorConfig.geo()),
    ),
    _RecordTypeOption(
      category: _RecordTypeCategory.contact,
      icon: Icons.badge_outlined,
      title: 'vCard (Kisi karti)',
      subtitle: 'Ad, telefon, e-posta, sirket ve daha fazlasi',
      searchTerms: const <String>['kartvizit', 'contact', 'vcard'],
      onTap: () => _openVCardEditor(context),
    ),
  ];

  Future<void> _openEditor(BuildContext context, _EditorConfig config) async {
    final content = await Navigator.of(context).push<NdefContent>(
      MaterialPageRoute(builder: (_) => _RecordInputPage(config: config)),
    );
    if (content == null || !context.mounted) return;
    Navigator.of(context).pop(content);
  }

  Future<void> _openVCardEditor(BuildContext context) async {
    final content = await Navigator.of(context).push<NdefContent>(
      MaterialPageRoute(builder: (_) => const _VCardInputPage()),
    );
    if (content == null || !context.mounted) return;
    Navigator.of(context).pop(content);
  }
}

enum _RecordTypeCategory {
  basic('Temel'),
  contact('Iletisim'),
  location('Konum');

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
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}

class _RecordInputPage extends StatefulWidget {
  const _RecordInputPage({required this.config});

  final _EditorConfig config;

  @override
  State<_RecordInputPage> createState() => _RecordInputPageState();
}

class _RecordInputPageState extends State<_RecordInputPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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

class _VCardInputPage extends StatefulWidget {
  const _VCardInputPage();

  @override
  State<_VCardInputPage> createState() => _VCardInputPageState();
}

class _VCardInputPageState extends State<_VCardInputPage> {
  late final TextEditingController _fullName;
  late final TextEditingController _givenName;
  late final TextEditingController _familyName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _organization;
  late final TextEditingController _title;
  late final TextEditingController _address;
  late final TextEditingController _url;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _givenName = TextEditingController();
    _familyName = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _organization = TextEditingController();
    _title = TextEditingController();
    _address = TextEditingController();
    _url = TextEditingController();
    _note = TextEditingController();
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
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('vCard olustur')),
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
              hintText: 'ornek@alan.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _organization,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Sirket',
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
              hintText: 'Istanbul, Turkiye',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _url,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Web sitesi',
              hintText: 'https://ornek.com',
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
          const SizedBox(height: AppSpacing.lg),
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
  );

  void _submit() {
    final formattedName = _fullName.text.trim();
    if (formattedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tam ad zorunlu')),
      );
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
      note: _nullIfBlank(_note.text),
    );

    Navigator.of(context).pop(content);
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
    title: 'Metin kaydi',
    label: 'Metin',
    icon: Icons.text_fields,
    build: (value) => TextContent(text: value),
  );

  factory _EditorConfig.url() => const _EditorConfig(
    title: 'Baglanti kaydi',
    label: 'URL',
    hint: 'https://ornek.com',
    icon: Icons.link,
    keyboardType: TextInputType.url,
    build: UriContent.new,
  );

  factory _EditorConfig.phone() => _EditorConfig(
    title: 'Telefon kaydi',
    label: 'Telefon numarasi',
    hint: '+905551112233',
    icon: Icons.call_outlined,
    keyboardType: TextInputType.phone,
    build: (value) => UriContent('tel:$value'),
  );

  factory _EditorConfig.sms() => _EditorConfig(
    title: 'SMS kaydi',
    label: 'Telefon numarasi',
    hint: '+905551112233',
    icon: Icons.sms_outlined,
    keyboardType: TextInputType.phone,
    build: (value) => UriContent('sms:$value'),
  );

  factory _EditorConfig.email() => _EditorConfig(
    title: 'E-posta kaydi',
    label: 'E-posta adresi',
    hint: 'ornek@alan.com',
    icon: Icons.email_outlined,
    keyboardType: TextInputType.emailAddress,
    build: (value) => UriContent('mailto:$value'),
  );

  factory _EditorConfig.geo() => _EditorConfig(
    title: 'Konum kaydi',
    label: 'Enlem,Boylam',
    hint: '41.0082,28.9784',
    icon: Icons.place_outlined,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    build: (value) => UriContent('geo:$value'),
  );
}
