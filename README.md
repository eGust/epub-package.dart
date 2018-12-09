# epub_package

Yet another EPub package for Flutter.

## Why another EPUB package?

You may already noticed, there is an awesome [epub](https://pub.dartlang.org/packages/epub) package on pub that works for all dart platforms. Why I created another EPub package only for Flutter?

Here is the story:

When I started my 2nd experimental Flutter project which is a reader for EPub, I immediately installed `epub` package. Soon I realized the package depends on [archive](https://pub.dartlang.org/packages/archive) to handle ZIP format. Everything was fine until I found I have a huge EPub file which is over 120MiB. It requires a lot of memory because `archive` has to read all data into memory. That's unacceptable to a mobile app.

And here we are. This package also has implemented a very simple reader requires 16KiB memory buffer to parse Zip files.

According to a [fantastic answer from stackoverflow](https://stackoverflow.com/questions/20762094/how-are-zlib-gzip-and-zip-related-what-do-they-have-in-common-and-how-are-they):

> The ISO/IEC 21320-1:2015 standard for file containers is a restricted zip format, such as used in Java archive files (.jar), Office Open XML files (Microsoft Office .docx, .xlsx, .pptx), Office Document Format files (.odt, .ods, .odp), and EPUB files (.epub). That standard limits the compression methods to 0 and 8, as well as other constraints such as no encryption or signatures.

My implementation is just good enough for EPub files.

Another issue I noticed later was the disk speed of some devices. My low-price Android phone from 2016 spends ~10s to parse the Zip file. Unfortunately, Zip format just bundles files one by one. There is no a single block to hold all files information. That means the internal storage has only ~10M/s reading speed. No wonder it's cheap! Even the files had just been read, it still required 4s+. So I had to find a way to avoid parse large files every time. That's why I introduced another functionality to load from json when it's unchanged.

So this is basically an EPub reader with small memory consumption.

## Getting Started

For help getting started with Flutter, view our online [documentation](https://flutter.io/).

For help on editing package code, view the [documentation](https://flutter.io/developing-packages/).
