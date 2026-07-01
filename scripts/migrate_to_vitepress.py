#!/usr/bin/env python3
"""
_source/ からVitePressの docs/ にコンテンツ移行。
- 日本語判定でMQLAuth独自コンテンツのみ抽出
- 親子階層を保持（子を持つ→フォルダ+index.md、葉→単体.md）
- 画像URLをリモート→/images/相対に変換
- 画像を docs/public/images/ にコピー
- .vitepress/sidebar.json を生成
"""
import json
import re
import shutil
import urllib.parse
from pathlib import Path

from markdownify import markdownify as html_to_markdown

ROOT = Path("/home/emipponu/AI-Assistant/projects/mqlauth-manual")
SRC = ROOT / "_source"
DOCS = ROOT / "docs"
VITEPRESS = DOCS / ".vitepress"
PUBLIC_IMG = DOCS / "public" / "images"

BASE_URL = "https://manual.mql-auth.com"

ROOT_TO_DIR = {
    "基本マニュアル": ("manual", "基本マニュアル"),
    "リファレンス": ("reference", "リファレンス"),
    "応用マニュアル": ("advanced", "応用マニュアル"),
}

JAPANESE_RE = re.compile(r"[぀-ヿ一-鿿]")


def has_japanese(text):
    return bool(JAPANESE_RE.search(text or ""))


def clean_title(html):
    if not html:
        return ""
    text = re.sub(r"<[^>]+>", "", html)
    for k, v in [
        ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
        ("&#8211;", "-"), ("&#8217;", "'"), ("&#8220;", '"'), ("&#8221;", '"'),
    ]:
        text = text.replace(k, v)
    return text.strip()


def sanitize(name):
    name = re.sub(r'[\/\\:*?"<>|]', "-", name).strip()
    return name or "untitled"


def make_slug(item):
    raw = item.get("slug", "") or f"id-{item['id']}"
    decoded = urllib.parse.unquote(raw)
    return sanitize(decoded)


def get_root(item, id_map):
    current = item
    seen = set()
    while current and current.get("parent", 0) != 0:
        if current["id"] in seen:
            break
        seen.add(current["id"])
        current = id_map.get(current.get("parent"))
    return current


IMG_PATTERN = re.compile(rf"{re.escape(BASE_URL)}/wp-content/uploads/([^\s\"')>\]]+)")
# WordPress自動生成のサイズsuffix（-1024x376.png等）→ オリジナル参照へ
IMG_SIZE_SUFFIX = re.compile(r"(-\d+x\d+)(\.(?:png|jpg|jpeg|gif|webp|svg))", re.IGNORECASE)


def rewrite_images(md_text):
    text = IMG_PATTERN.sub(r"/images/\1", md_text)
    text = IMG_SIZE_SUFFIX.sub(r"\2", text)
    return text


def html_to_md(html):
    if not html:
        return ""
    return html_to_markdown(
        html,
        heading_style="ATX",
        strip=["script", "style"],
        bullets="-",
    ).strip()


def yaml_str(s):
    if s is None:
        return '""'
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_page(item):
    title = clean_title(item.get("title", {}).get("rendered", ""))
    content_html = item.get("content", {}).get("rendered", "")
    excerpt_html = item.get("excerpt", {}).get("rendered", "")

    body_md = rewrite_images(html_to_md(content_html))
    excerpt_md = rewrite_images(html_to_md(excerpt_html))

    fm = ["---"]
    fm.append(f"title: {yaml_str(title)}")
    if excerpt_md:
        desc = re.sub(r"\s+", " ", excerpt_md).strip()[:160]
        fm.append(f"description: {yaml_str(desc)}")
    fm.append(f"weDocsId: {item['id']}")
    fm.append(f"modified: {item.get('modified', '')}")
    fm.append(f"originalUrl: {item.get('link', '')}")
    fm.append("---")
    fm.append("")

    body = [f"# {title}", ""]
    if excerpt_md:
        body.append(f"> {excerpt_md}")
        body.append("")
    body.append(body_md)
    body.append("")

    return "\n".join(fm) + "\n".join(body)


def copy_images():
    src = SRC / "images" / "wp-content" / "uploads"
    if not src.exists():
        return 0
    if PUBLIC_IMG.exists():
        shutil.rmtree(PUBLIC_IMG)
    PUBLIC_IMG.mkdir(parents=True)
    count = 0
    for f in src.rglob("*"):
        if f.is_file():
            rel = f.relative_to(src)
            dst = PUBLIC_IMG / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, dst)
            count += 1
    return count


