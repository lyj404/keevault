import 'dart:math';

class PasswordGenerator {
  static const defaultUppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const defaultLowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const defaultDigits = '0123456789';
  static const defaultSymbols = '!@#\$%^&*=[]{}|;:,.<>?';
  static const defaultHyphen = '-';
  static const defaultSpace = ' ';
  static const defaultUnderscore = '_';
  static const defaultParentheses = '()';

  static String generate({
    int length = 20,
    bool useUppercase = true,
    bool useLowercase = true,
    bool useDigits = true,
    bool useSymbols = true,
    bool useHyphen = true,
    bool useSpace = false,
    bool useUnderscore = true,
    bool useParentheses = true,
    String? customSymbols,
  }) {
    length = length.clamp(1, 200);
    var chars = '';
    if (useUppercase) chars += defaultUppercase;
    if (useLowercase) chars += defaultLowercase;
    if (useDigits) chars += defaultDigits;
    if (useSymbols) chars += defaultSymbols;
    if (useHyphen) chars += defaultHyphen;
    if (useSpace) chars += defaultSpace;
    if (useUnderscore) chars += defaultUnderscore;
    if (useParentheses) chars += defaultParentheses;
    if (customSymbols?.isNotEmpty == true) chars += customSymbols!;
    if (chars.isEmpty) chars = defaultLowercase;

    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
