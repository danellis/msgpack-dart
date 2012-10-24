import 'dart:io';
import 'package:msgpack/msgpack.dart';

import 'package:darmatch/matchers.dart';
import 'package:detester/detester.dart';
part 'package:detester/test.dart';

suite() => configure('MsgPack packer',
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
  expectThat(msgPack(null), orderedEquals([0xC0]));
}

testTrue() {
  expectThat(msgPack(true), orderedEquals([0xC3]));
}

testFalse() {
  expectThat(msgPack(false), orderedEquals([0xC2]));
}

testPositiveFixnum() {
  expectThat(msgPack(0),            orderedEquals([0x00])); // 0
  expectThat(msgPack(5),            orderedEquals([0x05]));
  expectThat(msgPack(32),           orderedEquals([0x20]));
  expectThat(msgPack(100),          orderedEquals([0x64]));
  expectThat(msgPack((1 << 7) - 1), orderedEquals([0x7F])); // 2^7 - 1
}

testUint8() {
  expectThat(msgPack(1 << 7),       orderedEquals([0xCC, 0x80])); // 2^7
  expectThat(msgPack(232),          orderedEquals([0xCC, 0xE8]));
  expectThat(msgPack((1 << 8) - 1), orderedEquals([0xCC, 0xFF])); // 2^8 - 1
}

testUint16() {
  expectThat(msgPack(1 << 8),        orderedEquals([0xCD, 0x01, 0x00])); // 2^8
  expectThat(msgPack(1025),          orderedEquals([0xCD, 0x04, 0x01]));
  expectThat(msgPack(55555),         orderedEquals([0xCD, 0xD9, 0x03]));
  expectThat(msgPack((1 << 16) - 1), orderedEquals([0xCD, 0xFF, 0xFF])); // 2^16 - 1
}

testUint32() {
  expectThat(msgPack(1 << 16),       orderedEquals([0xCE, 0x00, 0x01, 0x00, 0x00])); // 2^16
  expectThat(msgPack(1000000),       orderedEquals([0xCE, 0x00, 0x0F, 0x42, 0x40]));
  expectThat(msgPack((1 << 32) - 1), orderedEquals([0xCE, 0xFF, 0xFF, 0xFF, 0xFF])); // 2^32 - 1
}

testUint64() {
  expectThat(msgPack(1 << 32),             orderedEquals([0xCF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])); // 2^32
  expectThat(msgPack(101010101010),        orderedEquals([0xCF, 0x00, 0x00, 0x00, 0x17, 0x84, 0xAB, 0xD3, 0x12]));
  expectThat(msgPack(9999999999999999999), orderedEquals([0xCF, 0x8A, 0xC7, 0x23, 0x04, 0x89, 0xE7, 0xFF, 0xFF]));
  expectThat(msgPack((1 << 64) - 1),       orderedEquals([0xCF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])); // 2^64 - 1

  expectThat(() => msgPack(1 << 64), throws()); // 2^64
}

testNegativeFixnum() {
  expectThat(msgPack(-1),        orderedEquals([0xFF])); // -1
  expectThat(msgPack(-10),       orderedEquals([0xF6]));
  expectThat(msgPack(-(1 << 5)), orderedEquals([0xE0])); // -2^5
}

testInt8() {
  expectThat(msgPack(-(1 << 5) - 1), orderedEquals([0xD0, 0xDF])); // -2^5 - 1
  expectThat(msgPack(-100),          orderedEquals([0xD0, 0x9C]));
  expectThat(msgPack(-(1 << 7)),     orderedEquals([0xD0, 0x80])); // -2^7
}

testInt16() {
  expectThat(msgPack(-(1 << 7) - 1), orderedEquals([0xD1, 0xFF, 0x7F])); // -2^7 - 1
  expectThat(msgPack(-7777),         orderedEquals([0xD1, 0xE1, 0x9F]));
  expectThat(msgPack(-(1 << 15)),    orderedEquals([0xD1, 0x80, 0x00])); // -2^15
}

testInt32() {
  expectThat(msgPack(-(1 << 15) - 1), orderedEquals([0xD2, 0xFF, 0xFF, 0x7F, 0xFF])); // -2^15 - 1
  expectThat(msgPack(-7878787),       orderedEquals([0xD2, 0xFF, 0x87, 0xC7, 0x7D]));
  expectThat(msgPack(-(1 << 31)),     orderedEquals([0xD2, 0x80, 0x00, 0x00, 0x00])); // -2^31
}

testInt64() {
  expectThat(msgPack(-(1 << 31) - 1),     orderedEquals([0xD3, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF])); // -2^31 - 1
  expectThat(msgPack(-32323232323232323), orderedEquals([0xD3, 0xFF, 0x8D, 0x2A, 0x31, 0x03, 0x61, 0x9D, 0xBD]));
  expectThat(msgPack(-(1 << 63)),         orderedEquals([0xD3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])); // -2^63

  expectThat(() => msgPack(-(1 << 63) - 1), throws()); // -2^63 - 1
}

