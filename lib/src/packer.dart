// Copyright (c) 2012, Ladislav Thon. All rights reserved. Use of this source
// code is governed by a BSD-style license that can be found in the LICENSE file.

class _StateType {
  static const _StateType VALUE  = const _StateType('a value');
  static const _StateType ARRAY  = const _StateType('an array');
  static const _StateType MAP    = const _StateType('a map');
  static const _StateType MAP_KV = const _StateType('a key/value pair in a map');
  static const _StateType BYTES  = const _StateType('raw bytes'); // isn't used yet, but probably will be

  final String name;

  const _StateType(this.name);

  String toString() => name;
}

class _State {
  final _StateType type;
  int expectedCount;
  int actualCount;

  _State(this.type);

  checkCanWriteValue() {
    if (type == _StateType.BYTES) {
      throw new PackerException("Packer is serializing $type, can't serialize an arbitrary value in this place");
    }
  }

  checkType(_StateType type) {
    if (this.type != type) {
      throw new PackerException('Packer is serializing ${this.type}, but was expected to be serializing $type');
    }
  }

  checkValuesCount() {
    if (actualCount != expectedCount) {
      throw new PackerException("Packer serialized $actualCount values in $type, but was expected to serialize $expectedCount");
    }
  }
}

class Packer {
  final OutputStream _out;

  final Queue<_State> _stack;

  Packer(this._out) : _stack = new Queue<_State>() {
    _stack.addFirst(new _State(_StateType.VALUE));
  }

  get _state() => _stack.first();

  _checkStateBeforeWrite() {
    _state.checkCanWriteValue();
  }

  _modifyStateAfterWrite() {
    if (_state.type == _StateType.ARRAY) {
      _state.actualCount++;
    } else if (_state.type == _StateType.MAP) {
      _stack.addFirst(new _State(_StateType.MAP_KV));
    } else if (_state.type == _StateType.MAP_KV) {
      _stack.removeFirst();
      _state.actualCount++;
    }
  }

  write(value) {
    if (value == null) {
      writeNull();
    } else if (value is bool) {
      writeBool(value);
    } else if (value is num) {
      writeNum(value);
    } else if (value is String) {
      writeString(value);
    } else if (value is List) {
      writeArray(value);
    } else if (value is Map) {
      writeMap(value);
    } else {
      throw new PackerException("Packer can't serialize value of unknown type '$value'");
    }
  }

  writeNull() {
    _checkStateBeforeWrite();
    _out.write([0xC0]);
    _modifyStateAfterWrite();
  }

  writeBool(bool value) {
    _checkStateBeforeWrite();
    _out.write([value ? 0xC3 : 0xC2]);
    _modifyStateAfterWrite();
  }

  writeNum(num value) => value is int ? writeInt(value) : writeDouble(value);

  writeInt(int value) {
    _checkStateBeforeWrite();
    if (value >= 0) {
      if (value < (1 << 7)) { // positive fixnum
        _out.write([value]);
      } else if (value < (1 << 8)) { // uint 8
        _out.write([0xCC, value]);
      } else if (value < (1 << 16)) { // uint 16
        _out.write([0xCD,
            value >> 8 & 0xFF,
            value      & 0xFF]);
      } else if (value < (1 << 32)) { // uint 32
        _out.write([0xCE,
            value >> 24 & 0xFF,
            value >> 16 & 0xFF,
            value >> 8  & 0xFF,
            value       & 0xFF]);
      } else if (value < (1 << 64)) { // uint 64
        _out.write([0xCF,
            value >> 56 & 0xFF,
            value >> 48 & 0xFF,
            value >> 40 & 0xFF,
            value >> 32 & 0xFF,
            value >> 24 & 0xFF,
            value >> 16 & 0xFF,
            value >> 8  & 0xFF,
            value       & 0xFF]);
      } else {
        throw new PackerException("Packer can't serialize an integer greater than 2^64");
      }
    } else {
      if (value >= -(1 << 5)) { // negative fixnum
        _out.write([value & 0xFF | 0xE0]);
      } else if (value >= -(1 << 7)) { // int 8
        _out.write([0xD0, value & 0xFF]);
      } else if (value >= -(1 << 15)) { // int 16
        _out.write([0xD1,
            value >> 8 & 0xFF,
            value      & 0xFF]);
      } else if (value >= -(1 << 31)) { // int 32
        _out.write([0xD2,
            value >> 24 & 0xFF,
            value >> 16 & 0xFF,
            value >> 8  & 0xFF,
            value       & 0xFF]);
      } else if (value >= -(1 << 63)) { // int 64
        _out.write([0xD3,
            value >> 56 & 0xFF,
            value >> 48 & 0xFF,
            value >> 40 & 0xFF,
            value >> 32 & 0xFF,
            value >> 24 & 0xFF,
            value >> 16 & 0xFF,
            value >> 8  & 0xFF,
            value       & 0xFF]);
      } else {
        throw new PackerException("Packer can't serialize an integer less than -2^63");
      }
    }
    _modifyStateAfterWrite();
  }

