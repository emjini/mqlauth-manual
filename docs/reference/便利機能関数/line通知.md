---
title: "LINE通知[Auth_LineNotify]"
weDocsId: 5968
modified: 2021-07-10T12:05:53
originalUrl: https://manual.mql-auth.com/docs/reference/%e4%be%bf%e5%88%a9%e6%a9%9f%e8%83%bd%e9%96%a2%e6%95%b0/line%e9%80%9a%e7%9f%a5/
---
# LINE通知[Auth_LineNotify]

## Auth\_LineNotify

LINE通知を送信します。

## パラメータ

```

				
					string Auth_LineNotify(
   string token,
   string message
);				
			
```

## 関数書式

token  
   [in] LINE Notify Token  
message  
   [in] LINE通知するメッセージ

## 戻り値

LINE NotifyからのメッセージをJson形式でそのまま返します。

## サンプル

```

				
					Auth_LineNotify(p_lineNotifyToken, "\nただ今のレート\nBid: " + DoubleToString(Bid, Digits) + "\nAsk: " + DoubleToString(Ask, Digits));				
			
```

##### LINE通知を送信するにはLINE Notify Tokenの取得が必要です。LINE Notify Tokenの取得方法に関してはこちらの記事を参考にして下さい。

> [LineNotifyトークンの取得方法](https://interactivebrokers.work/line_notifiy/)

##### こちらの記事で具体的に説明しています。

> [EA・インジケーターからLINEにメッセージを送信する方法](https://interactivebrokers.work/mt4_line_notify/)
