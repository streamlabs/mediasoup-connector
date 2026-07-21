#!/usr/bin/env python3
"""Print the member object file paths from a GNU thin archive (!<thin>).

Usage: thin_archive_objs.py <archive.a>

Prints one absolute path per line. Each path is resolved relative to the
directory containing the archive, matching how the linker locates them.
If the file is not a thin archive the script exits silently with code 0.
"""

import os
import sys


def thin_archive_members(path):
    """Return list of member paths (relative to the archive directory)."""
    members = []
    with open(path, "rb") as f:
        if f.read(8) != b"!<thin>\n":
            return []
        long_names = b""
        while True:
            header = f.read(60)
            if len(header) < 60:
                break
            name = header[0:16].rstrip(b" ")
            size = int(header[48:58].strip())
            if name == b"/":
                f.read(size + (size % 2))
                continue
            elif name == b"//":
                long_names = f.read(size + (size % 2))
                continue
            elif name.startswith(b"/"):
                off = int(name[1:].rstrip(b"/"))
                try:
                    end = long_names.index(b"\n", off)
                except ValueError as e:
                    raise ValueError(f"Invalid long filename offset {off} in thin archive {path}") from e
                member = long_names[off:end].rstrip(b"/").decode("utf-8", errors="surrogateescape")
            else:
                member = name.decode("utf-8", errors="surrogateescape").rstrip("/")
            members.append(member)
    return members


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <archive.a>", file=sys.stderr)
        sys.exit(1)

    archive = os.path.abspath(sys.argv[1])
    archive_dir = os.path.dirname(archive)

    try:
        members = thin_archive_members(archive)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

    for member in members:
        print(os.path.join(archive_dir, member))


if __name__ == "__main__":
    main()
