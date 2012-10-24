import 'dart:io';
import 'package:msgpack/msgpack.dart';

import 'package:darmatch/matchers.dart';
import 'package:detester/detester.dart';
part 'package:detester/test.dart';

suite() => configure('MsgPack unpacker',
  [
    testNil,
    testTrue,
    testFalse,
    testPositiveFixnum,
    testUint8,
    testUint16,
    testUint32,
    testUint64,
    testNegativeFixnum,
    testInt8,
    testInt16,
    testInt32,
    testInt64,
    testFloat,
    testDouble,
    testFixRaw,
    testRaw16,
    testRaw32,
    testFixArray,
    testArray16,
    testArray32,
    testFixMap,
    testMap16,
    testMap32,
    testArrayWrongCount,
    testMapWrongCount,
    testMapInvalidState
  ]
);

testNil() {
  expectThat(msgUnpack([0xC0]), isNull());
}

testTrue() {
  expectThat(msgUnpack([0xC3]), isTrue());
}

testFalse() {
  expectThat(msgUnpack([0xC2]), isFalse());
}

testPositiveFixnum() {
  expectThat(msgUnpack([0x00]), equals(0)); // 0
  expectThat(msgUnpack([0x05]), equals(5));
  expectThat(msgUnpack([0x20]), equals(32));
  expectThat(msgUnpack([0x64]), equals(100));
  expectThat(msgUnpack([0x7F]), equals((1 << 7) - 1)); // 2^7 - 1
}

testUint8() {
  expectThat(msgUnpack([0xCC, 0x80]), equals(1 << 7)); // 2^7
  expectThat(msgUnpack([0xCC, 0xE8]), equals(232));
  expectThat(msgUnpack([0xCC, 0xFF]), equals((1 << 8) - 1)); // 2^8 - 1
}

testUint16() {
  expectThat(msgUnpack([0xCD, 0x01, 0x00]), equals(1 << 8));
  expectThat(msgUnpack([0xCD, 0x04, 0x01]), equals(1025));
  expectThat(msgUnpack([0xCD, 0xD9, 0x03]), equals(55555));
  expectThat(msgUnpack([0xCD, 0xFF, 0xFF]), equals((1 << 16) - 1)); // 2^16 - 1
}

testUint32() {
  expectThat(msgUnpack([0xCE, 0x00, 0x01, 0x00, 0x00]), equals(1 << 16)); // 2^16
  expectThat(msgUnpack([0xCE, 0x00, 0x0F, 0x42, 0x40]), equals(1000000));
  expectThat(msgUnpack([0xCE, 0xFF, 0xFF, 0xFF, 0xFF]), equals((1 << 32) - 1)); // 2^32 - 1
}

