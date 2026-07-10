# MQLAuth マニュアル

MT4/MT5用EA・インジケーター認証サービス [MQLAuth](https://mql-auth.com/) のドキュメントサイト。

## 開発

```bash
npm install
npm run docs:dev
```

http://localhost:5173/ で開発サーバー起動。

## ビルド

```bash
npm run docs:build
```

`docs/.vitepress/dist/` に出力。

## デプロイ

Cloudflare Pages 経由で自動デプロイ（master push トリガー）。

## AI向け実装ガイドの同期ルール

`docs/public/llms-install.md` を更新したら、**必ず同内容を `docs/public/llms-install.txt` にコピーする**（URLを読めないAIへのファイル添付用。ai-implementation ページからダウンロードリンクあり）。

```bash
cp docs/public/llms-install.md docs/public/llms-install.txt
```

`docs/public/MQLAuthBoilerplate.mqh` はMQLAuth認証の標準実装（配布物）。ガイドのStep構成とセットなので、変更時は llms-install.md 側の手順・バージョン表記との整合を確認する。
