#!/usr/bin/env python3
"""
MQLAuthマニュアルサイト（https://manual.mql-auth.com）から全コンテンツを取得し、
JSON生データ + Markdown化 + 画像ダウンロード + 目次 を出力する。
"""
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import requests
from markdownify import markdownify as html_to_markdown

BASE = "https://manual.mql-auth.com"
API = f"{BASE}/wp-json/wp/v2"
OUT = Path("/home/emipponu/AI-Assistant/projects/mqlauth-manual")
RAW = OUT / "raw"
MD = OUT / "markdown"
IMG = OUT / "images"

CONTENT_TYPES = ["docs", "pages", "posts", "faq", "categories", "tags"]
MEDIA_ENDPOINT = "media"

HEADERS = {
    "User-Agent": "MQLAuth-Manual-Backup/1.0 (contact: emipponu@gmail.com)"
}


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def fetch_all(endpoint, per_page=100):
    results = []
    page = 1
    while True:
        url = f"{API}/{endpoint}"
        params = {"per_page": per_page, "page": page, "_embed": 0}
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=60)
        except requests.RequestException as e:
            log(f"  API取得エラー {endpoint} page {page}: {e}")
            break
        if r.status_code == 400 and "rest_post_invalid_page_number" in r.text:
            break
        if r.status_code == 404:
            log(f"  {endpoint}: 存在しない（404）")
            return None
        if r.status_code != 200:
            log(f"  {endpoint} page {page}: HTTP {r.status_code}")
            break
        batch = r.json()
        if not batch:
            break
        results.extend(batch)
        total_pages = int(r.headers.get("X-WP-TotalPages", 1) or 1)
        total = r.headers.get("X-WP-Total", "?")
        log(f"  {endpoint} page {page}/{total_pages} (累計 {len(results)}/{total})")
        if page >= total_pages:
            break
        page += 1
        time.sleep(0.3)
    return results


