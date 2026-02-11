import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

String generateTotp(
  String base32Secret,
  int timestampMs, {
  int digits = 6,
  int period = 30,
}) {
  final key = base32Decode(base32Secret);
  final counter = (timestampMs ~/ 1000) ~/ period;
  final data = ByteData(8)..setInt64(0, counter);
  final hmac = Hmac(sha1, key).convert(data.buffer.asUint8List());
  final bytes = hmac.bytes;
  final offset = bytes.last & 0x0f;
  final binary = ((bytes[offset] & 0x7f) << 24) |
      ((bytes[offset + 1] & 0xff) << 16) |
      ((bytes[offset + 2] & 0xff) << 8) |
      (bytes[offset + 3] & 0xff);
  final modulus = pow(10, digits).toInt();
  final code = binary % modulus;
  return code.toString().padLeft(digits, '0');
}

List<int> base32Decode(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('=', '')
      .toUpperCase();
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var buffer = 0;
  var bitsLeft = 0;
  final output = <int>[];
  for (final codeUnit in cleaned.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    final index = alphabet.indexOf(char);
    if (index == -1) {
      throw const FormatException('Invalid Base32 character');
    }
    buffer = (buffer << 5) | index;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      bitsLeft -= 8;
      output.add((buffer >> bitsLeft) & 0xff);
    }
  }
  return output;
}

bool isValidBase32(String input) {
  final cleaned = input.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (cleaned.isEmpty) return false;
  return RegExp(r'^[A-Z2-7]+=*$').hasMatch(cleaned);
}
