part of epub_package;

class ZipPackage {
  ZipPackage._(this.file);
  final File file;

  Map<String, ZipLocalFile> entries;
  List<ZipCentralDirectory> centralDirectories;
  ZipEndCentralDirectory cdEnd;

  Map<String, dynamic> toJson() => {
        'file': file.path,
        'entries': entries,
        'cdEnd': cdEnd,
        'centralDirectories': centralDirectories,
        'stopOffset': stopOffset,
      };

  int stopOffset;

  static Future<ZipPackage> from(File file) async {
    if (!(await file.exists())) return null;

    final zp = ZipPackage._(file);
    final package = await FileBuffer.from(file);
    try {
      final entries = <ZipLocalFile>[];
      final cds = <ZipCentralDirectory>[];

      while (!package.isEnd) {
        final pk = await package.readUint16();
        if (pk != 0x4b50) {
          // print(jsonEncode(zp));
          throw UnsupportedError('Unsupported format');
        }

        final sign = await package.readUint16();
        final header = await ZipHeader.readNext(package, sign);

        /*
        if (sign == 0x0806) {
          // 0608: Archive extra data record
          print('[Archive extra data record]');
          break;
        } else if (sign == 0x0505) {
          // 0505: Digital signature
          print('[Digital signature]');
          break;
        } else if (sign == 0x0606) {
          // 0x0606: Zip64 end of central directory record
          print('[Zip64 end of central directory record]');
          break;
        } else if (sign == 0x0706) {
          // 0x0607: Zip64 end of central directory locator
          print('[Zip64 end of central directory locator]');
          break;
        } else if (sign == 0x0605) {
          // 0x0506: End of central directory record
          print('[End of central directory record]');
          break;
        }
        */
        if (header == null) {
          throw UnsupportedError(
              'Unsupported Header: ${sign.toRadixString(16).padLeft(4, '0')}');
        }

        if (header.isCentralDirectoryEnd) {
          zp.cdEnd = header;
          zp.stopOffset = package.position;
          break;
        }

        if (header.isLocalFile) {
          final ZipLocalFile f = header;
          entries.add(f);
          package.addToPosition(f.compressedSize);
        } else if (header.isCentralDirectory) {
          final ZipCentralDirectory cd = header;
          cds.add(cd);
        }
      }

      zp.entries = Map.fromEntries(entries.map((f) => MapEntry(f.filename, f)));
      zp.centralDirectories = cds;
      return zp;
    } finally {
      package.close();
    }
  }

  static final zlibDecoder = ZLibDecoder(raw: true);

  static Stream<List<int>> extract(
    File file, {
    final int start,
    final int end,
    final int compressionMethod,
  }) {
    final stream = file.openRead(start, end);
    if (compressionMethod == 0) return stream;
    if (compressionMethod == 8) return stream.transform(zlibDecoder);

    throw UnsupportedError('Unsupported compress method: ${compressionMethod}');
  }

  static Stream<List<int>> raw(File file, {final int start, final int end}) =>
      file.openRead(start, end);

  Stream<List<int>> extractStream(String filename) {
    final zip = entries[filename];
    return zip == null
        ? null
        : extract(file,
            start: zip.offsetEnd,
            end: zip.offsetEnd + zip.compressedSize,
            compressionMethod: zip.compressionMethod);
  }

  Future<String> extractAsUtf8(String filename) {
    final stream = extractStream(filename);
    if (stream == null) return null;

    return stream.transform(utf8.decoder).join();
  }
}