def slugify(text, maxlen=80):
    if not text:
        return "untitled"
    text = re.sub(r"[^\w\-]", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text[:maxlen] or "untitled"


def clean_title(html):
    if not html:
        return ""
    text = re.sub(r"<[^>]+>", "", html)
    text = text.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    text = text.replace("&#8211;", "-").replace("&#8217;", "'").replace("&#8220;", '"').replace("&#8221;", '"')
    return text.strip()


def html_to_md(html):
    if not html:
        return ""
    return html_to_markdown(
        html,
        heading_style="ATX",
        strip=["script", "style"],
        bullets="-",
    ).strip()


def yaml_escape(s):
    if not s:
        return ""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def save_items_as_markdown(items, kind):
    if not items:
        return 0
    kind_dir = MD / kind
    kind_dir.mkdir(parents=True, exist_ok=True)
    used_slugs = set()
    count = 0
    for item in items:
        item_id = item.get("id")
        raw_slug = item.get("slug") or f"id-{item_id}"
        slug = slugify(raw_slug)
        # slug衝突対策
        base_slug = slug
        n = 1
        while slug in used_slugs:
            n += 1
            slug = f"{base_slug}-{n}"
        used_slugs.add(slug)

        title_html = (item.get("title") or {}).get("rendered", "")
        title = clean_title(title_html)
        content_html = (item.get("content") or {}).get("rendered", "")
        excerpt_html = (item.get("excerpt") or {}).get("rendered", "")
        content_md = html_to_md(content_html)
        excerpt_md = html_to_md(excerpt_html)
        parent = item.get("parent", 0)
        menu_order = item.get("menu_order", 0)
        link = item.get("link", "")
        date = item.get("date", "")
        modified = item.get("modified", "")
        status = item.get("status", "")

        fm = [
            "---",
            f"id: {item_id}",
            f'title: "{yaml_escape(title)}"',
            f"slug: {raw_slug}",
            f"kind: {kind}",
            f"parent: {parent}",
            f"menu_order: {menu_order}",
            f"status: {status}",
            f"date: {date}",
            f"modified: {modified}",
            f"original_url: {link}",
        ]
        cats = item.get("doc_category") or item.get("categories")
        if cats:
            fm.append(f"categories: {cats}")
        tags = item.get("tags")
        if tags:
            fm.append(f"tags: {tags}")
        fm.append("---")
        fm.append("")

        body = [f"# {title}", ""]
        if excerpt_md:
            body.append(f"> {excerpt_md}")
            body.append("")
        body.append(content_md)
        body.append("")

        out_path = kind_dir / f"{slug}.md"
        out_path.write_text("\n".join(fm) + "\n".join(body), encoding="utf-8")
        count += 1
    return count


def download_media(media_items):
    if not media_items:
        return 0
    ok, skip, fail = 0, 0, 0
    for m in media_items:
        url = m.get("source_url")
        if not url:
            continue
        parsed = urlparse(url)
        if not parsed.netloc.endswith("mql-auth.com"):
            continue
        rel = parsed.path.lstrip("/")
        if not rel.startswith("wp-content/uploads/"):
            skip += 1
            continue
        dest = IMG / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists() and dest.stat().st_size > 0:
            skip += 1
            continue
        try:
            r = requests.get(url, headers=HEADERS, timeout=60)
            if r.status_code == 200:
                dest.write_bytes(r.content)
                ok += 1
            else:
                fail += 1
                log(f"  画像取得失敗 HTTP {r.status_code}: {url}")
        except Exception as e:
            fail += 1
            log(f"  画像取得エラー: {url}: {e}")
        time.sleep(0.15)
        if (ok + fail) % 25 == 0 and ok + fail:
            log(f"  画像: OK {ok} / skip {skip} / fail {fail}")
    log(f"  画像完了: OK {ok} / skip {skip} / fail {fail}")
    return ok


def build_index(data):
    lines = ["# MQLAuthマニュアル コンテンツ目次", ""]
    lines.append(f"取得日時: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")
    for kind in CONTENT_TYPES + [MEDIA_ENDPOINT]:
        items = data.get(kind)
        if items is None:
            continue
        lines.append(f"- {kind}: {len(items)}件")
    lines.append("")

    docs = data.get("docs") or []
    if docs:
        lines.append("## Docs（weDocs マニュアル本体）")
        lines.append("")
        by_parent = {}
        for d in docs:
            by_parent.setdefault(d.get("parent", 0), []).append(d)
        for group in by_parent.values():
            group.sort(key=lambda x: (x.get("menu_order", 0), x.get("id", 0)))

        seen = set()
        def render(pid, depth):
            for c in by_parent.get(pid, []):
                cid = c.get("id")
                if cid in seen:
                    continue
                seen.add(cid)
                title = clean_title((c.get("title") or {}).get("rendered", ""))
                slug = slugify(c.get("slug") or f"id-{cid}")
                indent = "  " * depth
                lines.append(f"{indent}- [{title}](markdown/docs/{slug}.md)")
                render(cid, depth + 1)
        render(0, 0)
        for d in docs:
            if d.get("id") not in seen:
                title = clean_title((d.get("title") or {}).get("rendered", ""))
                slug = slugify(d.get("slug") or f"id-{d.get('id')}")
                lines.append(f"- [{title}](markdown/docs/{slug}.md)  _(親不明)_")
        lines.append("")

    for kind_label, kind_key in [("Pages", "pages"), ("Posts", "posts"), ("FAQ", "faq")]:
        items = data.get(kind_key)
        if not items:
            continue
        lines.append(f"## {kind_label}（{len(items)}件）")
        lines.append("")
        for it in items:
            title = clean_title((it.get("title") or {}).get("rendered", ""))
            slug = slugify(it.get("slug") or f"id-{it.get('id')}")
            lines.append(f"- [{title}](markdown/{kind_key}/{slug}.md)")
        lines.append("")

    (OUT / "index.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    log(f"出力先: {OUT}")
    data = {}

    # 1. コンテンツ取得
    for kind in CONTENT_TYPES:
        log(f"取得: {kind}")
        items = fetch_all(kind)
        if items is None:
            continue
        data[kind] = items
        (RAW / f"{kind}.json").write_text(
            json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    # 2. メディア
    log("取得: media")
    media = fetch_all(MEDIA_ENDPOINT)
    if media is not None:
        data[MEDIA_ENDPOINT] = media
        (RAW / f"{MEDIA_ENDPOINT}.json").write_text(
            json.dumps(media, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    # 3. Markdown化
    log("Markdown化")
    for kind in ["docs", "pages", "posts", "faq"]:
        if kind in data:
            n = save_items_as_markdown(data[kind], kind)
            log(f"  {kind}: {n} ファイル出力")

    # 4. 画像
    log("画像ダウンロード")
    download_media(data.get(MEDIA_ENDPOINT, []))

    # 5. 目次
    log("index.md 生成")
    build_index(data)

    log("完了")


if __name__ == "__main__":
    main()
