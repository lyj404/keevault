// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'KeeVault';

  @override
  String get appSubtitle => 'KeePass 兼容的密码管理器';

  @override
  String get openLocalDatabase => '打开本地数据库';

  @override
  String get createNewDatabase => '创建新数据库';

  @override
  String get openCloudDatabase => '打开云端数据库';

  @override
  String get recentOpened => '最近打开';

  @override
  String get cloudPrefix => '云端';

  @override
  String get syncingCloudDatabase => '正在同步云端数据库...';

  @override
  String get downloadingFromCloud => '正在从云端下载...';

  @override
  String get uploadingToCloud => '正在同步到云端...';

  @override
  String get downloadingFromCloudShort => '正在从云端下载...';

  @override
  String get pleaseConfigureWebDAV => '请先在设置中配置 WebDAV';

  @override
  String get cloudNoDatabaseCreateFirst => '云端还没有数据库，请先在本地创建并保存后同步';

  @override
  String get cloudNoDatabaseSaveFirst => '云端还没有数据库，请先保存本地数据库后同步';

  @override
  String downloadFailed(Object error) {
    return '下载失败: $error';
  }

  @override
  String syncFailedWithError(Object error) {
    return '同步失败: $error';
  }

  @override
  String get cancel => '取消';

  @override
  String get goToSettings => '去设置';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确定';

  @override
  String get move => '移动';

  @override
  String get close => '关闭';

  @override
  String get unlockDatabase => '解锁数据库';

  @override
  String get cloudDatabase => '云端数据库';

  @override
  String get masterPassword => '主密码';

  @override
  String get pleaseEnterPassword => '请输入密码';

  @override
  String get decryptingFirstTimeSlow => '正在解密，首次打开可能较慢...';

  @override
  String get unlock => '解锁';

  @override
  String get passwordError => '密码错误';

  @override
  String get fileFormatIncorrect => '文件格式不正确或已损坏';

  @override
  String openFailed(Object msg) {
    return '打开失败: $msg';
  }

  @override
  String get createDatabase => '创建数据库';

  @override
  String get databaseName => '数据库名称';

  @override
  String get pleaseEnterName => '请输入名称';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordsNotMatch => '两次密码不一致';

  @override
  String get selectSaveLocation => '选择保存位置';

  @override
  String get create => '创建';

  @override
  String get saveDatabase => '保存数据库';

  @override
  String get myDatabase => '我的数据库';

  @override
  String error(Object e) {
    return '错误: $e';
  }

  @override
  String get cloudNewVersion => '云端有新版本';

  @override
  String get cloudModifiedSyncLatest => '检测到云端数据库已被其他设备修改，是否同步最新版本？';

  @override
  String get ignore => '忽略';

  @override
  String get sync => '同步';

  @override
  String get deleteEntry => '删除条目';

  @override
  String get moveToRecycleBin => '确定将此条目移至回收站？';

  @override
  String get permanentDelete => '永久删除';

  @override
  String get permanentDeleteConfirm => '此操作不可撤销，确定删除？';

  @override
  String get movedToRecycleBin => '已移至回收站';

  @override
  String get permanentlyDeleted => '已永久删除';

  @override
  String get restored => '已恢复';

  @override
  String get restoreFailed => '恢复失败：找不到原始分组';

  @override
  String get moved => '已移动';

  @override
  String get cannotDeleteNonEmptyGroup => '不能删除非空分组';

  @override
  String get deleteGroup => '删除分组';

  @override
  String deleteGroupConfirm(Object name) {
    return '确定删除分组「$name」？';
  }

  @override
  String get renameGroup => '重命名分组';

  @override
  String get groupName => '分组名称';

  @override
  String get saved => '已保存';

  @override
  String get syncConflict => '同步冲突';

  @override
  String get syncConflictMessage =>
      '云端数据库已被其他设备修改。你可以选择覆盖云端版本（以本地为准），或先下载云端版本再编辑。';

  @override
  String get downloadCloudVersion => '下载云端版本';

  @override
  String get overwriteCloud => '覆盖云端';

  @override
  String get overwrittenToCloud => '已覆盖同步到云端';

  @override
  String get syncFailed => '同步失败';

  @override
  String get search => '搜索';

  @override
  String get back => '返回';

  @override
  String get addEntry => '添加条目';

  @override
  String get addGroup => '添加分组';

  @override
  String get syncFromCloud => '从云端同步';

  @override
  String get more => '更多';

  @override
  String get syncToCloud => '同步到云端';

  @override
  String get downloadFromCloud => '从云端下载';

  @override
  String get settings => '设置';

  @override
  String get closeDatabase => '关闭数据库';

  @override
  String get rootDirectory => '根目录';

  @override
  String get thisGroupIsEmpty => '此分组为空';

  @override
  String get newEntry => '新建条目';

  @override
  String get title => '标题';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get url => '网址';

  @override
  String get notes => '备注';

  @override
  String get generatePassword => '生成密码';

  @override
  String get newGroup => '新建分组';

  @override
  String get rename => '重命名';

  @override
  String get syncedToCloud => '已同步到云端';

  @override
  String get syncedFromCloud => '已从云端同步';

  @override
  String get copyUsername => '复制用户名';

  @override
  String get copyPassword => '复制密码';

  @override
  String get entry => '条目';

  @override
  String get entryNotFound => '未找到该条目';

  @override
  String get entryDetail => '条目详情';

  @override
  String get edit => '编辑';

  @override
  String get restore => '恢复';

  @override
  String get permanentDeleteTooltip => '永久删除';

  @override
  String get deleteTooltip => '删除';

  @override
  String get editEntry => '编辑条目';

  @override
  String get untitled => '(未命名)';

  @override
  String get copy => '复制';

  @override
  String copiedField(Object label) {
    return '已复制$label';
  }

  @override
  String get copiedPassword => '已复制密码';

  @override
  String get copiedUsername => '已复制用户名';

  @override
  String get hide => '隐藏';

  @override
  String get show => '显示';

  @override
  String get searchEntries => '搜索条目...';

  @override
  String get enterKeywords => '输入关键词搜索';

  @override
  String get noResults => '未找到匹配结果';

  @override
  String get webdavSync => 'WebDAV 同步';

  @override
  String get autoSyncOnSave => '保存时自动同步到云端';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get serverAddressHint => 'https://example.com/dav/';

  @override
  String get serverAddressHelper => 'WebDAV 服务地址，不含文件名';

  @override
  String get pleaseEnterServerAddress => '请输入服务器地址';

  @override
  String get pleaseEnterUsername => '请输入用户名';

  @override
  String get appPasswordHelper => '部分服务（如坚果云）需要使用应用专用密码而非账号密码';

  @override
  String get remotePathOptional => '远程路径（可选）';

  @override
  String get remotePathHint => '例如 /keepass，留空则保存在根目录';

  @override
  String get filename => '文件名';

  @override
  String get testConnection => '测试连接';

  @override
  String get testing => '测试中...';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get moveToGroup => '移动到分组';

  @override
  String get generatePasswordTitle => '生成密码';

  @override
  String get copied => '复制';

  @override
  String get regenerate => '重新生成';

  @override
  String get passwordLength => '密码长度';

  @override
  String get characterTypes => '字符类型';

  @override
  String get uppercaseAZ => '大写字母 A-Z';

  @override
  String get lowercaseaz => '小写字母 a-z';

  @override
  String get digits09 => '数字 0-9';

  @override
  String get symbols => '符号 !@#\$%^&*';

  @override
  String get hyphen => '减号 -';

  @override
  String get underscore => '下划线 _';

  @override
  String get parentheses => '括号 ()';

  @override
  String get space => '空格';

  @override
  String get customSymbols => '自定义符号';

  @override
  String get customSymbolsHint => '输入额外要包含的符号';

  @override
  String get useThisPassword => '使用此密码';

  @override
  String get recycleBin => '回收站';

  @override
  String get noPasswordCannotReload => '无密码信息，无法重新加载';

  @override
  String get authFailedCheckCredentials => '认证失败，请检查用户名和密码';

  @override
  String serverConnectedPathNotAccessible(Object path) {
    return '服务器已连接，但路径「$path」不可访问';
  }

  @override
  String connectionFailedMsg(Object msg) {
    return '连接失败: $msg';
  }

  @override
  String get networkFailedCheckServer => '网络连接失败，请检查服务器地址';

  @override
  String get remoteDatabaseNotExist => '远程数据库不存在';

  @override
  String get pleaseConfigureWebDAVFirst => '请先配置 WebDAV';

  @override
  String get cloudDatabaseNotExist => '云端数据库不存在';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get theme => '主题';

  @override
  String get lightTheme => '浅色模式';

  @override
  String get darkTheme => '深色模式';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get groups => '个分组';

  @override
  String get entries => '个条目';

  @override
  String get closeBehavior => '关闭窗口时';

  @override
  String get askEveryTime => '每次询问';

  @override
  String get minimizeToTray => '最小化到系统托盘';

  @override
  String get minimize => '最小化';

  @override
  String get exitApp => '直接退出';

  @override
  String get closeWindowMessage => '请选择关闭窗口的方式：';

  @override
  String get rememberChoice => '记住我的选择';

  @override
  String get showMainWindow => '显示主窗口';

  @override
  String get exit => '退出';

  @override
  String get autoLock => '自动锁定';

  @override
  String get autoLockDescription => '无操作后自动锁定数据库';

  @override
  String get disabled => '关闭';

  @override
  String get minute => '分钟';

  @override
  String get minutes => '分钟';

  @override
  String get databaseBackup => '数据库备份';

  @override
  String get autoBackup => '自动备份';

  @override
  String get autoBackupDescription => '保存和同步前自动备份数据库';

  @override
  String get createBackupNow => '立即备份';

  @override
  String get noBackups => '暂无备份';

  @override
  String get backupCreated => '备份已创建';

  @override
  String get backupFailed => '备份失败';

  @override
  String get restoreBackup => '恢复备份';

  @override
  String get restoreBackupConfirm => '确定恢复此备份？恢复前将自动备份当前数据库。';

  @override
  String get backupRestored => '备份已恢复';

  @override
  String get backupRestoreFailed => '恢复失败';

  @override
  String get backupNotFound => '备份文件不存在';

  @override
  String get deleteBackup => '删除备份';

  @override
  String get deleteBackupConfirm => '确定删除此备份？此操作不可撤销。';

  @override
  String get backupDeleted => '备份已删除';

  @override
  String get backupRetention => '备份数量';

  @override
  String backupRetentionInfo(Object count) {
    return '保留最近 $count 个备份';
  }

  @override
  String backupRetentionCount(Object count) {
    return '保留 $count 个备份';
  }

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get build => '构建';

  @override
  String get aboutDescription => '一个安全、开源的密码管理器，兼容 KeePass 格式。';

  @override
  String get sourceCode => '源代码';

  @override
  String get reportIssue => '报告问题';

  @override
  String get reportIssueDescription => '反馈 Bug 或建议';

  @override
  String get linkCopied => '链接已复制';

  @override
  String get newVersionAvailable => '有新版本可用';

  @override
  String get update => '去更新';

  @override
  String get alreadyLatest => '已是最新版本';

  @override
  String get licenses => '许可证';

  @override
  String get openSourceLicenses => '开源许可协议';

  @override
  String get changeMasterPassword => '修改主密码';

  @override
  String get currentPassword => '当前密码';

  @override
  String get pleaseEnterCurrentPassword => '请输入当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get pleaseEnterNewPassword => '请输入新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get passwordChanged => '主密码已修改';

  @override
  String get history => '历史记录';

  @override
  String get noHistory => '暂无历史记录';

  @override
  String get restoreVersion => '恢复此版本';

  @override
  String get restoreVersionConfirm => '确定将条目恢复到此版本？当前状态会先保存到历史记录。';

  @override
  String get versionRestored => '已恢复到历史版本';

  @override
  String get currentVersion => '当前版本';

  @override
  String get attachments => '附件';

  @override
  String get addAttachment => '添加附件';

  @override
  String get deleteAttachment => '删除附件';

  @override
  String get deleteAttachmentConfirm => '确定删除此附件？';

  @override
  String get attachmentDeleted => '附件已删除';

  @override
  String get attachmentAdded => '附件已添加';

  @override
  String get attachmentSaved => '附件已保存';

  @override
  String get saveAttachment => '保存附件';

  @override
  String get noAttachments => '暂无附件';

  @override
  String get customFields => '自定义字段';

  @override
  String get addCustomField => '添加字段';

  @override
  String get fieldName => '字段名称';

  @override
  String get fieldValue => '字段值';

  @override
  String get protectField => '保护字段';

  @override
  String get unprotectField => '取消保护';

  @override
  String get fieldNameEmpty => '字段名称不能为空';

  @override
  String fieldNameDuplicate(Object name) {
    return '字段名称重复: $name';
  }

  @override
  String fieldNameReserved(Object name) {
    return '字段名称 \"$name\" 是保留名称';
  }

  @override
  String deleteCustomFieldConfirm(Object name) {
    return '确定删除字段 \"$name\"？';
  }

  @override
  String get backupPasswordDifferent => '备份使用了不同的密码（可能修改过主密码），请输入备份时的密码';

  @override
  String get backupPasswordHint => '请输入备份时的主密码';

  @override
  String get importCsv => '导入 CSV';

  @override
  String get exportCsv => '导出 CSV';

  @override
  String get exportKdbx => '导出 KDBX';

  @override
  String get importCsvTitle => '导入 CSV 文件';

  @override
  String importSuccess(Object count) {
    return '成功导入 $count 个条目';
  }

  @override
  String importFailed(Object error) {
    return '导入失败: $error';
  }

  @override
  String get exportSuccess => '导出成功';

  @override
  String get exportFailed => '导出失败';

  @override
  String get noEntriesToExport => '没有可导出的条目';

  @override
  String get noEntriesInCsv => 'CSV 文件中未找到有效条目';

  @override
  String get expiration => '过期时间';

  @override
  String get noExpiration => '永不过期';

  @override
  String get expired => '已过期';

  @override
  String expiresOn(Object date) {
    return '过期于 $date';
  }
}