testUint64() {
  expectThat(msgUnpack([0xCF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]), equals(1 << 32)); // 2^32
  expectThat(msgUnpack([0xCF, 0x00, 0x00, 0x00, 0x17, 0x84, 0xAB, 0xD3, 0x12]), equals(101010101010));
  expectThat(msgUnpack([0xCF, 0x8A, 0xC7, 0x23, 0x04, 0x89, 0xE7, 0xFF, 0xFF]), equals(9999999999999999999));
  expectThat(msgUnpack([0xCF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), equals((1 << 64) - 1)); // 2^64 - 1
}

testNegativeFixnum() {
  expectThat(msgUnpack([0xFF]), equals(-1)); // -1
  expectThat(msgUnpack([0xF6]), equals(-10));
  expectThat(msgUnpack([0xE0]), equals(-(1 << 5))); // -2^5
}

testInt8() {
  expectThat(msgUnpack([0xD0, 0xDF]), equals(-(1 << 5) - 1)); // -2^5 - 1
  expectThat(msgUnpack([0xD0, 0x9C]), equals(-100));
  expectThat(msgUnpack([0xD0, 0x80]), equals(-(1 << 7))); // -2^7
}

testInt16() {
  expectThat(msgUnpack([0xD1, 0xFF, 0x7F]), equals(-(1 << 7) - 1)); // -2^7 - 1
  expectThat(msgUnpack([0xD1, 0xE1, 0x9F]), equals(-7777));
  expectThat(msgUnpack([0xD1, 0x80, 0x00]), equals(-(1 << 15))); // -2^15
}

testInt32() {
  expectThat(msgUnpack([0xD2, 0xFF, 0xFF, 0x7F, 0xFF]), equals(-(1 << 15) - 1)); // -2^15 - 1
  expectThat(msgUnpack([0xD2, 0xFF, 0x87, 0xC7, 0x7D]), equals(-7878787));
  expectThat(msgUnpack([0xD2, 0x80, 0x00, 0x00, 0x00]), equals(-(1 << 31))); // -2^31
}

testInt64() {
  expectThat(msgUnpack([0xD3, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF]), equals(-(1 << 31) - 1)); // -2^31 - 1
  expectThat(msgUnpack([0xD3, 0xFF, 0x8D, 0x2A, 0x31, 0x03, 0x61, 0x9D, 0xBD]), equals(-32323232323232323));
  expectThat(msgUnpack([0xD3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(-(1 << 63))); // -2^63
}

testFloat() {
  expectThat(msgUnpack([0xCA, 0x00, 0x00, 0x00, 0x00]), equals(0.0));
  expectThat(msgUnpack([0xCA, 0x80, 0x00, 0x00, 0x00]), equals(-0.0));

  // there are no 32-bit floats in Dart, so the deserialized 32-bit number
  // is converted to 64-bit number (and that is a lossy process)
  expectThat(msgUnpack([0xCA, 0x3D, 0xCC, 0xCC, 0xCD]), and([
      greaterThan(0.099999),
      lessThan(0.100001)
  ]));
  expectThat(msgUnpack([0xCA, 0x3E, 0x4C, 0xCC, 0xCD]), and([
      greaterThan(0.199999),
      lessThan(0.200001)
  ]));
  expectThat(msgUnpack([0xCA, 0x3F, 0x80, 0x00, 0x00]), equals(1.0));
}

testDouble() {
  expectThat(msgUnpack([0xCB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(0.0));
  expectThat(msgUnpack([0xCB, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(-0.0));

  expectThat(msgUnpack([0xCB, 0x3F, 0xB9, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A]), equals(0.1));
  expectThat(msgUnpack([0xCB, 0x3F, 0xC9, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A]), equals(0.2));
  expectThat(msgUnpack([0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(1.0));
  expectThat(msgUnpack([0xCB, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(2.0));
  expectThat(msgUnpack([0xCB, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(-2.0));

  expectThat(msgUnpack([0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]), equals(1.0000000000000002));
  expectThat(msgUnpack([0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02]), equals(1.0000000000000004));

  // see http://en.wikipedia.org/wiki/Denormal_number for explanation
  // of subnormal double numbers
  const MIN_SUBNORMAL_POSITIVE = double.MIN_POSITIVE;
  const MAX_SUBNORMAL_POSITIVE = 2.2250738585072009e-308;
  const MIN_NORMAL_POSITIVE    = 2.2250738585072014e-308;
  const MAX_NORMAL_POSITIVE    = double.MAX_FINITE;

  expectThat(msgUnpack([0xCB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]), equals(MIN_SUBNORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0x00, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), equals(MAX_SUBNORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(MIN_NORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0x7F, 0xEF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), equals(MAX_NORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]), equals(-MIN_SUBNORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0x80, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), equals(-MAX_SUBNORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(-MIN_NORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0xFF, 0xEF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), equals(-MAX_NORMAL_POSITIVE));
  expectThat(msgUnpack([0xCB, 0x7F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(double.INFINITY));
  expectThat(msgUnpack([0xCB, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), equals(double.NEGATIVE_INFINITY));

  // IEEE 754 defines all bit patterns looking like 7FFx_xxxx_xxxx_xxxx
  // and FFFx_xxxx_xxxx_xxxx to represent a NAN
  expectThat(msgUnpack([0xCB, 0x7F, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), isNaN());
  expectThat(msgUnpack([0xCB, 0xFF, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), isNaN());
  expectThat(msgUnpack([0xCB, 0x7F, 0xF8, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00]), isNaN());
  expectThat(msgUnpack([0xCB, 0xFF, 0xF8, 0x00, 0x10, 0x00, 0x01, 0x00, 0x00]), isNaN());
}

testFixRaw() {
  expectThat(msgUnpack([0xA0]),                   equals(""));
  expectThat(msgUnpack([0xA1, 0x61]),             equals("a"));
  expectThat(msgUnpack([0xA3, 0x61, 0x42, 0x63]), equals("aBc"));

  expectThat(msgUnpack([0xBF,
      0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
      0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a,
      0x31, 0x32, 0x33, 0x34, 0x35]), equals("abcdefghijklmnopqrstuvwxyz12345")); // 31
}

testRaw16() {
  expectThat(msgPack("abcdefghijklmnopqrstuvwxyz123456"), orderedEquals([0xDA, 0x00, 0x20, // 32
      0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
      0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a,
      0x31, 0x32, 0x33, 0x34, 0x35, 0x36]));

  // 2^16 - 1
  var longString = new StringBuffer();
  for (var i = 0; i < (1 << 16) - 1; i++) {
    longString.add(" ");
  }
  var msgPackBytes = [0xDA, 0xFF, 0xFF];
  for (var i = 0; i < (1 << 16) - 1; i++) {
    msgPackBytes.add(0x20);
  }
  expectThat(msgUnpack(msgPackBytes), equals("$longString"));
}

testRaw32() {
  // 2^16
  var longString = new StringBuffer();
  for (var i = 0; i < (1 << 16); i++) {
    longString.add(" ");
  }
  var msgPackBytes = [0xDB, 0x00, 0x01, 0x00, 0x00];
  for (var i = 0; i < (1 << 16); i++) {
    msgPackBytes.add(0x20);
  }
  expectThat(msgUnpack(msgPackBytes), equals("$longString"));

  // 2^16 + 1
  longString.add(" ");
  msgPackBytes[4] = 0x01;
  msgPackBytes.add(0x20);
  expectThat(msgUnpack(msgPackBytes), equals("$longString"));
}

testFixArray() {
  expectThat(msgUnpack([0x90]), orderedEquals([]));
  expectThat(msgUnpack([0x91, 0x00]), orderedEquals([0]));
  expectThat(msgUnpack([0x9F, // 15
      0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00]),
      orderedEquals([0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]));
}

testArray16() {
  expectThat(msgUnpack([0xDC, 0x00, 0x10, // 16
      0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01]),
      orderedEquals([0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]));

  // 2^16 - 1
  var longList = new List();
  for (var i = 0; i < (1 << 16) - 1; i++) {
    longList.add(0);
  }
  var msgPackBytes = [0xDC, 0xFF, 0xFF];
  for (var i = 0; i < (1 << 16) - 1; i++) {
    msgPackBytes.add(0x00);
  }
  expectThat(msgUnpack(msgPackBytes), orderedEquals(longList));
}

testArray32() {
  // 2^16
  var longList = new List();
  for (var i = 0; i < (1 << 16); i++) {
    longList.add(0);
  }
  var msgPackBytes = [0xDD, 0x00, 0x01, 0x00, 0x00];
  for (var i = 0; i < (1 << 16); i++) {
    msgPackBytes.add(0x00);
  }
  expectThat(msgUnpack(msgPackBytes), orderedEquals(longList));

  // 2^16 + 1
  longList.add(0);
  msgPackBytes[4] = 0x01;
  msgPackBytes.add(0x00);
  expectThat(msgUnpack(msgPackBytes), orderedEquals(longList));
}

testFixMap() {
  expectThat(msgUnpack([0x80]), mapEquals({}));
  expectThat(msgUnpack([0x81, 0xA1, 0x30, 0x00]), mapEquals({'0': 0}));
  expectThat(msgUnpack([0x8F, // 15
        0xA1, 0x30, 0x00, 0xA1, 0x31, 0x01, 0xA1, 0x32, 0x02, 0xA1, 0x33, 0x03, 0xA1, 0x34, 0x04,
        0xA1, 0x35, 0x05, 0xA1, 0x36, 0x06, 0xA1, 0x37, 0x07, 0xA1, 0x38, 0x08, 0xA1, 0x39, 0x09,
        0xA1, 0x61, 0x0A, 0xA1, 0x62, 0x0B, 0xA1, 0x63, 0x0C, 0xA1, 0x64, 0x0D, 0xA1, 0x65, 0x0E,
      ]),
      mapEquals({
        '0': 0,  '1': 1,  '2': 2,  '3': 3,  '4': 4, 
        '5': 5,  '6': 6,  '7': 7,  '8': 8,  '9': 9,
        'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14
      })        
  );
}

testMap16() {
  expectThat(msgUnpack([0xDE, 0x00, 0x10, // 16
        0xA1, 0x30, 0x00, 0xA1, 0x31, 0x01, 0xA1, 0x32, 0x02, 0xA1, 0x33, 0x03, 0xA1, 0x34, 0x04,
        0xA1, 0x35, 0x05, 0xA1, 0x36, 0x06, 0xA1, 0x37, 0x07, 0xA1, 0x38, 0x08, 0xA1, 0x39, 0x09,
        0xA1, 0x61, 0x0A, 0xA1, 0x62, 0x0B, 0xA1, 0x63, 0x0C, 0xA1, 0x64, 0x0D, 0xA1, 0x65, 0x0E,
        0xA1, 0x66, 0x0F
      ]),
      mapEquals({
        '0': 0,  '1': 1,  '2': 2,  '3': 3,  '4': 4, 
        '5': 5,  '6': 6,  '7': 7,  '8': 8,  '9': 9,
        'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14,
        'f': 15
      })
  );

  // 2^16 - 1
  var longMap = new LinkedHashMap();
  for (var i = 0; i < (1 << 16) - 1; i++) {
    longMap[i] = 0;
  }
  var msgPackBytes = [0xDE, 0xFF, 0xFF];
  for (var i = 0; i < (1 << 16) - 1; i++) {
    msgPackBytes.addAll(msgPack(i));
    msgPackBytes.add(0x00);
  }
  expectThat(msgUnpack(msgPackBytes), mapEquals(longMap));
}

testMap32() {
  // 2^16
  var longMap = new LinkedHashMap();
  for (var i = 0; i < (1 << 16); i++) {
    longMap[i] = 0;
  }
  var msgPackBytes = [0xDF, 0x00, 0x01, 0x00, 0x00];
  for (var i = 0; i < (1 << 16); i++) {
    msgPackBytes.addAll(msgPack(i));
    msgPackBytes.add(0x00);
  }
  expectThat(msgUnpack(msgPackBytes), mapEquals(longMap));

  // 2^16 + 1
  longMap[(1 << 16) + 1] = 0;
  msgPackBytes[4] = 0x01;
  msgPackBytes.addAll(msgPack((1 << 16) + 1));
  msgPackBytes.add(0x00);
  expectThat(msgUnpack(msgPackBytes), mapEquals(longMap));
}

testArrayWrongCount() {
  expectThat(() => msgUnpack([0x91]), throws(),
      "Array of length 1 is empty");
}

testMapWrongCount() {
  expectThat(() => msgUnpack([0x81]), throws(),
      "Map of length 1 is empty");
}

testMapInvalidState() {
  expectThat(() => msgUnpack([0x81, 0xA1, 0x30]), throws(),
      "Map unpacking ended in the middle of a pair");
}

