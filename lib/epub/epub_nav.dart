part of epub_package;

/// Represents a Nav Label
class NavLabel {
  NavLabel(this.text);

  final String text;
  final audio = <String, String>{};
  final img = <String, String>{};

  /// Constructs from XML version
  static NavLabel fromXmlElement(xml.XmlElement el) {
    final text = el.findElements('text');
    final label = NavLabel(text.isEmpty ? null : text.first.text?.trim());
    final audio = el.findElements('audio');
    if (audio.isNotEmpty) {
      audio.first.attributes.forEach((attr) {
        label.audio[attr.name.toString()] = attr.value;
      });
    }
    final img = el.findElements('img');
    if (img.isNotEmpty) {
      img.first.attributes.forEach((attr) {
        label.img[attr.name.toString()] = attr.value;
      });
    }
    return label;
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'audio': audio,
        'img': img,
      };

  NavLabel.fromJson(Map<String, dynamic> json) : text = json['text'] {
    audio.addAll(_as.map(json['audio']));
    img.addAll(_as.map(json['img']));
  }
}

/// Represents a Nav Point
class NavPoint {
  NavPoint({
    this.id,
    this.klass,
    this.playOrder,
    this.labels,
    this.content,
    this.children,
  });

  final String id;
  final String klass;
  final String content;
  final int playOrder;
  final List<NavLabel> labels;
  final List<NavPoint> children;

  NavPoint prevSibling;
  NavPoint nextSibling;
  NavPoint parent;
  NavPoint prev;
  NavPoint next;
  int index;
  int level;

  String get label => labels.first?.text;
  bool get isLink => content != null;

  NavPoint linkNext() {
    final next = _findNext();
    if (next == null) return null;

    next.prev = this;
    this.next = next;
    return next;
  }

  NavPoint _findNext() {
    if (children.isNotEmpty) return children.first;

    var current = this;
    while (current != null) {
      final next = current.nextSibling;
      if (next != null) return next;
      current = current.parent;
    }
    return null;
  }

  static void linkSiblings(List<NavPoint> points,
      {int level = 0, NavPoint parent = null}) {
    for (int i = 1, size = points.length; i < size; i += 1) {
      final prev = points[i - 1];
      final next = points[i];
      prev.nextSibling = next;
      next.prevSibling = prev;
      next.parent = parent;
      next.level = level;
    }

    if (points.isNotEmpty) {
      final point = points[0];
      point.parent = parent;
      point.level = level;
    }

    points.forEach((point) {
      linkSiblings(point.children, parent: point, level: level + 1);
    });
  }

  /// Constructs a tree-structure from <li> in HTML
  static NavPoint fromHtmlLi(String baseDir, dom.Element el) {
    final a = el.querySelector('a');
    final span = el.querySelector('span');
    final label = (a?.text ?? span?.text)?.trim();
    final content = (a.attributes ?? const {})['href'];

    return NavPoint(
      labels: [NavLabel(label)],
      content: content == null ? null : pathJoin([baseDir, content]),
      children: htmlOlToList(baseDir, el.querySelector('ol')),
    );
  }

  /// Parses <ol> in HTML and convert it to `List<NavPoint>`
  static List<NavPoint> htmlOlToList(String baseDir, dom.Element el) =>
      el == null
          ? []
          : el.children.map((li) => NavPoint.fromHtmlLi(baseDir, li)).toList();

  /// Constructs frm XML version
  static NavPoint fromXmlElement(String baseDir, xml.XmlElement el) => NavPoint(
      id: el.getAttribute('id'),
      klass: el.getAttribute('class'),
      playOrder: int.parse(el.getAttribute('playOrder')),
      labels: List.from(
          el.findElements('navLabel').map((el) => NavLabel.fromXmlElement(el))),
      content: pathJoin(
          [baseDir, el.findElements('content').first.getAttribute('src')]),
      children: List.from(el
          .findElements('navPoint')
          .map((el) => fromXmlElement(baseDir, el))));

  Map<String, dynamic> toJson() => {
        'id': id,
        'playOrder': playOrder,
        'label': label,
        'content': content,
        'children': children,
        'klass': klass,
        'labels': labels,
      };