def build_home():
    return """---
layout: home
title: MQLAuth マニュアル
titleTemplate: false
description: MT4/MT5用EA・インジケーター認証サービス MQLAuth のドキュメントサイト

hero:
  name: MQLAuth
  text: マニュアル
  tagline: MT4/MT5対応・EA/インジケーター向け口座認証サービス
  actions:
    - theme: brand
      text: 基本マニュアルを読む
      link: /manual/
    - theme: alt
      text: リファレンス
      link: /reference/
    - theme: alt
      text: 応用マニュアル
      link: /advanced/

features:
  - icon: 🔐
    title: 口座認証
    details: MT4/MT5のEAやインジケーターに口座番号認証・パスワード認証を実装できます。
  - icon: 🌐
    title: ブラウザ管理
    details: 認証設定はブラウザから遠隔で管理。コンパイル不要で口座追加・期限変更も可能。
  - icon: 🛡️
    title: ソース非公開OK
    details: マニュアル通りに実装するだけ。ソースコードを外部に見せる必要はありません。
---
"""


def main():
    docs_json = json.loads((SRC / "raw" / "docs.json").read_text(encoding="utf-8"))
    id_map = {d["id"]: d for d in docs_json}

    keep = []
    for d in docs_json:
        title = clean_title(d.get("title", {}).get("rendered", ""))
        root = get_root(d, id_map) or d
        root_title = clean_title(root.get("title", {}).get("rendered", ""))
        if has_japanese(title) or has_japanese(root_title):
            keep.append(d)

    by_root_title = {}
    for d in keep:
        root = get_root(d, id_map) or d
        rt = clean_title(root.get("title", {}).get("rendered", ""))
        by_root_title.setdefault(rt, []).append(d)

    # docs/ 掃除（.vitepressは残す）
    if DOCS.exists():
        for p in DOCS.iterdir():
            if p.name == ".vitepress":
                continue
            if p.is_dir():
                shutil.rmtree(p)
            else:
                p.unlink()
    DOCS.mkdir(parents=True, exist_ok=True)

    n_img = copy_images()
    print(f"画像コピー: {n_img}枚")

    sidebar_config = {}
    total_pages = 0

    for root_title, items in by_root_title.items():
        if root_title not in ROOT_TO_DIR:
            print(f"警告: 未知のroot: {root_title}")
            continue
        dir_slug, dir_label = ROOT_TO_DIR[root_title]
        cat_dir = DOCS / dir_slug
        cat_dir.mkdir(exist_ok=True)

        root_ids = [
            it["id"] for it in items
            if clean_title(it.get("title", {}).get("rendered", "")) == root_title
            and it.get("parent", 0) == 0
        ]
        root_id = root_ids[0] if root_ids else 0

        children_by_parent = {}
        for it in items:
            children_by_parent.setdefault(it.get("parent", 0), []).append(it)
        for group in children_by_parent.values():
            group.sort(key=lambda x: (x.get("menu_order", 0), x["id"]))

        def place(item, current_dir, current_url, out_sidebar):
            nonlocal total_pages
            slug = make_slug(item)
            title = clean_title(item.get("title", {}).get("rendered", ""))
            children = children_by_parent.get(item["id"], [])
            if children:
                item_dir = current_dir / slug
                item_dir.mkdir(exist_ok=True)
                (item_dir / "index.md").write_text(build_page(item), encoding="utf-8")
                total_pages += 1
                url = f"{current_url}/{slug}/"
                sub = []
                for c in children:
                    place(c, item_dir, f"{current_url}/{slug}", sub)
                out_sidebar.append({
                    "text": title,
                    "collapsed": False,
                    "link": url,
                    "items": sub,
                })
            else:
                (current_dir / f"{slug}.md").write_text(build_page(item), encoding="utf-8")
                total_pages += 1
                out_sidebar.append({"text": title, "link": f"{current_url}/{slug}"})

        root_item = id_map.get(root_id)
        if root_item:
            (cat_dir / "index.md").write_text(build_page(root_item), encoding="utf-8")
            total_pages += 1

        top_sidebar = []
        for child in children_by_parent.get(root_id, []):
            place(child, cat_dir, f"/{dir_slug}", top_sidebar)

        sidebar_config[f"/{dir_slug}/"] = [{
            "text": dir_label,
            "collapsed": False,
            "items": top_sidebar,
        }]

    (DOCS / "index.md").write_text(build_home(), encoding="utf-8")

    VITEPRESS.mkdir(parents=True, exist_ok=True)
    (VITEPRESS / "sidebar.json").write_text(
        json.dumps(sidebar_config, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"総ページ数: {total_pages}")
    print(f"サイドバー: {VITEPRESS / 'sidebar.json'}")
    for k in sidebar_config:
        print(f"  {k}")


if __name__ == "__main__":
    main()
