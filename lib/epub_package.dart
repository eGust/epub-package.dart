library epub_package;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;
import 'package:path/path.dart' as p;

part 'epub/epub_asset.dart';
part 'epub/epub_meta.dart';
part 'epub/epub_nav.dart';
part 'epub/epub_package.dart';
part 'zip/file_buffer.dart';
part 'zip/zip_header.dart';
part 'zip/zip_package.dart';
