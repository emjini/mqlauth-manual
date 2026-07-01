---
title: "一斉メッセージ取得[Auth_GetApplicationMessage]"
weDocsId: 5930
modified: 2021-07-10T11:47:43
originalUrl: https://manual.mql-auth.com/docs/reference/%e6%83%85%e5%a0%b1%e5%8f%96%e5%be%97%e9%96%a2%e6%95%b0/auth_getapplicationmessage/
---
# 一斉メッセージ取得[Auth_GetApplicationMessage]

## Auth\_GetApplicationMessage

EA等の管理画面に設定した一斉メッセージの内容を取得します。

##### 体験版機能を使う際の注意

この関数を使うには、EA・インジケーターの登録画面で「自動体験版作成機能を有効にする」にチェックを入れる必要があります。チェックを入れていない場合は、認証が失敗します。

## 関数書式

```

				
					string Auth_GetApplicationMessage(
   string ManagerName,
   string ApplicationName
);				
			
```

## パラメータ

ManagerName  
   [in] EA等をMQLAuthに登録したアカウントのMQLAuth ID  
ApplicationName  
   [in] EA等のMQLAuthに登録した名称

## 戻り値

メッセージ内容。データベースアクセス過多等によりエラーになった場合は 空文字 を返します。

## サンプル

```

				
					string message = Auth_GetApplicationMessage(MQLAUTH_ID, APPLICATION_NAME);
if(message != "") {
   Comment(message);
}				
			
```

##### こちらの記事で具体的な使い方を解説しています。

> [配布したEA利用者のMT4にメッセージを一斉配信する方法](https://interactivebrokers.work/messege-ea/)
