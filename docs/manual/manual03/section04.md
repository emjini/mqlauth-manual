---
title: "EAのソースコードに認証用のコードを追加"
weDocsId: 5678
modified: 2021-07-12T13:15:51
originalUrl: https://manual.mql-auth.com/docs/manual/manual03/section04/
---
# EAのソースコードに認証用のコードを追加

## ステップ1 ソースコード先頭に追記

MQLソースコードの先頭に以下の3行を追加します。

```

				
					#define MQLAUTH_ID "先ほどメモした「MQLAuth ID」"
#define APPLICATION_NAME "MQLAuthに登録するEAの名称"
#include <MQLAuth.mqh>				
			
```

## ステップ2 OnInit()に追記

口座認証はタイマーを利用するため、OnInit()に以下のソースコードを追加します。

```

				
					EventSetTimer(1);				
			
```

## ステップ3 OnTimer()の実装

OnTimer()に以下のソースコードを追加します。この例では、最初の認証の後、タイマーを1日後にセットしています。

```

				
					if(AccountNumber() != 0) {
    if(AuthByAccountNumber_ReturnBool(MQLAUTH_ID, APPLICATION_NAME)) {
      // 認証に成功した場合の処理をここに書く
      Print("[口座番号: " + (string)AccountNumber() + "] 認証に成功しました。");
    } else {
      // 認証に失敗した場合の処理をここに書く
      Print("[口座番号: " + (string)AccountNumber() 
      + "] 認証に失敗しました。利用期限が過ぎているか、この口座番号では利用できません。");
    }
    EventSetTimer(86400);
}				
			
```

OnTimer()がない場合は、以下のソースコードを追加します。

```

				
					void OnTimer() {
    if(AccountNumber() != 0) {
        if(AuthByAccountNumber_ReturnBool(MQLAUTH_ID, APPLICATION_NAME)) {
            // 認証に成功した場合の処理をここに書く
            Print("[口座番号: " + (string)AccountNumber() + "] 認証に成功しました。");
        } else {
            // 認証に失敗した場合の処理をここに書く
            Print("[口座番号: " + (string)AccountNumber() 
            + "] 認証に失敗しました。利用期限が過ぎているか、この口座番号では利用できません。");
        }
        EventSetTimer(86400);
    }
}				
			
```

MQLソースコードの追加は以上です。

[<< 前の項目 MQLAuthインクルードファイルのダウンロード](https://manual.mql-auth.com/docs/rogan-documentation/manual03/section03/)

[次の項目 MQLAuthに口座縛りをする口座番号を登録 >>](https://manual.mql-auth.com/docs/rogan-documentation/manual03/section05/)
