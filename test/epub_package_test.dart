import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

import 'package:epub_package/epub_package.dart';

import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart' as xml;

void main() async {
  // await testXml();
  await testPackages();
  // test('adds one to input values', () {
  //   final calculator = Calculator();
  //   expect(calculator.addOne(2), 3);
  //   expect(calculator.addOne(-7), -6);
  //   expect(calculator.addOne(0), 1);
  //   expect(() => calculator.addOne(null), throwsNoSuchMethodError);
  // });
}

void testPackages() async {
  const files = [
    'A-Room-with-a-View-morrison.epub',
    'Beyond-Good-and-Evil-Galbraithcolor.epub',
    'epub31-v31-20170105.epub',
    'Metamorphosis-jackson.epub',
    'The-Prince-1397058899.epub',
    'The-Problems-of-Philosophy-LewisTheme.epub',
    'huge/jy.epub',
  ];

  final packages =
      files.map((fn) => EpubPackage(File('test/epubs/$fn'))).toList();

  final results = await Future.wait(packages.map((pkg) async {
    final start = DateTime.now();
    await pkg.load();
    final stop = DateTime.now();
    return {
      'start': start,
      'stop': stop,
      'package': pkg,
    };
  }));

  await Future.wait(results.map((h) async {
    final DateTime start = h['start'];
    final DateTime stop = h['stop'];
    final EpubPackage pkg = h['package'];
    final ts = stop.difference(start);
    print('[time: $ts]\t${pkg.filePath}');
    // print(jsonEncode(pkg));
    final coverAsset = pkg.metadata.getCoverImageAsset();
    if (coverAsset != null) {
      final cover = pkg.getDocumentById(coverAsset.id);
      final bytes = await cover.readAsBytes();
      print('${coverAsset.filename}: ${bytes.length}');
    }
    print('\n');
  }));
}

void testPackage() async {
  print('started');
  final start = DateTime.now();
  final f = File('test/epubs/jy.epub');
  final package = EpubPackage(f);
  final succ = await package.load();
  final stop = DateTime.now();
  print('loaded: $succ');
  // print('$start - $stop');
  // print(jsonEncode(package));
  print('$start - $stop');
}

void testXml() async {
  final xmlStr = '''<?xml version="1.0" encoding="UTF-8" ?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/fb.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';
  // final doc = xml.parse(xmlStr);
  // final root = doc.rootElement;
  // final dom = root.findAllElements('rootfile').first;
  // print(dom.getAttribute('full-path'));

  // final opf = File('test/epubs/jy/OPS/fb.opf');
  // final meta =
  //     EpubMeta.fromXml('test/epubs/jy/OPS/fb.opf', opf.readAsStringSync());
  // print(jsonEncode(meta));

  final ncxFile = File('test/epubs/jy/OPS/fb.ncx');
  // final ncxXml = await ncxFile.readAsString();
  // final ncxDom = html.parse(ncxXml);
  // print(ncxDom.querySelector('head'));
  // print(ncxDom.querySelector('docTitle'));
  // print(ncxDom.querySelector('docAuthor'));
  // final navMap = ncxDom.querySelector('navMap');
  // print(navMap);
  // print(ncxDom.querySelectorAll('navMap > navPoint'));

  final ncx = EpubNav.fromNcx(ncxFile.path, await ncxFile.readAsString());
  print(jsonEncode(ncx));
}
