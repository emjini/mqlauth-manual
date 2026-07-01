#!/usr/bin/env python3
"""
raw/*.jsonから、MQLAuth独自コンテンツのみ抽出（Doclyデモを除外）。

判定基準:
1. docs: root（親をたどった一番上）が日本語タイトル → MQLAuth本物
   root自身が日本語タイトルなら残す。roolが英語のみならDoclyデモ扱いで除外
2. pages: タイトルが日本語 → 残す。既知のDocly系スラッグは強制除外
3. posts: タイトルが日本語 → 残す

出力:
- markdown_clean/{docs,pages,posts}/  ... 残した記事のみ
- logs/removed.txt                    ... 除外した記事一覧（目視確認用）
- index_clean.md                      ... 整理後の目次
"""
import json
import re
import shutil
from pathlib import Path

OUT = Path("/home/emipponu/AI-Assistant/projects/mqlauth-manual")
RAW = OUT / "raw"
MD = OUT / "markdown"
MD_CLEAN = OUT / "markdown_clean"
LOG = OUT / "logs" / "removed.txt"

# 既知のDocly/一般テーマデモ系pageスラッグ
DOCLY_PAGE_SLUGS = {
    "home-cool", "home-light", "home-help-desk",
    "docs", "forums", "blog", "ask-question",
    "signup", "sign-in",  # 認証系はテーマデモ（本サービスは別ドメイン）
    "onepage-documentation", "products",
    "stripe-checkout-result",
    "5724-2",  # IDのみのゴミページ候補
}

JAPANESE_RE = re.compile(r"[぀-ヿ一-鿿]")


def has_japanese(text):
    return bool(JAPANESE_RE.search(text or ""))


def clean_title(html):
    if not html:
        return ""
    text = re.sub(r"<[^>]+>", "", html)
    text = text.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    text = text.replace("&#8211;", "-").replace("&#8217;", "'").replace("&#8220;", '"').replace("&#8221;", '"')
    return text.strip()


def load_items(name):
    return json.loads((RAW / f"{name}.json").read_text(encoding="utf-8"))


