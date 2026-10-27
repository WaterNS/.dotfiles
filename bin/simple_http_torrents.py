"""Create resumable, single-file torrents backed by an ordinary HTTP web seed.

The HTTP range server supplies the pieces; no tracker or peer daemon is needed.
Clients must support BEP 19 web seeds and receive the complete torrent metadata.
"""

import collections
import hashlib
import ipaddress
import os
import re
import stat
import threading
import urllib.parse


_MIN_PIECE_LENGTH = 1024 * 1024
_MAX_PIECES = 8192
_HASH_BUFFER_SIZE = 1024 * 1024
_HOST_LABEL = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\Z")


def _bencode(value):
    """Encode the small subset of bencoding used by torrent metainfo."""
    if isinstance(value, bytes):
        return str(len(value)).encode("ascii") + b":" + value
    if isinstance(value, str):
        return _bencode(value.encode("utf-8"))
    if isinstance(value, int):
        return b"i" + str(value).encode("ascii") + b"e"
    if isinstance(value, (list, tuple)):
        return b"l" + b"".join(_bencode(item) for item in value) + b"e"
    if isinstance(value, dict):
        if any(not isinstance(key, bytes) for key in value):
            raise TypeError("Bencoded dictionary keys must be bytes")
        return b"d" + b"".join(
            _bencode(key) + _bencode(value[key]) for key in sorted(value)
        ) + b"e"
    raise TypeError("Unsupported bencoding value: {}".format(type(value).__name__))


def _file_identity(file_status):
    """Match the HTTP server's representation validator exactly."""
    return (
        file_status.st_dev,
        file_status.st_ino,
        file_status.st_size,
        getattr(file_status, "st_mtime_ns", int(file_status.st_mtime * 1_000_000_000)),
        getattr(file_status, "st_ctime_ns", int(file_status.st_ctime * 1_000_000_000)),
    )


def _etag(identity):
    return '"{:x}-{:x}-{:x}-{:x}-{:x}"'.format(*identity)


def _path_identity(path):
    # Use the same API as the hash source and HTTP server. On Windows, stat()
    # and fstat() may report different ctime semantics after a file is edited.
    with open(path, "rb") as current_source:
        return _file_identity(os.fstat(current_source.fileno()))


def validate_public_url(value):
    """Validate an advertised HTTP(S) base URL, retaining an optional path prefix."""
    if not isinstance(value, str):
        raise TypeError("Public URL must be a string")
    if (
        not value
        or any(character.isspace() or ord(character) < 32 or ord(character) == 127 for character in value)
        or any(character in value for character in ("\\", "?", "#"))
    ):
        raise ValueError("Public URL must not contain whitespace, queries or fragments")
    parts = urllib.parse.urlsplit(value)
    if parts.scheme.lower() not in ("http", "https") or not parts.netloc:
        raise ValueError("Public URL must be an absolute HTTP(S) URL")
    if "@" in parts.netloc or not parts.hostname:
        raise ValueError("Public URL must contain a host and no credentials")
    host = parts.hostname
    port = parts.port  # Also checks invalid and out-of-range port numbers.
    if parts.netloc.endswith(":"):
        raise ValueError("Public URL has an empty port")
    if ":" in host:
        if re.fullmatch(r"\[[^\]]+\](?::[0-9]+)?", parts.netloc) is None:
            raise ValueError("Public URL has an invalid IPv6 authority")
        if "%" in host:
            raise ValueError("Scoped IPv6 hosts are not supported in public URLs")
        host = "[{}]".format(ipaddress.IPv6Address(host).compressed)
    else:
        try:
            host = host.encode("idna").decode("ascii").lower()
        except UnicodeError as error:
            raise ValueError("Public URL has an invalid host") from error
        labels = host.rstrip(".").split(".")
        if len(host) > 254 or any(_HOST_LABEL.fullmatch(label) is None for label in labels):
            raise ValueError("Public URL has an invalid host")
        if all(character in "0123456789." for character in host):
            ipaddress.IPv4Address(host)
    authority = host + (":{}".format(port) if port is not None else "")
    if re.search(r"%(?![0-9A-Fa-f]{2})", parts.path):
        raise ValueError("Public URL has an invalid percent escape")
    path = urllib.parse.quote(parts.path, safe="/%:@!&()*+,;=-._~").rstrip("/")
    return urllib.parse.urlunsplit((parts.scheme.lower(), authority, path, "", ""))


