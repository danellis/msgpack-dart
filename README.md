MsgPack
=======

This is Dart implementation of MsgPack, a nice binary serialization format.
"It's like JSON. but fast and small." For more details about it, see
[http://msgpack.org/](http://msgpack.org/).

Status
------

The packer is quite OK, but the unpacker is pretty rudimentary. In addition
to returning the read object at once, it should also support emitting parsing
events (to support push-style parsing). There should also be an async version
of the unpacker.

Apart of that, the only unsolved problem is proper handling of MsgPack "raw"s.
Currently, they are always treated as UTF-8-encoded strings.

Once the basic stuff is in place, arbitrary object (un)packing using mirrors
could/should be added.

