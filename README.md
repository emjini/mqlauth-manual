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