def metadata(info_record, web_seed_url):
    """Build a complete .torrent using this server as the BEP 19 web seed."""
    return _bencode({
        b"created by": b"dotfiles simpleserver",
        b"info": info_record["info"],
        b"url-list": [web_seed_url.encode("utf-8")],
    })


class TorrentCache:
    """Bounded in-memory metadata cache, invalidated whenever a source changes."""

    def __init__(self, limit=64):
        if not isinstance(limit, int) or limit < 1:
            raise ValueError("Torrent cache limit must be a positive integer")
        self._limit = limit
        self._entries = collections.OrderedDict()
        # One scan at a time prevents duplicate or unbounded concurrent hashing.
        self._lock = threading.Lock()

    def get(self, path):
        """Read/hash a regular file lazily and return its torrent representation.

        Raises OSError for unavailable files, or ValueError if a file changes
        while its piece hashes are being computed. Returned dictionaries should
        be treated as read-only by callers.
        """
        path = os.path.abspath(os.fspath(path))
        canonical_path = os.path.normcase(os.path.realpath(path))
        name = os.path.basename(path)
        # Bencoding requires valid UTF-8 text; fail cleanly for surrogate names.
        encoded_name = name.encode("utf-8")
        cache_key = (canonical_path, name)
        with self._lock:
            if not stat.S_ISREG(os.stat(path).st_mode):
                raise ValueError("Torrent sources must be regular files")
            with open(path, "rb") as source:
                status = os.fstat(source.fileno())
                if not stat.S_ISREG(status.st_mode):
                    raise ValueError("Torrent sources must be regular files")
                identity = _file_identity(status)
                if _path_identity(path) != identity:
                    raise ValueError("The source changed while opening it; retry")
                cached = self._entries.get(cache_key)
                if cached is not None and cached["etag"] == _etag(identity):
                    self._entries.move_to_end(cache_key)
                    return cached
                self._entries.pop(cache_key, None)
                piece_length = _MIN_PIECE_LENGTH
                while (status.st_size + piece_length - 1) // piece_length > _MAX_PIECES:
                    piece_length *= 2
                pieces = []
                remaining = status.st_size
                while remaining:
                    piece_remaining = min(piece_length, remaining)
                    digest = hashlib.sha1()
                    while piece_remaining:
                        block = source.read(min(_HASH_BUFFER_SIZE, piece_remaining))
                        if not block:
                            raise ValueError("The source changed while hashing it; retry")
                        digest.update(block)
                        piece_remaining -= len(block)
                        remaining -= len(block)
                    pieces.append(digest.digest())
                if (
                    _file_identity(os.fstat(source.fileno())) != identity
                    or _path_identity(path) != identity
                ):
                    raise ValueError("The source changed while hashing it; retry")
            info = {
                b"length": status.st_size,
                b"name": encoded_name,
                b"piece length": piece_length,
                b"pieces": b"".join(pieces),
                # Avoid public DHT/peer discovery for files shared on a LAN.
                b"private": 1,
            }
            record = {
                "info": info,
                "info_hash": hashlib.sha1(_bencode(info)).hexdigest(),
                "etag": _etag(identity),
                "size": status.st_size,
                "name": name,
            }
            self._entries[cache_key] = record
            while len(self._entries) > self._limit:
                self._entries.popitem(last=False)
            return record
