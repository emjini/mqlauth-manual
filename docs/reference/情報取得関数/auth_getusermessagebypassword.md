---
title: "個別メッセージ取得(パスワード認証ユーザー)[Auth_GetUserMessageByPassword]"
weDocsId: 5940
modified: 2021-07-10T11:52:42
originalUrl: https://manual.mql-auth.com/docs/reference/%e6%83%85%e5%a0%b1%e5%8f%96%e5%be%97%e9%96%a2%e6%95%b0/auth_getusermessagebypassword/
---
# 個別メッセージ取得(パスワード認証ユーザー)[Auth_GetUserMessageByPassword]

## Auth\_GetUserMessageByPassword

パスワード認証を利用するユーザーに設定したメッセージを取得します。

## 関数書式

```

				
					string Auth_GetUserMessageByPassword(
   string ManagerName,
   string ApplicationName,
   string Password
);				
			
```

## パラメータ

ManagerName  
   [in] EA等をMQLAuthに登録したアカウントのMQLAuth ID  
ApplicationName  
   [in] EA等のMQLAuthに登録した名称  
Password  
   [in] パスワード認証のパスワード

## 戻り値

メッセージ内容。データベースアクセス過多等によりエラーになった場合は 空文字 を返します。

## サンプル

```

				
					string message = Auth_GetUserMessageByPassword(MQLAUTH_ID, APPLICATION_NAME, _password);
if(message != "") {
   Comment(message);
}				
			
```

##### こちらの記事で具体的な使い方を解説しています。

> [特定のEA利用者のMT4にメッセージを表示させる方法](https://interactivebrokers.work/messege-pinpoint/)
