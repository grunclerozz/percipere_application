import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'extraction_exception.dart';

/// Extracts plain text from a .docx file: unzips it and walks
/// `word/document.xml`, one line per paragraph (`w:p`), honoring tabs and
/// line breaks. Tables come out row by row, cells separated by tabs.
String extractDocxText(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const ExtractionException(ExtractionFailure.unreadable);
  }
  final entry = archive.findFile('word/document.xml');
  if (entry == null) {
    throw const ExtractionException(ExtractionFailure.unreadable);
  }

  final XmlDocument xml;
  try {
    xml = XmlDocument.parse(utf8.decode(entry.content));
  } on Object {
    throw const ExtractionException(ExtractionFailure.unreadable);
  }

  final out = StringBuffer();
  for (final p in xml.descendants.whereType<XmlElement>()) {
    if (p.name.qualified != 'w:p') continue;
    final line = StringBuffer();
    for (final node in p.descendants.whereType<XmlElement>()) {
      switch (node.name.qualified) {
        case 'w:t':
          line.write(node.innerText);
        case 'w:tab':
          line.write('\t');
        case 'w:br' || 'w:cr':
          line.write('\n');
      }
    }
    out
      ..write(line)
      ..write('\n');
  }
  return out.toString();
}

/// [extractDocxText] in a background isolate for larger files.
Future<String> extractDocxTextAsync(Uint8List bytes) {
  if (bytes.length < 200 * 1024) return Future.value(extractDocxText(bytes));
  return Isolate.run(() => extractDocxText(bytes));
}
