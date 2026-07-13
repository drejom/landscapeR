#!/usr/bin/env python3
"""Fail when a rendered pkgdown article references a missing local image."""

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse
import argparse


class ImageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.sources: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "img":
            return
        source = dict(attrs).get("src")
        if source:
            self.sources.append(source)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--site-root", required=True, type=Path)
    parser.add_argument("article", type=Path)
    args = parser.parse_args()

    site_root = args.site_root.resolve()
    article = args.article.resolve()
    if not article.is_relative_to(site_root):
        raise SystemExit(f"article is outside site root: {article}")
    images = ImageParser()
    images.feed(article.read_text(encoding="utf-8"))
    if not images.sources:
        raise SystemExit(f"no images found in {article}")

    missing: list[str] = []
    for source in images.sources:
        parsed = urlparse(source)
        if parsed.scheme or source.startswith("//") or source.startswith("data:"):
            continue
        image = (article.parent / unquote(parsed.path)).resolve()
        if not image.is_relative_to(site_root):
            missing.append(f"{source} -> outside site root ({image})")
        elif not image.is_file():
            missing.append(f"{source} -> {image}")

    if missing:
        raise SystemExit("missing local article images:\n" + "\n".join(missing))
    print(f"verified {len(images.sources)} image reference(s) in {article}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
