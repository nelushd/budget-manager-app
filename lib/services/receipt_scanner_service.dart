import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/receipt_scan_result.dart';

class ReceiptScannerService {
  ReceiptScannerService._();

  static final ReceiptScannerService instance =
      ReceiptScannerService._();

  final ImagePicker _imagePicker = ImagePicker();

  // ==========================================================
  // Camera / Gallery — UNCHANGED
  // ==========================================================

  Future<ReceiptScanResult?> scanFromCamera() async {
    return _pickAndProcessImage(ImageSource.camera);
  }

  Future<ReceiptScanResult?> scanFromGallery() async {
    return _pickAndProcessImage(ImageSource.gallery);
  }

  Future<ReceiptScanResult?> _pickAndProcessImage(
    ImageSource source,
  ) async {
    final XFile? selectedImage = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (selectedImage == null) {
      return null;
    }

    return processImage(selectedImage.path);
  }

  // ==========================================================
  // processImage() — pass the whole RecognizedText object
  // ==========================================================

  Future<ReceiptScanResult> processImage(
    String imagePath,
  ) async {
    final InputImage inputImage =
        InputImage.fromFilePath(imagePath);

    final TextRecognizer textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // ===== ADD THESE =====
      print("========== OCR RAW TEXT ==========");
      print(recognizedText.text.trim());
      print("==================================");
      // =====================

      return _parseReceipt(recognizedText);
    } finally {
      await textRecognizer.close();
    }
  }

  // ==========================================================
  // _parseReceipt() — now takes the full RecognizedText object
  // ==========================================================

  ReceiptScanResult _parseReceipt(RecognizedText recognizedText) {
    // Still required for date extraction, time extraction, and notes.
    final String rawText = recognizedText.text.trim();

    // Flatten every TextLine from every TextBlock into a single list.
    // TextBlocks are only used to obtain the TextLines — the extraction
    // algorithm itself does not rely on block grouping.
    final List<TextLine> allTextLines = [];
    for (final TextBlock block in recognizedText.blocks) {
      allTextLines.addAll(block.lines);
    }

    return ReceiptScanResult(
      rawText: rawText,
      amount: _extractAmount(allTextLines),
      category: null,
      date: _extractDate(rawText),
      time: _extractTime(rawText),
      notes: "Transaction details extracted from receipt.",
    );
  }

  // ==========================================================
  // Amount extraction — REWRITTEN to use List<TextLine>
  // ==========================================================

  static final RegExp _amountPattern = RegExp(
    r'(\d{1,3}(?:[, ]\d{3})*(?:\.\d{2})|\d+\.\d{2})',
  );

  static const List<String> _ignoreKeywords = [
    'cash',
    'paid',
    'balance',
    'change',
  ];

  // Exact priority order requested.
  static const List<String> _totalKeywords = [
    'grand total',
    'net total',
    'total amount',
    'total invoice value',
    'bill total',
    'transfer amount',
    'amount due',
    'total due',
    'amount (lkr)',
    'amount',
    'subtotal',
    'sub total',
    'total',
  ];

  double? _extractAmount(List<TextLine> lines) {
    for (final String keyword in _totalKeywords) {
      TextLine? keywordLine;

      for (final TextLine line in lines) {
        if (line.text.toLowerCase().contains(keyword)) {
          keywordLine = line;
          break;
        }
      }

      if (keywordLine == null) {
        continue;
      }

      final double? found = _findNearbyAmount(
        lines: lines,
        keywordLine: keywordLine,
        keyword: keyword,
      );

      if (found != null) {
        return found;
      }
    }

    // Fallback: no keyword found anywhere — return the largest monetary value.
    final List<double> possibleAmounts = [];

    for (final TextLine line in lines) {
      for (final RegExpMatch match
          in _amountPattern.allMatches(line.text)) {
        final double? value = _parseAmount(match.group(1)!);
        if (value != null && value > 0) {
          possibleAmounts.add(value);
        }
      }
    }

    if (possibleAmounts.isEmpty) {
      return null;
    }

    possibleAmounts.sort();
    return possibleAmounts.last;
  }

  /// Locates the best monetary amount associated with [keywordLine].
  ///
  /// Strategy:
  /// 1. Look at every TextLine on the same visual row as the keyword
  ///    (including the keyword's own line, e.g. "Total: 500.00").
  /// 2. Among same-row candidates, pick the one whose centerX is closest
  ///    to the keyword's centerX.
  /// 3. If nothing is found on the same row, check the next three
  ///    TextLines that appear below the keyword in the flattened list.
  double? _findNearbyAmount({
    required List<TextLine> lines,
    required TextLine keywordLine,
    required String keyword,
  }) {
    final Rect keywordBox = keywordLine.boundingBox;

    final List<TextLine> sameRowCandidates = [];

    // The keyword's own line may itself contain the amount.
    if (!_shouldIgnoreLine(keywordLine, keyword) &&
        _amountPattern.hasMatch(keywordLine.text)) {
      sameRowCandidates.add(keywordLine);
    }

    for (final TextLine line in lines) {
      if (identical(line, keywordLine)) {
        continue;
      }
      if (_shouldIgnoreLine(line, keyword)) {
        continue;
      }
      if (!_amountPattern.hasMatch(line.text)) {
        continue;
      }
      if (_isSameRow(keywordBox, line.boundingBox)) {
        sameRowCandidates.add(line);
      }
    }

    if (sameRowCandidates.isNotEmpty) {
      // Select the candidate whose centerX is horizontally closest
      // to the keyword's centerX.
      TextLine? closest;
      double closestDistance = double.infinity;
      final double keywordCenterX =
          keywordBox.left + (keywordBox.width / 2);

      for (final TextLine candidate in sameRowCandidates) {
        final Rect box = candidate.boundingBox;
        final double candidateCenterX = box.left + (box.width / 2);
        final double distance =
            (candidateCenterX - keywordCenterX).abs();

        if (distance < closestDistance) {
          closestDistance = distance;
          closest = candidate;
        }
      }

      final double? value =
          closest != null ? _extractAmountFromLine(closest) : null;

      if (value != null) {
        return value;
      }
    }

    // Nothing on the same row — search the next three TextLines below.
    final int keywordIndex = lines.indexOf(keywordLine);
    if (keywordIndex != -1) {
      int checked = 0;
      for (int i = keywordIndex + 1;
          i < lines.length && checked < 3;
          i++, checked++) {
        final TextLine candidate = lines[i];

        if (_shouldIgnoreLine(candidate, keyword)) {
          continue;
        }
        if (!_amountPattern.hasMatch(candidate.text)) {
          continue;
        }

        final double? value = _extractAmountFromLine(candidate);
        if (value != null) {
          return value;
        }
      }
    }

    return null;
  }

  /// True if [line] should be ignored for the current [keyword] search,
  /// because it contains one of the excluded terms (Cash/Paid/Balance/Change)
  /// — unless the keyword itself is "cash".
  bool _shouldIgnoreLine(TextLine line, String keyword) {
    if (keyword == 'cash') {
      return false;
    }

    final String lower = line.text.toLowerCase();
    return _ignoreKeywords.any((kw) => lower.contains(kw));
  }

  /// True if two bounding boxes are considered to be on the same visual row,
  /// based on how close their vertical centers are relative to their height.
  bool _isSameRow(Rect a, Rect b) {
    final double aCenterY = a.top + (a.height / 2);
    final double bCenterY = b.top + (b.height / 2);

    final double tolerance =
        ((a.height + b.height) / 4).clamp(10.0, 30.0);

    return (aCenterY - bCenterY).abs() <= tolerance;
  }

  /// Extracts the first valid monetary value from a single TextLine.
  double? _extractAmountFromLine(TextLine line) {
    final Iterable<RegExpMatch> matches =
        _amountPattern.allMatches(line.text);

    if (matches.isEmpty) {
      return null;
    }

    // Prefer the last monetary value on the line (commonly the actual
    // figure when a currency code/prefix precedes it).
    return _parseAmount(matches.last.group(1)!);
  }

  /// Parses a matched amount string (stripping thousands separators)
  /// into a double.
  double? _parseAmount(String rawAmount) {
    final String cleaned = rawAmount.replaceAll(RegExp(r'[,\s]'), '');
    return double.tryParse(cleaned);
  }

  // ==========================================================
  // Date extraction — UNCHANGED
  // ==========================================================

  DateTime? _extractDate(String text) {
    final List<RegExp> patterns = [
      RegExp(
        r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b',
      ),
      RegExp(
        r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b',
      ),
      RegExp(
        r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})\b',
      ),
    ];

    for (int index = 0; index < patterns.length; index++) {
      final RegExpMatch? match =
          patterns[index].firstMatch(text);

      if (match == null) {
        continue;
      }

      int year;
      int month;
      int day;

      if (index == 0) {
        year = int.parse(match.group(1)!);
        month = int.parse(match.group(2)!);
        day = int.parse(match.group(3)!);
      } else {
        day = int.parse(match.group(1)!);
        month = int.parse(match.group(2)!);
        year = int.parse(match.group(3)!);

        if (year < 100) {
          year += 2000;
        }
      }

      final DateTime? validDate =
          _createValidDate(year, month, day);

      if (validDate != null) {
        return validDate;
      }
    }

    return null;
  }

  // ==========================================================
  // Time extraction — UNCHANGED
  // ==========================================================

  TimeOfDay? _extractTime(String text) {
    final RegExp twelveHourPattern = RegExp(
      r'\b(\d{1,2})[:.](\d{2})\s*(AM|PM)\b',
      caseSensitive: false,
    );

    final RegExpMatch? twelveHourMatch =
        twelveHourPattern.firstMatch(text);

    if (twelveHourMatch != null) {
      int hour = int.parse(twelveHourMatch.group(1)!);
      final int minute =
          int.parse(twelveHourMatch.group(2)!);
      final String period =
          twelveHourMatch.group(3)!.toUpperCase();

      if (hour >= 1 && hour <= 12 &&
          minute >= 0 && minute <= 59) {
        if (period == 'PM' && hour != 12) {
          hour += 12;
        }

        if (period == 'AM' && hour == 12) {
          hour = 0;
        }

        return TimeOfDay(
          hour: hour,
          minute: minute,
        );
      }
    }

    final RegExp twentyFourHourPattern = RegExp(
      r'\b([01]?\d|2[0-3]):([0-5]\d)\b',
    );

    final RegExpMatch? twentyFourHourMatch =
        twentyFourHourPattern.firstMatch(text);

    if (twentyFourHourMatch != null) {
      return TimeOfDay(
        hour: int.parse(
          twentyFourHourMatch.group(1)!,
        ),
        minute: int.parse(
          twentyFourHourMatch.group(2)!,
        ),
      );
    }

    return null;
  }

  // ==========================================================
  // Category detection — kept intact (method preserved),
  // simply not used for the `category` field per the new requirement.
  // ==========================================================

  String? _suggestCategory(String text) {
    final String lowercaseText = text.toLowerCase();

    final Map<String, List<String>> categoryKeywords = {
      'Groceries': [
        'supermarket',
        'grocery',
        'cargills',
        'keells',
        'arpico',
        'food city',
        'laugfs',
        'glomark',
      ],
      'Dining': [
        'restaurant',
        'cafe',
        'coffee',
        'pizza',
        'burger',
        'kfc',
        'dominos',
        'food',
      ],
      'Fuel': [
        'fuel',
        'petrol',
        'diesel',
        'filling station',
        'ceypetco',
        'ioc',
      ],
      'Medicines': [
        'pharmacy',
        'medicine',
        'medical',
        'drugs',
        'healthguard',
      ],
      'Transport': [
        'uber',
        'pickme',
        'taxi',
        'bus',
        'train',
        'transport',
      ],
      'Clothing': [
        'fashion',
        'clothing',
        'apparel',
        'shirt',
        'dress',
        'shoes',
      ],
      'Electricity': [
        'electricity',
        'ceb',
        'leco',
      ],
      'Water': [
        'water board',
        'water bill',
        'nwsdb',
      ],
      'Phone': [
        'dialog',
        'mobitel',
        'hutch',
        'airtel',
        'reload',
        'mobile',
      ],
      'Internet': [
        'internet',
        'broadband',
        'fibre',
        'fiber',
        'wifi',
      ],
    };

    for (final MapEntry<String, List<String>> entry
        in categoryKeywords.entries) {
      final bool matches = entry.value.any(
        lowercaseText.contains,
      );

      if (matches) {
        return entry.key;
      }
    }

    return null;
  }

  bool _looksLikeDate(String text) {
    return RegExp(
      r'\b\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}\b',
    ).hasMatch(text);
  }

  bool _looksLikeTime(String text) {
    return RegExp(
      r'\b\d{1,2}[:.]\d{2}(?:\s*[AP]M)?\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  bool _looksLikeAmount(String text) {
    return RegExp(
      r'(?:LKR|Rs\.?|රු\.?)?\s*\d+[,.]\d{2}',
      caseSensitive: false,
    ).hasMatch(text);
  }

  String _formatTitle(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .map((word) {
      if (word.isEmpty) {
        return word;
      }

      return '${word[0].toUpperCase()}'
          '${word.substring(1).toLowerCase()}';
    })
        .join(' ');
  }

  // ==========================================================
  // _createValidDate() — UNCHANGED, kept as required
  // ==========================================================

  DateTime? _createValidDate(
    int year,
    int month,
    int day,
  ) {
    if (year < 2000 ||
        year > DateTime.now().year + 1 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }

    final DateTime date = DateTime(year, month, day);

    if (date.year != year ||
        date.month != month ||
        date.day != day) {
      return null;
    }

    return date;
  }
}