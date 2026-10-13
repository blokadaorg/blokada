#!/usr/bin/env python3
"""Copy one file between local disk and a gs:// object: gcs.py SRC DST."""
import sys

from google.cloud import storage


def split(uri):
    bucket, _, name = uri[len("gs://"):].partition("/")
    return storage.Client().bucket(bucket).blob(name)


def main(argv):
    if len(argv) != 3:
        sys.exit("usage: gcs.py SRC DST (one of them gs://bucket/object)")
    src, dst = argv[1], argv[2]
    if src.startswith("gs://"):
        split(src).download_to_filename(dst)
    elif dst.startswith("gs://"):
        split(dst).upload_from_filename(src)
    else:
        sys.exit("one side must be gs://")


if __name__ == "__main__":
    main(sys.argv)
