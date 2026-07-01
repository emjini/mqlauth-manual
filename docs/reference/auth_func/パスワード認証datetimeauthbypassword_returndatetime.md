---
title: "パスワード認証(DateTime)[AuthByPassword_ReturnDatetime]"
weDocsId: 5918
modified: 2021-07-10T11:42:58
originalUrl: https://manual.mql-auth.com/docs/reference/auth_func/%e3%83%91%e3%82%b9%e3%83%af%e3%83%bc%e3%83%89%e8%aa%8d%e8%a8%bcdatetimeauthbypassword_returndatetime/
---
# パスワード認証(DateTime)[AuthByPassword_ReturnDatetime]

## AuthByPassword\_ReturnDatetime

入力されたパスワードが正しいかを取得し、正しければ利用期限の結果をDateTime型で返します。

## 関数書式

```

				
					datetime AuthByPassword_ReturnDatetime(
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
period  
   [in] 新たに作成される体験版ユーザーの期間

## 戻り値

パスワードが正しい場合はEA等の利用期限、それ以外の場合はfalse。データベースアクセス過多等によりエラーになった場合もfalseを返します。

## サンプル

```

				
					datetime period = AuthByPassword_ReturnDatetime(MQLAUTH_ID, APPLICATION_NAME, _password);
if(period >= TimeLocal()) {
   Print("[Password: " + _password + "] 認証に成功しました。"
   + "利用期限は " + TimeToString(period) + " です。");
} else {
   Print("[Password: " + _password + "] 認証に失敗しました。"
   + "利用期限が過ぎているか、パスワードが間違っています。");
   return(INIT_FAILED);
}				
			
```
