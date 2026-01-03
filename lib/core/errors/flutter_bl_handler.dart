import 'dart:convert';

class JsonBufferHelper {
  String _buffer = '';
  
  void addChunk(String chunk) {
    _buffer += chunk;
    print('📦 Buffer added: ${chunk.length} chars');
  }
  
  List<Map<String, dynamic>> extractCompleteJsons() {
    final List<Map<String, dynamic>> completeJsons = [];
    
    try {
      while (_buffer.isNotEmpty) {
        final startIndex = _buffer.indexOf('{');
        if (startIndex == -1) {
          _buffer = '';
          break;
        }
        
        if (startIndex > 0) {
          _buffer = _buffer.substring(startIndex);
        }
        
        int braceCount = 0;
        int endIndex = -1;
        
        for (int i = 0; i < _buffer.length; i++) {
          if (_buffer[i] == '{') braceCount++;
          if (_buffer[i] == '}') {
            braceCount--;
            if (braceCount == 0) {
              endIndex = i;
              break;
            }
          }
        }
        
        if (endIndex != -1) {
          final jsonString = _buffer.substring(0, endIndex + 1);
          
          try {
            final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
            
            if (jsonData.containsKey('type') && 
                jsonData['type'] == 'telemetry' &&
                jsonData.containsKey('device_id')) {
              
              print('✅ EXTRACTED COMPLETE JSON: ${jsonString.length} chars');
              completeJsons.add(jsonData);
              _buffer = _buffer.substring(endIndex + 1);
              continue;
            } else {
              _buffer = _buffer.substring(endIndex + 1);
            }
          } catch (e) {
            final nextBrace = _buffer.indexOf('{', 1);
            _buffer = nextBrace != -1 ? _buffer.substring(nextBrace) : '';
          }
        } else {
          break;
        }
      }
      
      if (_buffer.length > 5000) {
        final lastBrace = _buffer.lastIndexOf('{');
        _buffer = lastBrace != -1 ? _buffer.substring(lastBrace) : '';
      }
      
    } catch (e) {
      print('❌ Buffer error: $e');
      _buffer = '';
    }
    
    return completeJsons;
  }
  
  int get bufferLength => _buffer.length;
  String get bufferPreview => _buffer.length > 100 ? '${_buffer.substring(0, 100)}...' : _buffer;
  void clear() => _buffer = '';
}