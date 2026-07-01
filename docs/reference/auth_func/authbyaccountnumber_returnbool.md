---
title: "口座番号認証(bool)[AuthByAccountNumber_ReturnBool]"
weDocsId: 5785
modified: 2021-07-08T09:59:17
originalUrl: https://manual.mql-auth.com/docs/reference/auth_func/authbyaccountnumber_returnbool/
---
# 口座番号認証(bool)[AuthByAccountNumber_ReturnBool]

## AuthByAccountNumber\_ReturnBool

EA等を利用する口座番号が認証可能かどうかを取得し、結果をbool型で返します。この関数を利用すると、自動的にAccountInfoInteger(ACCOUNT\_LOGIN)から口座番号を取得します。

## 関数書式

```

				
					bool AuthByAccountNumber_ReturnBool(
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

認証成功の場合はtrue、それ以外の場合はfalse。データベースアクセス過多等によりエラーになった場合もfalseを返します。

## サンプル

```

				
					if(AuthByAccountNumber_ReturnBool(MQLAUTH_ID, APPLICATION_NAME)) {
   Print("[口座番号: " + (string)AccountNumber() + "] 認証に成功しました。");
   isAuthorization = true;
} else {
   Print("[口座番号: " + (string)AccountNumber() + "] 認証に失敗しました。"
   + "利用期限が過ぎているか、この口座番号では利用できません。");
   isAuthorization = false;
}				
			
```
