import 'dart:convert';

class JsonBufferHelper {
  String _buffer = '';
  
  void addChunk(String chunk) {
    chunk = chunk.replaceAll('\x00', '').trim();
    _buffer += chunk;
  }
  
  List<Map<String, dynamic>> extractCompleteJsons() {
    List<Map<String, dynamic>> results = [];
    _cleanBuffer();
    
    while (_buffer.isNotEmpty) {
      JsonParseResult? result = _findCompleteJson(_buffer);
      if (result == null) break;
      
      String jsonStr = result.json;
      
      try {
        final decoded = jsonDecode(jsonStr);
        final converted = _convertNumbers(decoded);
        
        if (converted is Map<String, dynamic>) {
          results.add(converted);
        } else if (converted is Map) {
          results.add(converted.cast<String, dynamic>());
        }
      } catch (e) {
        final fixedJson = _tryFixJson(jsonStr);
        try {
          final decoded = jsonDecode(fixedJson);
          final converted = _convertNumbers(decoded);
          
          if (converted is Map<String, dynamic>) {
            results.add(converted);
          } else if (converted is Map) {
            results.add(converted.cast<String, dynamic>());
          }
        } catch (e2) {}
      }
      
      _buffer = _buffer.substring(result.endIndex + 1).trimLeft();
    }
    
    return results;
  }
  
  JsonParseResult? _findCompleteJson(String text) {
    int braceCount = 0;
    bool inString = false;
    bool escaped = false;
    int startIndex = -1;
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      
      if (escaped) {
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        continue;
      }
      
      if (char == '"' && !escaped) {
        inString = !inString;
        continue;
      }
      
      if (!inString) {
        if (char == '{') {
          if (braceCount == 0) {
            startIndex = i;
          }
          braceCount++;
        } else if (char == '}') {
          braceCount--;
          
          if (braceCount == 0 && startIndex != -1) {
            return JsonParseResult(
              json: text.substring(startIndex, i + 1),
              startIndex: startIndex,
              endIndex: i,
            );
          } else if (braceCount < 0) {
            return null;
          }
        }
      }
    }
    
    return null; 
  }
  
  dynamic _convertNumbers(dynamic value) {
    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((key, val) {
        result[key.toString()] = _convertNumbers(val);
      });
      return result;
    } else if (value is List) {
      return value.map(_convertNumbers).toList();
    } else if (value is String) {
      if (_isNumeric(value)) {
        if (value.contains('.') || value.contains('e') || value.contains('E')) {
          try {
            return double.parse(value);
          } catch (_) {
            return value;
          }
        } else {
          try {
            return int.parse(value);
          } catch (_) {
            return value;
          }
        }
      }
      return value;
    }
    return value;
  }
  
  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    final numericRegex = RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$');
    return numericRegex.hasMatch(str);
  }
  
  String _tryFixJson(String jsonStr) {
    String working = jsonStr.trim();
    
    int openBraces = '${working.split('{').length - 1}' as int;
    int closeBraces = '${working.split('}').length - 1}' as int;
    
    if (working.contains('"velocity":{"kmh":0')) {
      if (!working.endsWith('}}')) {
        if (working.endsWith('}')) {
          working += '}';
        } else {
          working += '}}';
        }
      }
    }
    
    while (closeBraces > openBraces && working.endsWith('}')) {
      working = working.substring(0, working.length - 1);
      closeBraces = '${working.split('}').length - 1}' as int;
    }
    
    while (openBraces > closeBraces) {
      working += '}';
      closeBraces = '${working.split('}').length - 1}' as int;
    }
    
    return working;
  }
  
  void _cleanBuffer() {
    int firstBrace = _buffer.indexOf('{');
    if (firstBrace > 0) {
      _buffer = _buffer.substring(firstBrace);
    }
  }
  
  void clear() {
    _buffer = '';
  }
  
  int get bufferLength => _buffer.length;
  
  String get bufferPreview => _buffer.length > 100 
      ? '${_buffer.substring(0, 100)}...' 
      : _buffer;
}

class JsonParseResult {
  final String json;
  final int startIndex;
  final int endIndex;
  
  JsonParseResult({
    required this.json,
    required this.startIndex,
    required this.endIndex,
  });
}