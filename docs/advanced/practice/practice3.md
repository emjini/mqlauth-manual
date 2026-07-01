---
title: "アクセスする毎にデータの取得を行う"
weDocsId: 6027
modified: 2024-02-26T10:46:21
originalUrl: https://manual.mql-auth.com/docs/practicalmanual/practice/practice3/
---
# アクセスする毎にデータの取得を行う

MQLAuthはデフォルトでは2回目の認証以降はキャッシュを使うため、1日ごとに認証を行う等、MT4を起動してから一定期間ごとに認証を行う場合は、実装するEAに以下のコードを追記する必要があります。

```

				
					#define HTTP_QUERY_FLAG -2147483648				
			
```

このコードは、必ずMQLAuth.mqhをインクルードするコードの前に追加してください。

[![](/images/2021/07/manual_117.png)](/images/2021/07/manual_117.png)
