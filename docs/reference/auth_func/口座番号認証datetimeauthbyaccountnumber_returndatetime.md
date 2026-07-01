---
title: "口座番号認証(DateTime)[AuthByAccountNumber_ReturnDatetime]"
weDocsId: 5797
modified: 2021-07-08T10:01:38
originalUrl: https://manual.mql-auth.com/docs/reference/auth_func/%e5%8f%a3%e5%ba%a7%e7%95%aa%e5%8f%b7%e8%aa%8d%e8%a8%bcdatetimeauthbyaccountnumber_returndatetime/
---
# 口座番号認証(DateTime)[AuthByAccountNumber_ReturnDatetime]

## AuthByAccountNumber\_ReturnDatetime

EA等を利用する口座番号が認証可能かどうかを取得し、結果をDateTime型で返します。この関数を利用すると、自動的にAccountInfoInteger(ACCOUNT\_LOGIN)から口座番号を取得します。

## 関数書式

```

				
					datetime AuthByAccountNumber_ReturnDatetime(
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

EA等を利用する口座番号の利用期限。データベースアクセス過多等によりエラーになった場合はfalseを返します。

## サンプル

```

				
					datetime period = AuthByAccountNumber_ReturnDatetime(MQLAUTH_ID, APPLICATION_NAME);
if(period >= TimeLocal()) {
   Print("[口座番号: " + (string)AccountNumber() + "] 認証に成功しました。"
   + "利用期限は " + TimeToString(period) + " です。");
   isAuthorization = true;
} else {
   Print("[口座番号: " + (string)AccountNumber() + "] 認証に失敗しました。"
   + "利用期限が過ぎているか、この口座番号では利用できません。");
   isAuthorization = false;
}				
			
```
