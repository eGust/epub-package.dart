part of epub_package;

/// Represents item in EPub `spine`
class EpubItemRef {
  EpubItemRef(
    this.idref, {
    this.linear = true,
    this.id,
    this.properties,
  });
  final String idref;
  final bool linear;
  final String id;
  final String properties;

  Map<String, dynamic> toJson() => {
        'idref': idref,
        'linear': linear,
        'id': id,
        'properties': properties,
      };

  EpubItemRef.fromJson(Map<String, dynamic> json)
      : idref = json['idref'],
        linear = json['linear'],
        id = json['id'],
        properties = json['properties'];
}

/// EPub meta data
/// read more: http://www.idpf.org/epub/31/spec/epub-packages.html
class EpubMeta extends _EpubXmlBase {
  final String filename;
  final String basePath;
  final meta = <XmlTag>[];
  final spine = <EpubItemRef>[];
  final items = <String, EpubAsset>{};
  final itemByPath = <String, EpubAsset>{};

  void _loadMetadata(xml.XmlElement root) {
    meta.addAll(_childElements(root).map((el) {
      final item = XmlTag(el.name.toString(), el.text);
      el.attributes.forEach((attr) {
        item.attrs[attr.name.toString()] = attr.text;
      });
      return item;
    }));
  }

  static final _requiredItemAttrs = Set.from(['id', 'href', 'media-type']);

  void _loadManifest(xml.XmlElement root) {
    _childElements(root).forEach((el) {
      final item = EpubAsset._(
        el.getAttribute('id'),
        el.getAttribute('href'),
        el.getAttribute('media-type'),
        basePath,
      );
      el.attributes.forEach((attrs) {
        final key = attrs.name.toString();
        if (_requiredItemAttrs.contains(key)) return;
        item.optional[key] = attrs.text;
      });
      items[item.id] = item;
      itemByPath[item.filename] = item;
    });
  }

  EpubAsset getItemById(String id) => items[id];
  EpubAsset getItemByPath(String path) => itemByPath[path];

  void _loadSpine(xml.XmlElement root) {
    spine.addAll(
      _childElements(root).map((el) => EpubItemRef(
            el.getAttribute('idref'),
            linear: el.getAttribute('linear') != 'no',
            id: el.getAttribute('id'),
            properties: el.getAttribute('properties'),
          )),
    );
  }

  /// Constructs from [xmlStr] and sets [filename]
  EpubMeta.fromXml(this.filename, String xmlStr)
      : basePath = p.dirname(filename) {
    final root = _getXmlRoot(xmlStr);
    _loadMetadata(root.findElements('metadata').first);
    _loadManifest(root.findElements('manifest').first);
    _loadSpine(root.findElements('spine').first);
  }

  /// Creates [EpubMeta] and load meta data from [filename] in [package]
  static Future<EpubMeta> load(EpubPackage package, String filename) async {
    final xmlStr = await package.readText(filename);
    return xmlStr == null ? null : EpubMeta.fromXml(filename, xmlStr);
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'basePath': basePath,
        'meta': meta,
        'spine': spine,
        'items': items.values.toList(),
      };

  EpubMeta.fromJson(Map<String, dynamic> json)
      : filename = json['filename'],
        basePath = json['basePath'] {
    meta.addAll((json['meta'] as List).map((j) => XmlTag.fromJson(j)));
    spine.addAll((json['meta'] as List).map((j) => EpubItemRef.fromJson(j)));
    (json['items'] as List).forEach((j) {
      final item = EpubAsset.fromJson(j);
      items[item.filename] = item;
    });
  }
}
