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

      final String rawText = recognizedText.text.trim();

      return _parseReceipt(rawText);
    } finally {
      await textRecognizer.close();
    }
  }

  ReceiptScanResult _parseReceipt(String rawText) {
    final List<String> lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return ReceiptScanResult(
      rawText: rawText,
      amount: _extractAmount(lines),
      title: _extractTitle(lines),
      category: _suggestCategory(rawText),
      date: _extractDate(rawText),
      time: _extractTime(rawText),
      notes: rawText.isEmpty
          ? null
          : 'Transaction details extracted from receipt.',
    );
  }

  double? _extractAmount(List<String> lines) {
    final RegExp amountPattern = RegExp(
      r'(?:LKR|Rs\.?|රු\.?)?\s*'
      r'(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{1,2})'
      r'|\d+\.\d{1,2})',
      caseSensitive: false,
    );

    const List<String> totalKeywords = [
      'grand total',
      'net total',
      'amount due',
      'total due',
      'balance due',
      'total',
    ];

    for (final String keyword in totalKeywords) {
      for (final String line in lines.reversed) {
        if (!line.toLowerCase().contains(keyword)) {
          continue;
        }

        final Iterable<RegExpMatch> matches =
            amountPattern.allMatches(line);

        if (matches.isNotEmpty) {
          final String amountText =
              matches.last.group(1)!.replaceAll(
            RegExp(r'[,\s]'),
            '',
          );

          return double.tryParse(amountText);
        }
      }
    }

    final List<double> possibleAmounts = [];

    for (final String line in lines) {
      for (final RegExpMatch match
          in amountPattern.allMatches(line)) {
        final String amountText =
            match.group(1)!.replaceAll(
          RegExp(r'[,\s]'),
          '',
        );

        final double? value = double.tryParse(amountText);

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

  String? _extractTitle(List<String> lines) {
    const List<String> ignoredWords = [
      'receipt',
      'invoice',
      'tax invoice',
      'cash receipt',
      'duplicate',
      'customer copy',
      'merchant copy',
      'thank you',
      'welcome',
    ];

    for (final String line in lines.take(8)) {
      final String lowercaseLine = line.toLowerCase();

      final bool shouldIgnore = ignoredWords.any(
        (word) => lowercaseLine == word ||
            lowercaseLine.contains(word),
      );

      if (shouldIgnore) {
        continue;
      }

      if (_looksLikeDate(line) ||
          _looksLikeTime(line) ||
          _looksLikeAmount(line)) {
        continue;
      }

      if (!RegExp(r'[A-Za-z]').hasMatch(line)) {
        continue;
      }

      if (line.length < 3 || line.length > 60) {
        continue;
      }

      return _formatTitle(line);
    }

    return null;
  }

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