---
title: "パスワード認証(bool)[AuthByPassword_ReturnBool]"
weDocsId: 5911
modified: 2021-07-10T11:39:56
originalUrl: https://manual.mql-auth.com/docs/reference/auth_func/%e3%83%91%e3%82%b9%e3%83%af%e3%83%bc%e3%83%89%e8%aa%8d%e8%a8%bcboolauthbypassword_returnbool/
---
# パスワード認証(bool)[AuthByPassword_ReturnBool]

## AuthByPassword\_ReturnBool

入力されたパスワードが正しいかを取得し、結果をbool型で返します。

## 関数書式

```

				
					bool AuthByPassword_ReturnBool(
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
   [in] EA等のMQLAuthに登録した認証用パスワード

## 戻り値

パスワードが正しい場合はtrue、それ以外の場合はfalse。データベースアクセス過多等によりエラーになった場合もfalseを返します。

## サンプル

```

				
					if(AuthByPassword_ReturnBool(MQLAUTH_ID, APPLICATION_NAME, _password)) {
   Print("[Password: " + _password + "] 認証に成功しました。");
} else {
   Print("[Password: " + _password + "] 認証に失敗しました。"
   + "利用期限が過ぎているか、パスワードが間違っています。");
   return(INIT_FAILED);
}				
			
```
