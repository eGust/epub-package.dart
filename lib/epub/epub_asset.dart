part of epub_package;

final _pathRegEx = RegExp(r'[^\\/]');

class _Convert<T> {
  const _Convert();

  Map<String, T> map(Map<String, dynamic> json) =>
      json.map((k, v) => MapEntry<String, T>(k, v));

  Iterable<T> list(List json) => json.map((v) => v as T);
}

const _as = _Convert<String>();

String pathJoin(List<String> paths) {
  final parts = paths.where((s) => s != null && s.isNotEmpty).toList();
  final lastIndex = parts.length - 1;
  for (var i = 0; i <= lastIndex; i += 1) {
    final part = parts[i];
    parts[i] = part.substring(
      i == 0 ? 0 : part.indexOf(_pathRegEx),
      i == lastIndex ? part.length : part.lastIndexOf(_pathRegEx) + 1,
    );
  }

  return p
      .normalize(parts.where((s) => s.isNotEmpty).join('/'))
      .replaceAll('\\', '/');
}

class EpubFile {
  EpubFile(this.filename, this._offsetStart, this._offsetEnd, this._method);

  final String filename;
  final int _offsetStart;
  final int _offsetEnd;
  final int _method;

  Stream<List<int>> toStream(File file) => ZipPackage.extract(
        file,
        start: _offsetStart,
        end: _offsetEnd,
        compressionMethod: _method,
      );

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'offsetStart': _offsetStart,
        'offsetEnd': _offsetEnd,
        'compressedMethod': _method,
      };

  EpubFile.fromJson(Map<String, dynamic> json)
      : filename = json['filename'],
        _offsetStart = json['offsetStart'],
        _offsetEnd = json['offsetEnd'],
        _method = json['compressedMethod'];
}

class XmlTag {
  XmlTag(this.name, this.text);
  final String name;
  final String text;
  final attrs = <String, String>{};

  Map<String, dynamic> toJson() => {
        'name': name,
        'text': text,
        'attrs': attrs,
      };

  XmlTag.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        text = json['text'] {
    attrs.addAll(_as.map(json['attrs']));
  }
}

class EpubXmlBase {
  xml.XmlElement _getXmlRoot(String xmlStr) => xml.parse(xmlStr).rootElement;
  dom.Document _getHtmlRoot(String xmlStr) => html.parse(xmlStr);

  Iterable<xml.XmlElement> _childElements(xml.XmlElement parent) =>
      parent.children
          .map((node) => node is xml.XmlElement ? node : null)
          .where((n) => n != null);
}

class EpubAsset {
  EpubAsset(this.id, this.href, this.mediaType, String basePath)
      : filename = pathJoin([basePath, href]);
  final String id;
  final String href;
  final String mediaType;
  final String filename;

  final optional = <String, String>{};

  String relativePath(String path) => pathJoin([p.dirname(filename), path]);

  Map<String, dynamic> toJson() => {
        'id': id,
        'href': href,
        'filename': filename,
        'mediaType': mediaType,
        'optional': optional,
      };

  EpubAsset.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        href = json['href'],
        filename = json['filename'],
        mediaType = json['mediaType'] {
    optional.addAll(_as.map(json['optional']));
  }
}

class EpubDocument {
  EpubDocument({
    this.package,
    this.id,
    this.filename,
  }) : dirname = p.dirname(filename);

  final String id;
  final String dirname;
  final String filename;
  final EpubPackage package;

  static EpubDocument fromAsset(EpubAsset asset, EpubPackage package) =>
      asset == null
          ? null
          : EpubDocument(
              package: package,
              id: asset.id,
              filename: asset.filename,
            );

  Future<Stream<List<int>>> readStream() => package.readStream(filename);

  Future<List<int>> readAsBytes() => package.readAsBytes(filename);

  Future<String> readText({Converter<List<int>, String> decoder}) =>
      package.readText(filename, decoder: decoder);

  EpubDocument getReletiveDoc(String relativePath) =>
      package.getDocumentByPath(pathJoin([dirname, relativePath]));

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'package': package.file.path,
      };
}
