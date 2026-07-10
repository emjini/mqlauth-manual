---
title: "利用期限付きのEA等を設定する"
weDocsId: 5870
modified: 2026-07-10T13:30:00
originalUrl: https://manual.mql-auth.com/docs/practicalmanual/practice/practice01/
---
# 利用期限付きのEA等を設定する

次のように利用期限とパスワード（パスワード認証用）を設定したユーザーを作り、EA等にパスワード認証を付けることで、期限付きのEA等を設定することができます。

![](/images/v2/users-create-filled.png)

以下のようにパスワード入力用のパラメータを用意し、OnInit()内でパスワード認証用のコードを書くことで、EA等が期限付きになります。

```

				
					input string _password = "abcde";//パスワード

int OnInit()
  {
      if(AuthByPassword_ReturnBool(MQLAUTH_ID, APPLICATION_NAME, _password)) {
         _isAuthorized = true;
         Print("パスワード認証に成功しました。");
      } else {
         _isAuthorized = false;
         Print("パスワード認証に失敗しました。パスワードが間違っています。");
         return(INIT_FAILED);
      }

   return(INIT_SUCCEEDED);
  }				
			
```

ソースコードの全体像は以下のような感じになります。

```

				
					//+------------------------------------------------------------------+
//|  practice1.mq4 
//|  © 2020 MQLAuth. All rights reserved
//|  https://mql-auth.com/ 
//+------------------------------------------------------------------+
#define MQLAUTH_ID ""//必須
#define APPLICATION_NAME ""//必須

#define HTTP_QUERY_FLAG -2147483648
#include <MQLAuth.mqh>

#property copyright "© 2020 MQLAuth. All rights reserved"
#property link      "https://mql-auth.com/ "
#property version   "1.00"
#property strict

input string _password = "abcde";//パスワード

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
      if(AuthByPassword_ReturnBool(MQLAUTH_ID, APPLICATION_NAME, _password)) {
         _isAuthorized = true;
         Print("パスワード認証に成功しました。");
      } else {
         _isAuthorized = false;
         Print("パスワード認証に失敗しました。パスワードが間違っています。");
         return(INIT_FAILED);
      }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // EAの処理
  }				
			
```
