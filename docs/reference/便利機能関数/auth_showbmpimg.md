---
title: "BMP画像表示[Auth_ShowBMPIMG]"
weDocsId: 5947
modified: 2021-07-10T11:55:09
originalUrl: https://manual.mql-auth.com/docs/reference/%e4%be%bf%e5%88%a9%e6%a9%9f%e8%83%bd%e9%96%a2%e6%95%b0/auth_showbmpimg/
---
# BMP画像表示[Auth_ShowBMPIMG]

## Auth\_ShowBMPIMG

画像を表示します。

## 関数書式

```

				
					void Auth_ShowBMPIMG(
   string imgpath,
   string imgname,
   ENUM_BASE_CORNER corner = 0,
   int xdistance = 20,
   int ydistance = 20
);				
			
```

## パラメータ

imgpath  
   [in] 画像ファイルの場所  
imgname  
   [in] 画像のオブジェクト名  
corner  
   [in] 画像を表示する位置  
xdistance = 20  
   [in] 画像のX軸の表示位置  
xdistance = 20  
   [in] 画像のY軸の表示位置

## 戻り値

なし

## サンプル

```

				
					Auth_ShowBMPIMG("\\Include\\Images\\MQLAuthLogo.bmp", "MQLAuth_LOGO", CORNER_LEFT_LOWER);				
			
```

##### こちらの記事で具体的な使い方を解説しています。

> [BMP画像を簡単にMT4のチャートに表示させる方法](https://interactivebrokers.work/bmp/)
