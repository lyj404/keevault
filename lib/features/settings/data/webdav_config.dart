import 'dart:convert';

class WebDavConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final String remoteFilename;
  final bool enabled;

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '',
    this.remoteFilename = 'database.kdbx',
    this.enabled = false,
  });

  /// Builds the full remote file path for WebDAV operations.
  /// If remotePath is empty, only the filename is used (relative to server URL).
  String get remoteFilePath {
    final path = remotePath.trim();
    final name = remoteFilename.trim();
    if (path.isEmpty) return '/$name';
    return '$path/$name';
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'remotePath': remotePath,
        'remoteFilename': remoteFilename,
        'enabled': enabled,
      };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
        serverUrl: json['serverUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        remotePath: json['remotePath'] as String? ?? '',
        remoteFilename: json['remoteFilename'] as String? ?? 'database.kdbx',
        enabled: json['enabled'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  factory WebDavConfig.decode(String source) =>
      WebDavConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remotePath,
    String? remoteFilename,
    bool? enabled,
  }) =>
      WebDavConfig(
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        password: password ?? this.password,
        remotePath: remotePath ?? this.remotePath,
        remoteFilename: remoteFilename ?? this.remoteFilename,
        enabled: enabled ?? this.enabled,
      );
}
