import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persian_scanner/presentation/widgets.dart';

void main() {
  test('جهت خودکار متن', () {
    expect(autoDirection('scan_{date}'), TextDirection.ltr);
    expect(autoDirection('{type}_scan'), TextDirection.ltr);
    expect(autoDirection('اسکن_{type}'), TextDirection.rtl);
    expect(autoDirection('123'), TextDirection.ltr);
    expect(autoDirection(''), TextDirection.rtl);
  });
}