  NavPoint.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        playOrder = json['playOrder'],
        content = json['content'],
        klass = json['klass'],
        labels =
            (json['labels'] as List).map((j) => NavLabel.fromJson(j)).toList(),
        children = (json['children'] as List)
            .map((j) => NavPoint.fromJson(j))
            .toList();
}

/// Represents Nav
class EpubNav extends _EpubXmlBase {
  EpubNav._(this._type, String basepath)
      : _basepath = basepath.replaceAll('\\', '/');

  final String _basepath;
  final String _type;
  String _title;
  final _authors = <String>[];
  final _navMapList = <NavPoint>[];
  final _idNavMap = <String, NavPoint>{};

  String get basepath => _basepath;
  String get title => _title;
  List<String> get authors => _authors;
  List<NavPoint> get navMapList => _navMapList;

  Map<String, dynamic> toJson() => {
        'type': _type,
        'basepath': basepath,
        'title': title,
        'authors': authors,
        'navMapList': navMapList,
      };

  int _count;
  int get count => _count;
  NavPoint get first => _navMapList.first;

  void linkPoints() {
    NavPoint.linkSiblings(_navMapList);
    var point = first;
    var index = 0;
    while (point != null) {
      point.index = index;
      _idNavMap[point.id] = point;
      point = point.linkNext();
      index += 1;
    }
    _count = index;
  }

  NavPoint findById(String id) => _idNavMap[id];

  void _loadFromJson(Map<String, dynamic> json) {
    _title = json['title'];
    _authors.addAll(_as.list(json['authors']));
    _navMapList
        .addAll((json['navMapList'] as List).map((j) => NavPoint.fromJson(j)));
    linkPoints();
  }

  static EpubNav loadFromJson(Map<String, dynamic> json) {
    if (json == null) return null;

    final String type = json['type'];
    if (type != 'nav' && type != 'ncx') return null;

    final nav = EpubNav._(type, json['basepath']);
    nav._loadFromJson(json);
    return nav;
  }

  /// Converts from Epub Nav
  /// read more: http://www.idpf.org/epub/31/spec/epub-packages.html#sec-package-nav-def
  static EpubNav fromNav(String dirname, String xmlStr) {
    if (xmlStr == null) return null;

    final nav = EpubNav._('nav', dirname);
    final root = nav._getHtmlRoot(xmlStr);
    nav._title = root.head.querySelector('title')?.text;
    nav._navMapList.addAll(
        NavPoint.htmlOlToList(nav._basepath, root.querySelector('nav > ol')));
    nav.linkPoints();
    return nav;
  }

  static String _getDocText(xml.XmlElement node) {
    if (node == null) return null;

    final text = node.findElements('text').first;
    return text == null ? null : text.text?.trim();
  }

  /// Converts from Epub NCX
  /// read more: http://www.daisy.org/z3986/2005/Z3986-2005.html
  static EpubNav fromNcx(String dirname, String xmlStr) {
    if (xmlStr == null) return null;

    final nav = EpubNav._('nav', dirname);
    final root = nav._getXmlRoot(xmlStr);

    // load meta
    // root.findElements('head').first

    // loadDocAttributes
    nav._title = _getDocText(root.findElements('docTitle').first);
    nav._authors.addAll(root.findElements('docAuthor').map(_getDocText));

    // loadNavMapList
    final navMapList = root.findElements('navMap').first;
    if (navMapList != null) {
      nav._navMapList.addAll(navMapList
          .findElements('navPoint')
          .map((el) => NavPoint.fromXmlElement(nav._basepath, el)));
    }

    nav.linkPoints();
    return nav;
  }

  /// Parses and converts from Nav
  static Future<EpubNav> fromNavDoc(EpubDocument doc) async =>
      doc == null ? null : fromNav(doc.dirname, await doc.readText());

  /// Parses and converts from NCX
  static Future<EpubNav> fromNcxDoc(EpubDocument doc) async =>
      doc == null ? null : fromNcx(doc.dirname, await doc.readText());
}
