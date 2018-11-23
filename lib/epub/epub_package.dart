part of epub_package;

class EpubPackage {
  EpubPackage(this.file);

  final File file;
  final files = <String, EpubFile>{};

  EpubMeta _meta;
  EpubNav _nav;

  int _fileSize;
  int _timestamp;
  bool _unloaded = true;
  bool _properlyLoaded = false;

  String get filepath => file.path;
  EpubMeta get metadata => _meta;
  EpubNav get nav => _nav;

  int get fileSize => _fileSize;
  int get timestamp => _timestamp;
  bool get unloaded => _unloaded;
  bool get properlyLoaded => _properlyLoaded;

  static Future<int> getFileTimestamp(File file) async =>
      (await file.lastModified()).toUtc().microsecondsSinceEpoch;

  Future<void> _updateFileInfo() async {
    final sizes = await Future.wait([
      file.length(),
      getFileTimestamp(file),
    ]);

    _fileSize = sizes[0];
    _timestamp = sizes[1];
  }

  Future<bool> load() async {
    if (properlyLoaded) return true;

    _unloaded = false;
    if (!(await file.exists())) return false;

    await _loadZipFiles();
    if (!(await _checkMimeType())) return false;
    if (!(await _loadMeta())) return false;
    await Future.wait([
      _loadNav(),
      _updateFileInfo(),
    ]);
    _properlyLoaded = true;
    return true;
  }

  bool hasFile(String filename) => files.containsKey(filename);

  EpubDocument getDocumentByPath(String filename) =>
      EpubDocument.fromAsset(_meta.getItemByPath(filename), this) ??
      (hasFile(filename)
          ? EpubDocument(filename: filename, package: this)
          : null);

  EpubDocument getDoucmentById(String id) =>
      EpubDocument.fromAsset(_meta.getItemById(id), this);

  Future<Stream<List<int>>> readStream(String filename) async {
    final f = filename == null ? null : files[filename];
    return f == null ? null : await f.toStream(file);
  }

  Future<List<int>> readAsBytes(String filename) async =>
      (await readStream(filename))?.first;

  Future<String> readText(String filename,
      {Converter<List<int>, String> decoder}) async {
    final stream = await readStream(filename);
    return stream == null
        ? null
        : await stream.transform(decoder ?? utf8.decoder).join();
  }

  Future<String> assetAsUtf8(EpubAsset asset) => readText(asset?.filename);

  Future<void> _loadZipFiles() async {
    final zip = await ZipPackage.from(file);
    zip.entries.values.forEach((f) {
      files[f.filename] = EpubFile(
        f.filename,
        f.offsetEnd,
        f.offsetEnd + f.compressedSize,
        f.compressionMethod,
      );
    });
  }

  Future<bool> _checkMimeType() async {
    if (!hasFile('mimetype')) return false;

    final mimetype = await readText('mimetype');
    return mimetype != null && mimetype.trim() == 'application/epub+zip';
  }

  Future<bool> _loadMeta() async {
    if (!hasFile('META-INF/container.xml')) return false;

    final meta = await readText('META-INF/container.xml');
    if (meta == null) return false;

    final doc = html.parse(meta);
    final nodeRootfile = doc.querySelector('rootfile');
    if (nodeRootfile == null) return false;

    final opfPath = nodeRootfile.attributes['full-path'];
    if (opfPath == null || !hasFile(opfPath)) return false;

    _meta = await EpubMeta.load(this, opfPath);
    return _meta != null;
  }

  Future<void> _loadNav() async {
    _nav = (await EpubNav.fromNcxDoc(getDoucmentById('ncx'))) ??
        (await EpubNav.fromNavDoc(getDoucmentById('nav')));
  }

  static Future<EpubPackage> loadFromJson(Map<String, dynamic> json) async {
    if (!json['loaded']) return null;

    final filename = json['filename'];
    if (filename == null) return null;

    final file = File(filename);
    if (!(await file.exists())) return null;

    final sizes = await Future.wait([
      file.length(),
      getFileTimestamp(file),
    ]);
    if (sizes[0] != json['fileSize'] || sizes[1] != json['timestamp'])
      return null;

    final package = EpubPackage(file);
    return package._loadFromJson(json) ? package : null;
  }

  bool _loadFromJson(Map<String, dynamic> json) {
    if (_properlyLoaded) return true;

    _unloaded = false;
    _fileSize = json['fileSize'];
    _timestamp = json['timestamp'];

    files.addAll((json['files'] as Map<String, dynamic>)
        .map((key, val) => MapEntry(key, EpubFile.fromJson(val))));

    _meta = EpubMeta.fromJson(json['meta']);
    _nav = EpubNav.loadFromJson(json['nav']);
    _properlyLoaded = true;
    return true;
  }

  Map<String, dynamic> toJson() => properlyLoaded
      ? {
          'loaded': true,
          'filename': file.path,
          'fileSize': fileSize,
          'timestamp': timestamp,
          'files': files,
          'meta': _meta,
          'nav': _nav,
        }
      : {
          'filename': file.path,
          'loaded': false,
        };
}
