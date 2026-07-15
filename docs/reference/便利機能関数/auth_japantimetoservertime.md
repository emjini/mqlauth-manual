---
title: "日本時間をMT4時間に変換[Auth_JapanTimeToServerTime]"
weDocsId: 5963
modified: 2021-07-10T12:03:22
originalUrl: https://manual.mql-auth.com/docs/reference/%e4%be%bf%e5%88%a9%e6%a9%9f%e8%83%bd%e9%96%a2%e6%95%b0/auth_japantimetoservertime/
---
# 日本時間をMT4時間に変換[Auth_JapanTimeToServerTime]

## Auth\_JapanTimeToServerTime

日本時間をMT4時間（サーバー時間）に変換します。

## 関数書式

```

				
					datetime Auth_JapanTimeToServerTime(
   datetime time,
   MQLAUTHENUM_GMTOFFSET gmtoffset,
   MQLAUTHENUM_SUMMERTIMECOUNTRY summertimecountry
);				
			
```

## パラメータ

time  
   [in] 変換前の時間です。datetime型で指定します。  
gmtoffset  
   [in] サーバー時間のGMTオフセット。[MQLAUTHENUM\_GMTOFFSET型](https://mql-auth.com/Home/Manual#ref15)で指定します。  
summertimecountry  
   [in] サーバー時間のサマータイム基準国。[MQLAUTHENUM\_SUMMERTIMECOUNTRY型](https://mql-auth.com/Home/Manual#ref16)で指定します。

## 戻り値

DateTimet型の日本時間を返します。

## サンプル

```

				
					Auth_JapanTimeToServerTime(TimeLocale(), 2, STC_US);				
			
```

##### こちらの記事で具体的に説明しています。

> [MT4時間と日本時間を相互変換してみよう](https://interactivebrokers.work/jet_lag/)

##### MQLAUTHENUM\_GMTOFFSET型についてはこちらを参照してください。

> [MQLAUTHENUM\_GMTOFFSET列挙型](/reference/enum/mqlauthenum_gmtoffset)

##### MQLAUTHENUM\_SUMMERTIMECOUNTRY型についてはこちらを参照してください。

> [MQLAUTHENUM\_SUMMERTIMECOUNTRY列挙型](/reference/enum/mqlauthenum_summertimecountry)
