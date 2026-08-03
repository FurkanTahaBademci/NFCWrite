import 'app_strings.dart';

/// Ingilizce metinler.
final class AppStringsEn extends AppStrings {
  const AppStringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get appName => 'NFC Toolkit';

  @override
  String get tabRead => 'Read';
  @override
  String get tabWrite => 'Write';
  @override
  String get tabTools => 'Other';
  @override
  String get tabHistory => 'History';

  @override
  String get actionCancel => 'Cancel';
  @override
  String get actionRetry => 'Retry';
  @override
  String get actionDone => 'Done';
  @override
  String get actionSave => 'Save';
  @override
  String get actionDelete => 'Delete';
  @override
  String get actionCopy => 'Copy';
  @override
  String get actionShare => 'Share';
  @override
  String get actionClose => 'Close';
  @override
  String get actionSettings => 'Settings';
  @override
  String get actionScan => 'Scan tag';

  @override
  String get scanTitle => 'Hold tag near phone';
  @override
  String get scanHint => 'Place the tag against the back of your phone';
  @override
  String get scanFound => 'Tag found';
  @override
  String get scanWorking => 'Working…';
  @override
  String get scanSuccess => 'Done';
  @override
  String get scanFailed => 'Operation failed';

  @override
  String get readEmptyTitle => 'No tag read yet';
  @override
  String get readEmptyDescription =>
      'Hold an NFC tag against the back of your phone to read its contents.';
  @override
  String get readSectionIdentity => 'Info';
  @override
  String get readSectionNdef => 'NDEF';
  @override
  String get readSectionMemory => 'Memory';
  @override
  String get readSectionTechnical => 'Technical';
  @override
  String get readUid => 'UID';
  @override
  String get readUidReversed => 'UID (reversed)';
  @override
  String get readChip => 'Chip';
  @override
  String get readManufacturer => 'Manufacturer';
  @override
  String get readTechnologies => 'Technologies';
  @override
  String get readCapacity => 'NDEF capacity';
  @override
  String get readWritable => 'Writable';
  @override
  String get readReadOnly => 'Read-only';
  @override
  String get readFormatted => 'Formatted';
  @override
  String get readNotFormatted => 'Not formatted';
  @override
  String get readPasswordProtected => 'Password protected';
  @override
  String get readNoRecords => 'No NDEF records on this tag';

  @override
  String get writeEmptyTitle => 'No records added';
  @override
  String get writeEmptyDescription =>
      'Add the records you want to write, then tap “Write”.';
  @override
  String get writeAddRecord => 'Add record';
  @override
  String get writeAction => 'Write to tag';
  @override
  String get writeLockAfterWrite => 'Lock after writing';

  @override
  String get toolsTitle => 'Tag tools';
  @override
  String get toolsGroupSafe => 'Safe';
  @override
  String get toolsGroupContent => 'Content';
  @override
  String get toolsGroupConfig => 'Configuration';
  @override
  String get toolsGroupIrreversible => 'Irreversible';
  @override
  String get toolsExpertModeRequired =>
      'Enable expert mode in Settings to use these tools.';

  @override
  String get historyEmptyTitle => 'History is empty';
  @override
  String get historyEmptyDescription => 'Tags you read will be listed here.';
  @override
  String get historyToday => 'Today';
  @override
  String get historyYesterday => 'Yesterday';
  @override
  String get historyThisWeek => 'This week';
  @override
  String get historyOlder => 'Older';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get settingsAppearance => 'Appearance';
  @override
  String get settingsTheme => 'Theme';
  @override
  String get settingsThemeSystem => 'System';
  @override
  String get settingsThemeLight => 'Light';
  @override
  String get settingsThemeDark => 'Dark';
  @override
  String get settingsDynamicColor => 'Dynamic color';
  @override
  String get settingsLanguage => 'Language';
  @override
  String get settingsFeedback => 'Feedback';
  @override
  String get settingsHaptic => 'Haptics';
  @override
  String get settingsSound => 'Sound';
  @override
  String get settingsScanning => 'Scanning';
  @override
  String get settingsAutoSaveHistory => 'Save scans to history';
  @override
  String get settingsDeepRead => 'Deep read (slower, more detail)';
  @override
  String get settingsSafety => 'Safety';
  @override
  String get settingsExpertMode => 'Expert mode';
  @override
  String get settingsExpertModeDescription =>
      'Reveals irreversible tools. Misuse can permanently ruin a tag.';
  @override
  String get settingsAutoBackup => 'Back up before destructive operations';
  @override
  String get settingsAbout => 'About';
  @override
  String get settingsVersion => 'Version';
  @override
  String get settingsLicenses => 'Licenses';

  @override
  String get dangerIrreversible => 'THIS CANNOT BE UNDONE';
  @override
  String get dangerSlideToConfirm => 'Slide to confirm';
  @override
  String get dangerTakeBackup => 'Back up first';

  @override
  String get errorNfcUnsupported => 'This device has no NFC.';
  @override
  String get errorNfcDisabled => 'NFC is turned off. Enable it in settings.';
  @override
  String get errorNfcDisabledAction => 'Open NFC settings';
  @override
  String get errorTagLost =>
      'Tag moved away. Hold it still until the operation finishes.';
  @override
  String get errorTagNotSupported =>
      'This operation is not supported by this tag.';
  @override
  String get errorTagReadOnly => 'The tag is write-protected.';
  @override
  String get errorAuthRequired => 'This operation requires the tag password.';
  @override
  String get errorAuthFailed => 'Wrong password.';
  @override
  String get errorCancelled => 'Operation cancelled.';
  @override
  String get errorTimeout => 'Timed out — no tag found.';
  @override
  String get errorVerificationFailed =>
      'Write verification failed — data read back does not match.';
  @override
  String get errorMalformedData =>
      'The data on the tag is unreadable or corrupt.';
  @override
  String get errorStorage => 'Could not save data.';
  @override
  String get errorUnknown => 'An unexpected error occurred.';
  @override
  String get errorNotImplemented => 'This feature is not ready yet.';

  @override
  String errorInsufficientSpace(int needed, int available) => available < 0
      ? 'The content does not fit on this tag.'
      : 'Content does not fit: $needed bytes needed, $available available.';
}