  writeFloat(double value) {
    _checkStateBeforeWrite();
    var bytes = (new Float32List(1)..[0] = value).asByteArray();
    _out.write([0xCA,
        bytes.getUint8(3),
        bytes.getUint8(2),
        bytes.getUint8(1),
        bytes.getUint8(0),
    ]);
    _modifyStateAfterWrite();
  }

  writeDouble(double value) {
    _checkStateBeforeWrite();
    var bytes = (new Float64List(1)..[0] = value).asByteArray();
    _out.write([0xCB,
        bytes.getUint8(7),
        bytes.getUint8(6),
        bytes.getUint8(5),
        bytes.getUint8(4),
        bytes.getUint8(3),
        bytes.getUint8(2),
        bytes.getUint8(1),
        bytes.getUint8(0),
    ]);
    _modifyStateAfterWrite();
  }

  writeString(String value) {
    _checkStateBeforeWrite();
    var bytes = encodeUtf8(value);
    var length = bytes.length;    

    if (length < (1 << 5)) { // fix raw
      _out.write([length | 0xA0]);      
    } else if (length < (1 << 16)) { // raw 16
      _out.write([0xDA,
          length >> 8 & 0xFF,
          length      & 0xFF]);
    } else if (length < (1 << 32)) { // raw 32
      _out.write([0xDB,
          length >> 24 & 0xFF,
          length >> 16 & 0xFF,
          length >> 8  & 0xFF,
          length       & 0xFF]);
    } else {
      throw new PackerException("Packer can't serialize a string longer than 2^32 bytes");
    }

    _out.write(bytes);
    _modifyStateAfterWrite();
  }

  writeArray(List values) {
    startArray(values.length);
    for (final item in values) {
      write(item);
    }
    endArray();
  }

  startArray(int count) {
    _checkStateBeforeWrite();
    _stack.addFirst(new _State(_StateType.ARRAY));
    _state.expectedCount = count;
    _state.actualCount = 0;

    if (count < (1 << 4)) {
      _out.write([count | 0x90]);
    } else if (count < (1 << 16)) {
      _out.write([0xDC,
          count >> 8 & 0xFF,
          count      & 0xFF]);
    } else if (count < (1 << 32)) {
      _out.write([0xDD,
          count >> 24 & 0xFF,
          count >> 16 & 0xFF,
          count >> 8  & 0xFF,
          count       & 0xFF]);
    } else {
      throw new PackerException("Packer can't serialize an array with more than 2^32 items");
    }
  }

  endArray() {
    _state.checkType(_StateType.ARRAY);
    _state.checkValuesCount();
    _stack.removeFirst();
    _modifyStateAfterWrite();
  }

  writeMap(Map values) {
    startMap(values.length);
    values.forEach((key, value) {
      write(key);
      write(value);
    });
    endMap();
  }

  startMap(int count) {
    _checkStateBeforeWrite();
    _stack.addFirst(new _State(_StateType.MAP));
    _state.expectedCount = count;
    _state.actualCount = 0;

    if (count < (1 << 4)) {
      _out.write([count | 0x80]);
    } else if (count < (1 << 16)) {
      _out.write([0xDE,
          count >> 8 & 0xFF,
          count      & 0xFF]);
    } else if (count < (1 << 32)) {
      _out.write([0xDF,
          count >> 24 & 0xFF,
          count >> 16 & 0xFF,
          count >> 8  & 0xFF,
          count       & 0xFF]);
    } else {
      throw new PackerException("Packer can't serialize a map with more than 2^32 items");
    }
  }

  endMap() {
    _state.checkType(_StateType.MAP);
    _state.checkValuesCount();
    _stack.removeFirst();
    _modifyStateAfterWrite();
  }
}

