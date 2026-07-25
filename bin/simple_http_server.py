#!/usr/bin/env python3
"""Small development HTTP server with resumable-download support."""

import argparse
import functools
import os
import re
import stat
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


_BYTE_RANGE = re.compile(
    r"^\s*bytes\s*=\s*(\d*)-(\d*)\s*$",
    re.IGNORECASE,
)
_COPY_BUFFER_SIZE = 64 * 1024


class _RangeNotSatisfiable(Exception):
    pass


class RangeRequestHandler(SimpleHTTPRequestHandler):
    """Serve normal files plus one RFC-style byte range per GET request."""

    _selected_range = None
    _range_capable_response = False

    def send_head(self):
        self._selected_range = None
        self._range_capable_response = False

        path = self.translate_path(self.path)
        if os.path.isdir(path) or not os.path.isfile(path):
            return super().send_head()

        self._range_capable_response = True
        range_values = self.headers.get_all("Range", [])

        # RFC 9110 defines Range processing for GET. Let the standard handler
        # retain its HEAD and conditional-request behavior.
        if (
            self.command != "GET"
            or len(range_values) != 1
            or "If-Modified-Since" in self.headers
            or "If-None-Match" in self.headers
        ):
            return super().send_head()

        try:
            source = open(path, "rb")
        except OSError:
            return super().send_head()

        try:
            file_status = os.fstat(source.fileno())
            if not stat.S_ISREG(file_status.st_mode):
                source.close()
                self._range_capable_response = False
                return super().send_head()

            last_modified = self.date_time_string(file_status.st_mtime)
            if_range = self.headers.get("If-Range")
            if if_range is not None and if_range != last_modified:
                source.close()
                return super().send_head()

            try:
                selected_range = self._parse_byte_range(
                    range_values[0],
                    file_status.st_size,
                )
            except _RangeNotSatisfiable:
                source.close()
                self.send_response(416)
                self.send_header(
                    "Content-Range",
                    "bytes */{}".format(file_status.st_size),
                )
                self.send_header("Content-Length", "0")
                self.end_headers()
                return None

            # Unknown units, malformed values, and multiple ranges are safely
            # ignored instead of being mislabeled as a single-part response.
            if selected_range is None:
                source.close()
                return super().send_head()

            start, end = selected_range
            self._selected_range = selected_range
            self.send_response(206)
            self.send_header("Content-Type", self.guess_type(path))
            self.send_header(
                "Content-Range",
                "bytes {}-{}/{}".format(start, end, file_status.st_size),
            )
            self.send_header("Content-Length", str(end - start + 1))
            self.send_header("Last-Modified", last_modified)
            self.end_headers()
            return source
        except Exception:
            source.close()
            raise

    def end_headers(self):
        if self._range_capable_response:
            self.send_header("Accept-Ranges", "bytes")
        self._range_capable_response = False
        super().end_headers()

    def send_error(self, *args, **kwargs):
        self._selected_range = None
        self._range_capable_response = False
        return super().send_error(*args, **kwargs)

    def copyfile(self, source, outputfile):
        if self._selected_range is None:
            return super().copyfile(source, outputfile)

        start, end = self._selected_range
        remaining = end - start + 1
        source.seek(start)

        while remaining > 0:
            block = source.read(min(_COPY_BUFFER_SIZE, remaining))
            if not block:
                break
            outputfile.write(block)
            remaining -= len(block)

    @staticmethod
    def _parse_byte_range(value, file_size):
        match = _BYTE_RANGE.fullmatch(value)
        if match is None:
            return None

        first, last = match.groups()
        if not first and not last:
            return None
        if file_size == 0:
            raise _RangeNotSatisfiable

        if first:
            try:
                start = int(first)
                end = int(last) if last else file_size - 1
            except ValueError:
                return None
            if start >= file_size or end < start:
                raise _RangeNotSatisfiable
            return start, min(end, file_size - 1)

        try:
            suffix_length = int(last)
        except ValueError:
            return None
        if suffix_length == 0:
            raise _RangeNotSatisfiable
        return max(file_size - suffix_length, 0), file_size - 1


def main():
    parser = argparse.ArgumentParser(
        description="Serve files over HTTP with single byte-range support.",
    )
    parser.add_argument(
        "-b",
        "--bind",
        metavar="ADDRESS",
        help="bind to this address (default: all interfaces)",
    )
    parser.add_argument(
        "-d",
        "--directory",
        default=os.getcwd(),
        help="serve this directory (default: current directory)",
    )
    parser.add_argument("port", default=8000, type=int, nargs="?")
    args = parser.parse_args()

    handler = functools.partial(
        RangeRequestHandler,
        directory=args.directory,
    )
    address = args.bind or ""

    with ThreadingHTTPServer((address, args.port), handler) as server:
        display_address = args.bind or "0.0.0.0"
        print(
            "Serving HTTP with byte-range support on {} port {} "
            "(http://{}:{}/) ...".format(
                display_address,
                args.port,
                display_address,
                args.port,
            )
        )
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
