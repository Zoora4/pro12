import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;

class TextRun {
  final String text;
  final bool isBold;

  TextRun(this.text, {this.isBold = false});
}

class TextExtractorService {
  static Future<String> extractText(String filePath) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();

    if (ext == 'txt') return _clean(await file.readAsString());

    if (ext == 'docx') {
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final doc = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
      );
      final xml = XmlDocument.parse(
        String.fromCharCodes(doc.content as List<int>),
      );

      final buffer = StringBuffer();
      for (final para in xml.findAllElements('w:p')) {
        final paragraphText = _extractDocxParagraphText(para);
        final trimmed = paragraphText.trim();
        if (trimmed.isNotEmpty) {
          buffer.write(trimmed);
          buffer.write('\n\n');
        }
      }
      return _clean(buffer.toString());
    }

    if (ext == 'pdf') {
      final doc = PdfDocument(inputBytes: await file.readAsBytes());
      final extractor = PdfTextExtractor(doc);
      final buffer = StringBuffer();
      for (int i = 0; i < doc.pages.count; i++) {
        var pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
          layoutText: true,
        );

        // If plain extraction did not return useful text, try line-based extraction.
        if (pageText.trim().isEmpty) {
          final textLines = extractor.extractTextLines(
            startPageIndex: i,
            endPageIndex: i,
          );
          if (textLines.isNotEmpty) {
            pageText = textLines
                .map((line) => line.text.trim())
                .where((text) => text.isNotEmpty)
                .join('\n');
          }
        }

        final normalized = _normalizePdfText(pageText);
        if (normalized.isNotEmpty) {
          buffer.write(normalized);
          buffer.write('\n\n');
        }
      }
      doc.dispose();
      return _clean(buffer.toString());
    }

    if (['jpg', 'jpeg', 'png'].contains(ext)) {
      final input = mlkit.InputImage.fromFile(file);
      final recognizer = mlkit.TextRecognizer();
      final result = await recognizer.processImage(input);
      await recognizer.close();
      return _clean(result.text);
    }

    return 'Unsupported file type';
  }
  

  static Future<List<List<TextRun>>> extractParagraphRuns(
    String filePath,
  ) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();

    if (ext == 'txt') {
      final content = await file.readAsString();
      final trimmed = content.trim();
      return trimmed.isEmpty
          ? []
          : [
              [TextRun(trimmed)],
            ];
    }

    if (ext == 'docx') {
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final doc = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
      );
      final xml = XmlDocument.parse(
        String.fromCharCodes(doc.content as List<int>),
      );

      final paragraphs = <List<TextRun>>[];
      for (final para in xml.findAllElements('w:p')) {
        final text = _extractDocxParagraphText(para).trim();
        if (text.isNotEmpty) {
          paragraphs.add([TextRun(text)]);
        }
      }
      return paragraphs;
    }

    if (ext == 'pdf') {
      final doc = PdfDocument(inputBytes: await file.readAsBytes());
      final extractor = PdfTextExtractor(doc);
      final lines = extractor.extractTextLines();
      final paragraphs = <List<TextRun>>[];
      var currentParagraph = <TextRun>[];
      var previousLine = '';

      for (final line in lines) {
        final lineText = line.text.trim();
        if (lineText.isEmpty) {
          if (currentParagraph.isNotEmpty) {
            paragraphs.add(currentParagraph);
            currentParagraph = [];
          }
          previousLine = '';
          continue;
        }

        final lineRuns = _runsForTextLine(line);
        if (currentParagraph.isEmpty) {
          currentParagraph = [...lineRuns];
        } else if (_shouldJoinPdfLine(previousLine, lineText)) {
          if (previousLine.endsWith('-') && currentParagraph.isNotEmpty) {
            final lastRun = currentParagraph.removeLast();
            final mergedText = lastRun.text.replaceFirst(RegExp(r'-$'), '');
            if (mergedText.isNotEmpty) {
              currentParagraph.add(TextRun(mergedText, isBold: lastRun.isBold));
            }
          } else {
            currentParagraph.add(TextRun(' '));
          }
          currentParagraph.addAll(lineRuns);
        } else {
          paragraphs.add(currentParagraph);
          currentParagraph = [...lineRuns];
        }

        previousLine = lineText;
      }

      if (currentParagraph.isNotEmpty) {
        paragraphs.add(currentParagraph);
      }

      doc.dispose();
      return paragraphs;
    }

    if (['jpg', 'jpeg', 'png'].contains(ext)) {
      final input = mlkit.InputImage.fromFile(file);
      final recognizer = mlkit.TextRecognizer();
      final result = await recognizer.processImage(input);
      await recognizer.close();
      final text = result.text.trim();
      return text.isEmpty
          ? []
          : [
              [TextRun(text)],
            ];
    }

    return [];
  }

  static List<TextRun> _runsForTextLine(TextLine line) {
    final runs = <TextRun>[];
    for (var i = 0; i < line.wordCollection.length; i++) {
      final word = line.wordCollection[i];
      if (i > 0) {
        runs.add(TextRun(' '));
      }
      runs.add(
        TextRun(word.text, isBold: word.fontStyle.contains(PdfFontStyle.bold)),
      );
    }
    if (runs.isEmpty && line.text.trim().isNotEmpty) {
      runs.add(TextRun(line.text.trim()));
    }
    return runs;
  }

  static bool _shouldJoinPdfLine(String previous, String current) {
    if (previous.isEmpty) return false;
    if (previous.endsWith('-')) return true;
    if (RegExp(r'[.!?;:]$').hasMatch(previous)) return false;
    if (current.length < 4 && current == current.toUpperCase()) return false;
    return true;
  }

  /// Splits text into clean paragraphs (double newline separated)
  static List<String> toParagraphs(String text) {
    return text
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.replaceAll('\n', ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Splits a paragraph into sentences — handles Dr., Mr., decimals, etc.
  static List<String> toSentences(String paragraph) {
    // Split on . ! ? but NOT on abbreviations like Dr. Mr. etc. or decimals
    final parts = paragraph.splitMapJoin(
      RegExp(r'(?<=[^A-Z][.!?])\s+(?=[A-Z])'),
      onMatch: (m) => '\n',
      onNonMatch: (s) => s,
    );
    return parts
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Normalizes whitespace and removes junk characters from OCR/extraction
  static String _clean(String raw) {
    return raw
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201A', "'")
        .replaceAll('\u201B', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u201E', '"')
        .replaceAll('\u201F', '"')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2015', '-')
        .replaceAll('\u2212', '-')
        .replaceAll('\u2026', '...')
        .replaceAll(RegExp(r'[ \t]+'), ' ') // collapse spaces/tabs
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // max 2 newlines
        .replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '')
        .trim();
  }

  static String _extractDocxParagraphText(XmlElement paragraph) {
    final buffer = StringBuffer();

    void walk(XmlNode node) {
      if (node is XmlText) {
        buffer.write(node.value);
      } else if (node is XmlElement) {
        final name = node.name.local;
        switch (name) {
          case 't':
            buffer.write(node.innerText);
            break;
          case 'tab':
            buffer.write('    ');
            break;
          case 'br':
          case 'cr':
          case 'cr2':
            buffer.write('\n');
            break;
          case 'sym':
            final charCode = node.getAttribute('w:char') ?? node.getAttribute('char');
            if (charCode != null) {
              final code = int.tryParse(charCode, radix: 16);
              if (code != null) {
                buffer.write(String.fromCharCode(code));
                break;
              }
            }
            buffer.write(node.innerText);
            break;
          default:
            node.children.forEach(walk);
            break;
        }
      }
    }

    paragraph.children.forEach(walk);
    return buffer.toString();
  }

  static String _normalizePdfText(String raw) {
    if (raw.trim().isEmpty) return '';

    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final buffer = StringBuffer();
    var previous = '';

    bool isSentenceBoundary(String text) {
      return RegExp(r'[.!?;:]$').hasMatch(text);
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
          buffer.write('\n\n');
        }
        previous = '';
        continue;
      }

      if (buffer.isNotEmpty) {
        if (previous.endsWith('-')) {
          buffer.write(line);
        } else if (RegExp(r'^[a-z0-9]').hasMatch(line) &&
            !isSentenceBoundary(previous)) {
          buffer.write(' ');
          buffer.write(line);
        } else {
          buffer.write('\n');
          buffer.write(line);
        }
      } else {
        buffer.write(line);
      }

      previous = line;
    }

    return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
