---
title: "最新バージョン取得[Auth_GetNewestVersion]"
weDocsId: 5924
modified: 2021-07-10T11:45:14
originalUrl: https://manual.mql-auth.com/docs/reference/%e6%83%85%e5%a0%b1%e5%8f%96%e5%be%97%e9%96%a2%e6%95%b0/%e6%9c%80%e6%96%b0%e3%83%90%e3%83%bc%e3%82%b8%e3%83%a7%e3%83%b3%e5%8f%96%e5%be%97auth_getnewestversion/
---
# 最新バージョン取得[Auth_GetNewestVersion]

## Auth\_GetNewestVersion

EA等の管理画面に設定した最新バージョン番号とダウンロードURLを取得します。

## 関数書式

```

				
					string Auth_GetNewestVersion(
   string ManagerName,
   string ApplicationName,
   string &downloadurl
);				
			
```

## パラメータ

ManagerName  
   [in] EA等をMQLAuthに登録したアカウントのMQLAuth ID  
ApplicationName  
   [in] EA等のMQLAuthに登録した名称  
downloadurl  
   [out] EA等のMQLAuthに登録したダウンロードURL

## 戻り値

バージョン番号。データベースアクセス過多等によりエラーになった場合は 空文字 を返します。

## サンプル

```

				
					string downloadurl;
string newestVersion = Auth_GetNewestVersion(APPLICATION_NAME, downloadurl);
if(VERSION != newestVersion) {
   Alert("最新バージョンは " + newestVersion + " です。\r\n"
   + "最新バージョンのファイルは " + downloadurl + " からダウンロードすることができます。");
}				
			
```

##### こちらの記事で具体的な使い方を解説しています。

> [EAアップデート時に自動でMT4のアラートを表示する機能を追加する](https://interactivebrokers.work/update-announces/)
