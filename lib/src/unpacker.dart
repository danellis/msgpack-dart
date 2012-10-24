// Copyright (c) 2012, Ladislav Thon. All rights reserved. Use of this source
// code is governed by a BSD-style license that can be found in the LICENSE file.

class Unpacker {
  final ListInputStream _data;

  Unpacker(this._data);

  _readBytes(count) {
    var bytes = _data.read(count);
    if (bytes == null) {
      throw new UnpackerException("Unpacker attempted to read $count bytes beyond the end of input");
    }
    return bytes;
  }

  _readByte() => _readBytes(1)[0];

  _readByteArray(int bytesCount) {
    var bytes = _readBytes(bytesCount);
    var bytesList = new Uint8List(bytesCount);
    for (var i = 0; i < bytesCount; i++) {
      bytesList[i] = bytes[bytesCount - 1 - i]; // MsgPack uses big endian
    }
    return bytesList.asByteArray();
  }

  read() {
    var byte = _readByte();

    if (byte == 0xC0) {
      return null;
    } else if (byte == 0xC3) {
      return true;
    } else if (byte == 0xC2) {
      return false;
    } else if (byte >= 0x00 && byte <= 0x7F) {
      return byte; // positive fixnum
    } else if (byte >= 0xE0 && byte <= 0xFF) {
      return byte - 0x100; // negative fixnum
    } else if (byte == 0xCC) {
      return _readByteArray(1).getUint8(0); // uint 8
    } else if (byte == 0xCD) {
      return _readByteArray(2).getUint16(0); // uint 16
    } else if (byte == 0xCE) {
      return _readByteArray(4).getUint32(0); // uint 32
    } else if (byte == 0xCF) {
      return _readByteArray(8).getUint64(0); // uint 64
    } else if (byte == 0xD0) {
      return _readByteArray(1).getInt8(0); // int 8
    } else if (byte == 0xD1) {
      return _readByteArray(2).getInt16(0); // int 16
    } else if (byte == 0xD2) {
      return _readByteArray(4).getInt32(0); // int 32
    } else if (byte == 0xD3) {
      return _readByteArray(8).getInt64(0); // int 64
    } else if (byte == 0xCA) {
      return _readByteArray(4).getFloat32(0); // float
    } else if (byte == 0xCB) {
      return _readByteArray(8).getFloat64(0); // double
    } else if (byte >= 0xA0 && byte <= 0xBF) {
      return _readString(byte - 0xA0); // fix raw
    } else if (byte == 0xDA) {
      return _readString(_readByteArray(2).getUint16(0)); // raw 16
    } else if (byte == 0xDB) {
      return _readString(_readByteArray(4).getUint32(0)); // raw 32
    } else if (byte >= 0x90 && byte <= 0x9F) {
      return _readArray(byte - 0x90); // fix array
    } else if (byte == 0xDC) {
      return _readArray(_readByteArray(2).getUint16(0)); // array 16
    } else if (byte == 0xDD) {
      return _readArray(_readByteArray(4).getUint32(0)); // array 32
    } else if (byte >= 0x80 && byte <= 0x8F) {
      return _readMap(byte - 0x80); // fix map
    } else if (byte == 0xDE) {
      return _readMap(_readByteArray(2).getUint16(0)); // map 16
    } else if (byte == 0xDF) {
      return _readMap(_readByteArray(4).getUint32(0)); // map 32
    } else {
      throw new UnpackerException("Unpacker can't deserialize byte '${byte.toRadixString(16)}'");
    }
  }

  _readString(int length) {
    if (length == 0) return '';
    return decodeUtf8(_readBytes(length));
  }

  _readArray(int length) {
    var result = [];
    for (var i = 0; i < length; i++) {
      result.add(read());
    }
    return result;
  }

  _readMap(int length) {
    var result = {};
    for (var i = 0; i < length; i++) {
      var key = read();
      var value = read();
      result[key] = value;
    }
    return result;
  }
}