testFloat() {
  packFloat(double value) {
    var data = new ListOutputStream();
    var packer = new Packer(data);
    packer.writeFloat(value);
    return data.read();
  }

  expectThat(packFloat(0.0),  orderedEquals([0xCA, 0x00, 0x00, 0x00, 0x00]));
  expectThat(packFloat(-0.0), orderedEquals([0xCA, 0x80, 0x00, 0x00, 0x00]));

  expectThat(packFloat(0.1),  orderedEquals([0xCA, 0x3D, 0xCC, 0xCC, 0xCD]));
  expectThat(packFloat(0.2),  orderedEquals([0xCA, 0x3E, 0x4C, 0xCC, 0xCD]));
  expectThat(packFloat(1.0),  orderedEquals([0xCA, 0x3F, 0x80, 0x00, 0x00]));  
}

testDouble() {
  expectThat(msgPack(0.0),  orderedEquals([0xCB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));
  expectThat(msgPack(-0.0), orderedEquals([0xCB, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));

  expectThat(msgPack(0.1),  orderedEquals([0xCB, 0x3F, 0xB9, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A]));
  expectThat(msgPack(0.2),  orderedEquals([0xCB, 0x3F, 0xC9, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A]));
  expectThat(msgPack(1.0),  orderedEquals([0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));
  expectThat(msgPack(2.0),  orderedEquals([0xCB, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));
  expectThat(msgPack(-2.0), orderedEquals([0xCB, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));

  expectThat(msgPack(1.0000000000000002), orderedEquals([0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]));
  expectThat(msgPack(1.0000000000000004), orderedEquals([0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02]));

  // see http://en.wikipedia.org/wiki/Denormal_number for explanation
  // of subnormal double numbers
  const MIN_SUBNORMAL_POSITIVE = double.MIN_POSITIVE;
  const MAX_SUBNORMAL_POSITIVE = 2.2250738585072009e-308;
  const MIN_NORMAL_POSITIVE    = 2.2250738585072014e-308;
  const MAX_NORMAL_POSITIVE    = double.MAX_FINITE;

  expectThat(msgPack(MIN_SUBNORMAL_POSITIVE),   orderedEquals([0xCB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]));
  expectThat(msgPack(MAX_SUBNORMAL_POSITIVE),   orderedEquals([0xCB, 0x00, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]));
  expectThat(msgPack(MIN_NORMAL_POSITIVE),      orderedEquals([0xCB, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));
  expectThat(msgPack(MAX_NORMAL_POSITIVE),      orderedEquals([0xCB, 0x7F, 0xEF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]));
  expectThat(msgPack(-MIN_SUBNORMAL_POSITIVE),  orderedEquals([0xCB, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]));
  expectThat(msgPack(-MAX_SUBNORMAL_POSITIVE),  orderedEquals([0xCB, 0x80, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]));
  expectThat(msgPack(-MIN_NORMAL_POSITIVE),     orderedEquals([0xCB, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));
  expectThat(msgPack(-MAX_NORMAL_POSITIVE),     orderedEquals([0xCB, 0xFF, 0xEF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]));
  expectThat(msgPack(double.INFINITY),          orderedEquals([0xCB, 0x7F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));
  expectThat(msgPack(double.NEGATIVE_INFINITY), orderedEquals([0xCB, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));

  // NAN can be negative (it happens on my Linux machine), but it doesn't
  // affect anything (positive and negative NANs are equivalent)
  //
  // also note that IEEE 754 defines all bit patterns looking like
  // 7FFx_xxxx_xxxx_xxxx and FFFx_xxxx_xxxx_xxxx to represent a NAN,
  // but there is no payload in double.NAN (and shouldn't be)
  const POSITIVE_NAN_BITS = const [0x7F, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
  const NEGATIVE_NAN_BITS = const [0xFF, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
  expectThat(msgPack(double.NAN), or([
      orderedEquals([0xCB]..addAll(POSITIVE_NAN_BITS)),
      orderedEquals([0xCB]..addAll(NEGATIVE_NAN_BITS))
  ]));
}

testFixRaw() {
  expectThat(msgPack(""),    orderedEquals([0xA0]));
  expectThat(msgPack("a"),   orderedEquals([0xA1, 0x61]));
  expectThat(msgPack("aBc"), orderedEquals([0xA3, 0x61, 0x42, 0x63]));

  expectThat(msgPack("abcdefghijklmnopqrstuvwxyz12345"), orderedEquals([0xBF, // 31
      0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
      0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a,
      0x31, 0x32, 0x33, 0x34, 0x35]));
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
  expectThat(msgPack("$longString"), orderedEquals(msgPackBytes));
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
  expectThat(msgPack("$longString"), orderedEquals(msgPackBytes));

  // 2^16 + 1
  longString.add(" ");
  msgPackBytes[4] = 0x01;
  msgPackBytes.add(0x20);
  expectThat(msgPack("$longString"), orderedEquals(msgPackBytes));
}

testFixArray() {
  expectThat(msgPack([]),  orderedEquals([0x90]));
  expectThat(msgPack([0]), orderedEquals([0x91, 0x00]));
  expectThat(msgPack([0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]), orderedEquals([0x9F, // 15
      0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01,
      0x00, 0x01, 0x00, 0x01, 0x00]));
}

testArray16() {
  expectThat(msgPack([0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]), orderedEquals([0xDC, 0x00, 0x10, // 16
      0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01,
      0x00, 0x01, 0x00, 0x01, 0x00, 0x01]));

  // 2^16 - 1
  var longList = new List();
  for (var i = 0; i < (1 << 16) - 1; i++) {
    longList.add(0);
  }
  var msgPackBytes = [0xDC, 0xFF, 0xFF];
  for (var i = 0; i < (1 << 16) - 1; i++) {
    msgPackBytes.add(0x00);
  }
  expectThat(msgPack(longList), orderedEquals(msgPackBytes));
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
  expectThat(msgPack(longList), orderedEquals(msgPackBytes));

  // 2^16 + 1
  longList.add(0);
  msgPackBytes[4] = 0x01;
  msgPackBytes.add(0x00);
  expectThat(msgPack(longList), orderedEquals(msgPackBytes));
}

testFixMap() {
  expectThat(msgPack({}),       orderedEquals([0x80]));
  expectThat(msgPack({'0': 0}), orderedEquals([0x81, 0xA1, 0x30, 0x00]));
  expectThat(msgPack(
      {
        '0': 0,  '1': 1,  '2': 2,  '3': 3,  '4': 4, 
        '5': 5,  '6': 6,  '7': 7,  '8': 8,  '9': 9,
        'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14
      }),
      orderedEquals([0x8F, // 15
        0xA1, 0x30, 0x00, 0xA1, 0x31, 0x01, 0xA1, 0x32, 0x02, 0xA1, 0x33, 0x03, 0xA1, 0x34, 0x04,
        0xA1, 0x35, 0x05, 0xA1, 0x36, 0x06, 0xA1, 0x37, 0x07, 0xA1, 0x38, 0x08, 0xA1, 0x39, 0x09,
        0xA1, 0x61, 0x0A, 0xA1, 0x62, 0x0B, 0xA1, 0x63, 0x0C, 0xA1, 0x64, 0x0D, 0xA1, 0x65, 0x0E,
      ])
  );
}

testMap16() {
  expectThat(msgPack(
      {
        '0': 0,  '1': 1,  '2': 2,  '3': 3,  '4': 4, 
        '5': 5,  '6': 6,  '7': 7,  '8': 8,  '9': 9,
        'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14,
        'f': 15
      }),
      orderedEquals([0xDE, 0x00, 0x10, // 16
        0xA1, 0x30, 0x00, 0xA1, 0x31, 0x01, 0xA1, 0x32, 0x02, 0xA1, 0x33, 0x03, 0xA1, 0x34, 0x04,
        0xA1, 0x35, 0x05, 0xA1, 0x36, 0x06, 0xA1, 0x37, 0x07, 0xA1, 0x38, 0x08, 0xA1, 0x39, 0x09,
        0xA1, 0x61, 0x0A, 0xA1, 0x62, 0x0B, 0xA1, 0x63, 0x0C, 0xA1, 0x64, 0x0D, 0xA1, 0x65, 0x0E,
        0xA1, 0x66, 0x0F
      ])
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
  expectThat(msgPack(longMap), orderedEquals(msgPackBytes));
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
  expectThat(msgPack(longMap), orderedEquals(msgPackBytes));

  // 2^16 + 1
  longMap[(1 << 16) + 1] = 0;
  msgPackBytes[4] = 0x01;
  msgPackBytes.addAll(msgPack((1 << 16) + 1));
  msgPackBytes.add(0x00);
  expectThat(msgPack(longMap), orderedEquals(msgPackBytes));
}

testArrayWrongCount() {
  expectThat(() {
    var packer = new Packer(new ListOutputStream());
    packer.startArray(1);
    packer.endArray();
  }, throws(), "Array of length 1 is empty");

  expectThat(() {
    var packer = new Packer(new ListOutputStream());
    packer.startArray(1);
    packer.write(0);
    packer.write(0);
    packer.endArray();
  }, throws(), "Array of length 1 has 2 elements");
}

testMapWrongCount() {
  expectThat(() {
    var packer = new Packer(new ListOutputStream());
    packer.startMap(1);
    packer.endMap();
  }, throws(), "Map of length 1 is empty");

  expectThat(() {
    var packer = new Packer(new ListOutputStream());
    packer.startMap(1);
    packer.write(0);
    packer.write(0);
    packer.write(1);
    packer.write(1);
    packer.endMap();
  }, throws(), "Map of length 1 has 2 mappings");
}

testMapInvalidState() {
  expectThat(() {
    var packer = new Packer(new ListOutputStream());
    packer.startMap(1);
    packer.write(0);
    packer.endMap();
  }, throws(), "Map packing ended in the middle of a pair");
}

