// Copyright (c) 2012, Ladislav Thon. All rights reserved. Use of this source
// code is governed by a BSD-style license that can be found in the LICENSE file.

List<int> msgPack(value) {
  var stream = new ListOutputStream();
  new Packer(stream).write(value);
  return stream.read();
}

msgUnpack(List<int> data) {
  var stream = new ListInputStream();
  stream..write(data)..markEndOfStream();
  return new Unpacker(stream).read();
}

