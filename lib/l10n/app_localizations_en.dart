// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KeeVault';

  @override
  String get appSubtitle => 'KeePass-compatible password manager';

  @override
  String get openLocalDatabase => 'Open Local Database';

  @override
  String get createNewDatabase => 'Create New Database';

  @override
  String get openCloudDatabase => 'Open Cloud Database';

  @override
  String get recentOpened => 'Recent';

  @override
  String get cloudPrefix => 'Cloud';

  @override
  String get syncingCloudDatabase => 'Syncing cloud database...';

  @override
  String get downloadingFromCloud => 'Downloading from cloud...';

  @override
  String get uploadingToCloud => 'Uploading to cloud...';

  @override
  String get downloadingFromCloudShort => 'Downloading from cloud...';

  @override
  String get pleaseConfigureWebDAV =>
      'Please configure WebDAV in settings first';

  @override
  String get cloudNoDatabaseCreateFirst =>
      'No cloud database found. Please create and save a local database first, then sync.';

  @override
  String get cloudNoDatabaseSaveFirst =>
      'No cloud database found. Please save a local database first, then sync.';

  @override
  String downloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String syncFailedWithError(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'OK';

  @override
  String get move => 'Move';

  @override
  String get close => 'Close';

  @override
  String get unlockDatabase => 'Unlock Database';

  @override
  String get cloudDatabase => 'Cloud Database';

  @override
  String get masterPassword => 'Master Password';

  @override
  String get pleaseEnterPassword => 'Please enter password';

  @override
  String get decryptingFirstTimeSlow => 'Decrypting, first open may be slow...';

  @override
  String get unlock => 'Unlock';

  @override
  String get passwordError => 'Incorrect password';

  @override
  String get fileFormatIncorrect => 'File format is incorrect or corrupted';

  @override
  String openFailed(Object msg) {
    return 'Open failed: $msg';
  }

  @override
  String get createDatabase => 'Create Database';

  @override
  String get databaseName => 'Database Name';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordsNotMatch => 'Passwords do not match';

  @override
  String get selectSaveLocation => 'Select Save Location';

  @override
  String get create => 'Create';

  @override
  String get saveDatabase => 'Save Database';

  @override
  String get myDatabase => 'My Database';

  @override
  String error(Object e) {
    return 'Error: $e';
  }

  @override
  String get cloudNewVersion => 'New version on cloud';

  @override
  String get cloudModifiedSyncLatest =>
      'Cloud database has been modified by another device. Sync the latest version?';

  @override
  String get ignore => 'Ignore';

  @override
  String get sync => 'Sync';

  @override
  String get deleteEntry => 'Delete Entry';

  @override
  String get moveToRecycleBin => 'Move this entry to the recycle bin?';

  @override
  String get permanentDelete => 'Permanent Delete';

  @override
  String get permanentDeleteConfirm =>
      'This action cannot be undone. Confirm delete?';

  @override
  String get movedToRecycleBin => 'Moved to recycle bin';

  @override
  String get permanentlyDeleted => 'Permanently deleted';

  @override
  String get restored => 'Restored';

  @override
  String get restoreFailed => 'Restore failed: original group not found';

  @override
  String get moved => 'Moved';

  @override
  String get cannotDeleteNonEmptyGroup => 'Cannot delete a non-empty group';

  @override
  String get deleteGroup => 'Delete Group';

  @override
  String deleteGroupConfirm(Object name) {
    return 'Delete group \'$name\'?';
  }

  @override
  String get renameGroup => 'Rename Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get saved => 'Saved';

  @override
  String get syncConflict => 'Sync Conflict';

  @override
  String get syncConflictMessage =>
      'Cloud database has been modified by another device. You can overwrite the cloud version (use local), or download the cloud version first.';

  @override
  String get downloadCloudVersion => 'Download Cloud Version';

  @override
  String get overwriteCloud => 'Overwrite Cloud';

  @override
  String get overwrittenToCloud => 'Overwritten to cloud';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get search => 'Search';

  @override
  String get back => 'Back';

  @override
  String get addEntry => 'Add Entry';

  @override
  String get addGroup => 'Add Group';

  @override
  String get syncFromCloud => 'Sync from Cloud';

  @override
  String get more => 'More';

  @override
  String get syncToCloud => 'Sync to Cloud';

  @override
  String get downloadFromCloud => 'Download from Cloud';

  @override
  String get syncSettings => 'Sync Settings';

  @override
  String get closeDatabase => 'Close Database';

  @override
  String get rootDirectory => 'Root';

  @override
  String get thisGroupIsEmpty => 'This group is empty';

  @override
  String get newEntry => 'New Entry';

  @override
  String get title => 'Title';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get url => 'URL';

  @override
  String get notes => 'Notes';

  @override
  String get generatePassword => 'Generate Password';

  @override
  String get newGroup => 'New Group';

  @override
  String get rename => 'Rename';

  @override
  String get syncedToCloud => 'Synced to cloud';

  @override
  String get syncedFromCloud => 'Synced from cloud';

  @override
  String get copyUsername => 'Copy Username';

  @override
  String get copyPassword => 'Copy Password';

  @override
  String get entry => 'Entry';

  @override
  String get entryNotFound => 'Entry not found';

  @override
  String get entryDetail => 'Entry Details';

  @override
  String get edit => 'Edit';

  @override
  String get restore => 'Restore';

  @override
  String get permanentDeleteTooltip => 'Permanent Delete';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get editEntry => 'Edit Entry';

  @override
  String get untitled => '(Untitled)';

  @override
  String get copy => 'Copy';

  @override
  String copiedField(Object label) {
    return 'Copied $label';
  }

  @override
  String get copiedPassword => 'Copied password';

  @override
  String get copiedUsername => 'Copied username';

  @override
  String get hide => 'Hide';

  @override
  String get show => 'Show';

  @override
  String get searchEntries => 'Search entries...';

  @override
  String get enterKeywords => 'Enter keywords to search';

  @override
  String get noResults => 'No matching results';

  @override
  String get webdavSync => 'WebDAV Sync';

  @override
  String get autoSyncOnSave => 'Auto-sync to cloud on save';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get serverAddressHint => 'https://example.com/dav/';

  @override
  String get serverAddressHelper => 'WebDAV server URL, without filename';

  @override
  String get pleaseEnterServerAddress => 'Please enter server address';

  @override
  String get pleaseEnterUsername => 'Please enter username';

  @override
  String get appPasswordHelper =>
      'Some services (e.g. Jianguoyun) require an app-specific password instead of your account password';

  @override
  String get remotePathOptional => 'Remote Path (optional)';

  @override
  String get remotePathHint => 'e.g. /keepass, leave empty for root directory';

  @override
  String get filename => 'Filename';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get testing => 'Testing...';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get moveToGroup => 'Move to Group';

  @override
  String get generatePasswordTitle => 'Generate Password';

  @override
  String get copied => 'Copy';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get passwordLength => 'Password Length';

  @override
  String get characterTypes => 'Character Types';

  @override
  String get uppercaseAZ => 'Uppercase A-Z';

  @override
  String get lowercaseaz => 'Lowercase a-z';

  @override
  String get digits09 => 'Digits 0-9';

  @override
  String get symbols => 'Symbols !@#\$%^&*';

  @override
  String get hyphen => 'Hyphen -';

  @override
  String get underscore => 'Underscore _';

  @override
  String get parentheses => 'Parentheses ()';

  @override
  String get space => 'Space';

  @override
  String get customSymbols => 'Custom Symbols';

  @override
  String get customSymbolsHint => 'Enter additional symbols to include';

  @override
  String get useThisPassword => 'Use This Password';

  @override
  String get recycleBin => 'Recycle Bin';

  @override
  String get noPasswordCannotReload => 'No password available, cannot reload';

  @override
  String get authFailedCheckCredentials =>
      'Authentication failed, please check username and password';

  @override
  String serverConnectedPathNotAccessible(Object path) {
    return 'Server connected, but path \'$path\' is not accessible';
  }

  @override
  String connectionFailedMsg(Object msg) {
    return 'Connection failed: $msg';
  }

  @override
  String get networkFailedCheckServer =>
      'Network connection failed, please check server address';

  @override
  String get remoteDatabaseNotExist => 'Remote database does not exist';

  @override
  String get pleaseConfigureWebDAVFirst => 'Please configure WebDAV first';

  @override
  String get cloudDatabaseNotExist => 'Cloud database does not exist';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow System';

  @override
  String get theme => 'Theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';
}
