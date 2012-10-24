// Copyright (c) 2012, Ladislav Thon. All rights reserved. Use of this source
// code is governed by a BSD-style license that can be found in the LICENSE file.

class PackerException implements Exception {
  final String _message;

  PackerException(this._message);

  String toString() => _message;
}

class UnpackerException implements Exception {
  final String _message;

  UnpackerException(this._message);

  String toString() => _message;
}

