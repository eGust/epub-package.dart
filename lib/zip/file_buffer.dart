part of epub_package;

/// A simple buffer to read files efficiently.
class FileBuffer {
  FileBuffer._(this._file, this.length);

  /// Creates [FileBuffer] from [file]
  static Future<FileBuffer> from(File file) async {
    final args = await Future.wait([
      file.open(),
      file.length(),
    ]);
    return FileBuffer._(args[0], args[1]);
  }

  static const _BLOCK_SHIFT = 14; // 16KB
  static const _BLOCK_SIZE = 1 << _BLOCK_SHIFT;
  static const _BLOCK_MASK = _BLOCK_SIZE - 1;

  List<int> _buffer = List<int>(_BLOCK_SIZE);
  int _blockIndex = -1;

  final RandomAccessFile _file;

  /// Returns file size
  final int length;
  int _position = 0;
  int _fileBlockIndex = 0;

  /// Indicator whether current position reached the end
  bool get isEnd => position >= length;

  void _setPosition(int pos) {
    if (pos < 0) {
      _position = 0;
    } else if (pos > length) {
      _position = length;
    } else {
      _position = pos;
    }
  }

  /// Closes [file] object
  Future<void> close() => _file.close();

  /// Current [position]
  int get position => _position;
  set position(int value) {
    _setPosition(value < 0 ? length + value : value);
  }

  /// Move [position] by giving [delta] rather than set to an absolute value.
  void addToPosition(int delta) {
    _setPosition(position + delta);
  }

  int _normalizeCount(int count) {
    if (count <= 0) return 0;
    final remained = length - position;
    return count > remained ? remained : count;
  }

  Future<List<int>> _read(final int count) async {
    final result = List<int>(count);
    if (count == 0) return result;

    var start = 0;
    var blkIndexStart = _position >> _BLOCK_SHIFT;
    var blkOffsetStart = _position & _BLOCK_MASK;
    final end = _position + count;
    if (blkIndexStart == _blockIndex) {
      // read from current buffer
      final remained = _BLOCK_SIZE - blkOffsetStart;
      start = count > remained ? remained : count;
      result.setRange(0, start, _buffer, blkOffsetStart);

      _position += start;
      if (_position >= end) return result;

      blkIndexStart += 1;
      blkOffsetStart = 0;
    }

    final blkIndexEnd = end >> _BLOCK_SHIFT;
    final lastBlockPos = blkIndexEnd << _BLOCK_SHIFT;
    // directly read blocks
    if (blkIndexStart != blkIndexEnd) {
      if (_blockIndex != _fileBlockIndex) {
        await _file.setPosition(_position);
      }

      final stopOffset = lastBlockPos - _position;
      await _file.readInto(result, start, stopOffset);
      start = stopOffset;
      blkOffsetStart = 0;
    } else {
      if (_fileBlockIndex != blkIndexEnd) {
        await _file.setPosition(lastBlockPos);
      }
    }

    // read to buffer
    await _file.readInto(_buffer, 0, _BLOCK_SIZE);
    _blockIndex = blkIndexEnd;
    _fileBlockIndex = blkIndexEnd + 1;

    result.setRange(start, count, _buffer, blkOffsetStart);
    _position = end;
    return result;
  }

  /// Reads [count] bytes from current [position].
  Future<List<int>> read([final int count = 1]) =>
      _read(_normalizeCount(count));

  /// Reads 1 byte as unsigned int8 from current [position].
  Future<int> readByte() async {
    final buff = await read();
    return buff[0];
  }

  /// Reads 2 bytes as unsigned int16 from current [position].
  Future<int> readUint16() async {
    final buff = await read(2);
    final b0 = buff[0] & 0xff;
    final b1 = buff[1] & 0xff;
    return (b1 << 8) | b0;
  }

  /// Reads 4 bytes as unsigned int32 from current [position].
  Future<int> readUint32() async {
    final buff = await read(4);
    final b0 = buff[0] & 0xff;
    final b1 = buff[1] & 0xff;
    final b2 = buff[2] & 0xff;
    final b3 = buff[3] & 0xff;
    return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
  }

  /// Reads [count] bytes as UTF-8 string from current [position].
  Future<String> readUtf8(int count) async => utf8.decode(await read(count));
}
