---
title: "体験版機能付口座番号認証(DateTime)[AuthByAccountNumberWithAddUser_ReturnDatetime]"
weDocsId: 5805
modified: 2021-07-10T11:40:03
originalUrl: https://manual.mql-auth.com/docs/reference/auth_func/authbyaccountnumber_returndatetime/
---
# 体験版機能付口座番号認証(DateTime)[AuthByAccountNumberWithAddUser_ReturnDatetime]

## AuthByAccountNumberWithAddUser\_ReturnDatetime

EA等を利用する口座番号が認証可能な期限を取得し、結果をDateTime型で返します。口座番号が存在しない場合は、引数periodを利用期間とした新たなユーザーを作成します。この関数を利用すると、自動的にAccountInfoInteger(ACCOUNT\_LOGIN)から口座番号を取得します。

##### 体験版機能を使う際の注意

この関数を使うには、EA・インジケーターの登録画面で「自動体験版作成機能を有効にする」にチェックを入れる必要があります。チェックを入れていない場合は、認証が失敗します。

## 関数書式

```

				
					datetime AuthByAccountNumberWithAddUser_ReturnDatetime(
   string ManagerName,
   string ApplicationName,
   int period
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

EA等を利用する口座番号の利用期限。データベースアクセス過多等によりエラーになった場合はfalseを返します。

## サンプル

```

				
					datetime period = AuthByAccountNumberWithAddUser_ReturnDatetime(MQLAUTH_ID, APPLICATION_NAME, 7);
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

##### こちらの記事で具体的な使い方を解説しています。

> [自動的に期限付き体験版になる機能をEAに追加する方法](https://interactivebrokers.work/limit/)
