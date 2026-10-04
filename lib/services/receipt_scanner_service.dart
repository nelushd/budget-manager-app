import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/receipt_scan_result.dart';

class ReceiptScannerService {
  ReceiptScannerService._();

  static final ReceiptScannerService instance =
      ReceiptScannerService._();

  final ImagePicker _imagePicker = ImagePicker();

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

      print(recognizedText.text.trim());

      return _parseReceipt(recognizedText);
    } finally {
      await textRecognizer.close();
    }
  }
  ReceiptScanResult _parseReceipt(RecognizedText recognizedText) {

    final String rawText = recognizedText.text.trim();
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

  static final RegExp _amountPattern = RegExp(
    r'(\d{1,3}(?:[, ]\d{3})*(?:\.\d{2})|\d+\.\d{2})',
  );

  static const List<String> _ignoreKeywords = [
    'cash',
    'paid',
    'balance',
    'change',
  ];

  static const List<String> _totalKeywords = [
   'grand total',
  'total invoice value',
  'bill total',
  'total due',
  'amount due',
  'net total',
  'total amount',
  'bill amount',
  'bill amt',
  'full amount',
  'total lkr',
  'total rs',
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

    final List<double> possibleAmounts = [];

    for (final TextLine line in lines) {
      for (final RegExpMatch match
          in _amountPattern.allMatches(line.text)) {
        final double? value = _parseAmount(match.group(1)!);
        if (value != null &&
            value > 0 &&
            !_isImplausibleAmount(value)) {
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

  double? _findNearbyAmount({
    required List<TextLine> lines,
    required TextLine keywordLine,
    required String keyword,
  }) {
    final Rect keywordBox = keywordLine.boundingBox;

    final List<TextLine> sameRowCandidates = [];

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

  bool _shouldIgnoreLine(TextLine line, String keyword) {
    if (keyword == 'cash') {
      return false;
    }

    final String lower = line.text.toLowerCase();
    return _ignoreKeywords.any((kw) => lower.contains(kw));
  }

  bool _isSameRow(Rect a, Rect b) {
    final double aCenterY = a.top + (a.height / 2);
    final double bCenterY = b.top + (b.height / 2);

    final double tolerance =
        ((a.height + b.height) / 4).clamp(10.0, 30.0);

    return (aCenterY - bCenterY).abs() <= tolerance;
  }
  double? _extractAmountFromLine(TextLine line) {
    final List<double> plausibleValues = [];

    for (final RegExpMatch match in _amountPattern.allMatches(line.text)) {
      final double? value = _parseAmount(match.group(1)!);
      if (value != null && !_isImplausibleAmount(value)) {
        plausibleValues.add(value);
      }
    }

    if (plausibleValues.isEmpty) {
      return null;
    }
    return plausibleValues.last;
  }

  double? _parseAmount(String rawAmount) {
    final String cleaned = rawAmount.replaceAll(RegExp(r'[,\s]'), '');
    return double.tryParse(cleaned);
  }

  bool _isImplausibleAmount(double value) {
    final int wholePart = value.truncate();
    final int centsPart = ((value - wholePart) * 100).round();

    final bool looksLikeYearMonth = wholePart >= 1900 &&
        wholePart <= 2099 &&
        centsPart >= 1 &&
        centsPart <= 12;

    if (looksLikeYearMonth) {
      return true;
    }

    const double minPlausibleAmount = 10;
    return value < minPlausibleAmount;
  }


  static const Map<String, int> _monthNamesToNumber = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  DateTime? _extractDate(String text) {

    final DateTime? monthNameDate = _extractMonthNameDate(text);
    if (monthNameDate != null) {
      return monthNameDate;
    }

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

  DateTime? _extractMonthNameDate(String text) {
    final RegExp dayMonthYear = RegExp(
      r'\b(\d{1,2})[-\s]+([A-Za-z]{3,9})[-,\s]+(\d{4})\b',
      caseSensitive: false,
    );

    final RegExpMatch? dayMonthYearMatch = dayMonthYear.firstMatch(text);
    if (dayMonthYearMatch != null) {
      final int? month = _monthNamesToNumber[
          dayMonthYearMatch.group(2)!.toLowerCase()];
      if (month != null) {
        final DateTime? validDate = _createValidDate(
          int.parse(dayMonthYearMatch.group(3)!),
          month,
          int.parse(dayMonthYearMatch.group(1)!),
        );
        if (validDate != null) {
          return validDate;
        }
      }
    }

    final RegExp monthDayYear = RegExp(
      r'\b([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})\b',
      caseSensitive: false,
    );

    final RegExpMatch? monthDayYearMatch = monthDayYear.firstMatch(text);
    if (monthDayYearMatch != null) {
      final int? month = _monthNamesToNumber[
          monthDayYearMatch.group(1)!.toLowerCase()];
      if (month != null) {
        final DateTime? validDate = _createValidDate(
          int.parse(monthDayYearMatch.group(3)!),
          month,
          int.parse(monthDayYearMatch.group(2)!),
        );
        if (validDate != null) {
          return validDate;
        }
      }
    }

    return null;
  }

  TimeOfDay? _extractTime(String text) {
    final RegExp twelveHourPattern = RegExp(
      r'\b(\d{1,2})[:.](\d{2})(?::\d{2})?\s*(AM|PM)\b',
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