def slugify(text, maxlen=80):
    if not text:
        return "untitled"
    text = re.sub(r"[^\w\-]", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text[:maxlen] or "untitled"


def get_root(item, id_to_item):
    seen = set()
    current = item
    while current and current.get("parent", 0) != 0:
        if current["id"] in seen:
            break
        seen.add(current["id"])
        parent_id = current.get("parent")
        current = id_to_item.get(parent_id)
    return current


def copy_markdown(items, src_subdir, dst_subdir):
    src_dir = MD / src_subdir
    dst_dir = MD_CLEAN / dst_subdir
    dst_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    used = set()
    for it in items:
        raw_slug = it.get("slug") or f"id-{it['id']}"
        slug = slugify(raw_slug)
        base = slug
        n = 1
        while slug in used:
            n += 1
            slug = f"{base}-{n}"
        used.add(slug)
        src_path = src_dir / f"{slug}.md"
        if not src_path.exists():
            print(f"  !! 元ファイルなし: {src_path}")
            continue
        shutil.copy2(src_path, dst_dir / f"{slug}.md")
        count += 1
    return count


def build_clean_index(kept_docs, kept_pages, kept_posts):
    lines = ["# MQLAuthマニュアル（クリーン版目次）", ""]
    lines.append("Docly テーマデモを除外した、MQLAuth独自のコンテンツのみの目次です。")
    lines.append("")

    # docs
    lines.append(f"## Docs（{len(kept_docs)}件）")
    lines.append("")
    by_parent = {}
    for d in kept_docs:
        by_parent.setdefault(d.get("parent", 0), []).append(d)
    for group in by_parent.values():
        group.sort(key=lambda x: (x.get("menu_order", 0), x.get("id", 0)))

    kept_ids = {d["id"] for d in kept_docs}
    seen = set()

    def render(pid, depth):
        for c in by_parent.get(pid, []):
            cid = c.get("id")
            if cid in seen:
                continue
            seen.add(cid)
            title = clean_title(c.get("title", {}).get("rendered", ""))
            slug = slugify(c.get("slug") or f"id-{cid}")
            indent = "  " * depth
            lines.append(f"{indent}- [{title}](markdown_clean/docs/{slug}.md)")
            render(cid, depth + 1)

    render(0, 0)
    # 親が除外され孤立した子（root不明扱い）は末尾に
    for d in kept_docs:
        if d["id"] not in seen:
            parent = d.get("parent", 0)
            title = clean_title(d.get("title", {}).get("rendered", ""))
            slug = slugify(d.get("slug") or f"id-{d['id']}")
            lines.append(f"- [{title}](markdown_clean/docs/{slug}.md)  _(親除外 id={parent})_")
    lines.append("")

    for label, items, sub in [("Pages", kept_pages, "pages"), ("Posts", kept_posts, "posts")]:
        lines.append(f"## {label}（{len(items)}件）")
        lines.append("")
        for it in items:
            title = clean_title(it.get("title", {}).get("rendered", ""))
            slug = slugify(it.get("slug") or f"id-{it['id']}")
            lines.append(f"- [{title}](markdown_clean/{sub}/{slug}.md)")
        lines.append("")

    (OUT / "index_clean.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    docs = load_items("docs")
    pages = load_items("pages")
    posts = load_items("posts")
    id_to_doc = {d["id"]: d for d in docs}

    removed_lines = ["# 除外したコンテンツ一覧（Docly テーマデモ / 英語のみ）", ""]

    # docs判定: rootが日本語 or 自分が日本語なら残す
    kept_docs = []
    removed_docs = []
    for d in docs:
        title = clean_title(d.get("title", {}).get("rendered", ""))
        root = get_root(d, id_to_doc) or d
        root_title = clean_title(root.get("title", {}).get("rendered", ""))
        if has_japanese(title) or has_japanese(root_title):
            kept_docs.append(d)
        else:
            removed_docs.append((d["id"], title, root_title, d.get("slug", "")))

    removed_lines.append(f"## Docs 除外 {len(removed_docs)} 件")
    removed_lines.append("")
    for i, t, rt, slg in removed_docs:
        removed_lines.append(f"- id={i} slug={slg} title=\"{t}\" (root=\"{rt}\")")
    removed_lines.append("")

    # pages判定: 日本語タイトル or Docly強制除外リストに無ければ残す
    # ただしタイトル英語でも重要そうなpage（例: contact, privacy-policy）は残す
    ALWAYS_KEEP_PAGES = {"contact", "privacy-policy", "register", "sign-in"}  # 一応残す
    kept_pages = []
    removed_pages = []
    for p in pages:
        title = clean_title(p.get("title", {}).get("rendered", ""))
        slug = p.get("slug", "")
        if slug in DOCLY_PAGE_SLUGS:
            removed_pages.append((p["id"], title, slug, "Doclyデモ既知"))
            continue
        if slug in ALWAYS_KEEP_PAGES or has_japanese(title):
            kept_pages.append(p)
        else:
            removed_pages.append((p["id"], title, slug, "英語タイトル"))

    removed_lines.append(f"## Pages 除外 {len(removed_pages)} 件")
    removed_lines.append("")
    for i, t, slg, reason in removed_pages:
        removed_lines.append(f"- id={i} slug={slg} title=\"{t}\" ({reason})")
    removed_lines.append("")

    # posts判定: 日本語タイトルなら残す
    kept_posts = []
    removed_posts = []
    for p in posts:
        title = clean_title(p.get("title", {}).get("rendered", ""))
        if has_japanese(title):
            kept_posts.append(p)
        else:
            removed_posts.append((p["id"], title, p.get("slug", "")))

    removed_lines.append(f"## Posts 除外 {len(removed_posts)} 件")
    removed_lines.append("")
    for i, t, slg in removed_posts:
        removed_lines.append(f"- id={i} slug={slg} title=\"{t}\"")

    # markdown_clean/ を作り直し
    if MD_CLEAN.exists():
        shutil.rmtree(MD_CLEAN)

    n_docs = copy_markdown(kept_docs, "docs", "docs")
    n_pages = copy_markdown(kept_pages, "pages", "pages")
    n_posts = copy_markdown(kept_posts, "posts", "posts")

    build_clean_index(kept_docs, kept_pages, kept_posts)

    LOG.write_text("\n".join(removed_lines), encoding="utf-8")

    print(f"Docs:  保持 {n_docs} / 除外 {len(removed_docs)}")
    print(f"Pages: 保持 {n_pages} / 除外 {len(removed_pages)}")
    print(f"Posts: 保持 {n_posts} / 除外 {len(removed_posts)}")
    print(f"除外リスト: {LOG}")
    print(f"クリーン目次: {OUT / 'index_clean.md'}")


if __name__ == "__main__":
    main()
