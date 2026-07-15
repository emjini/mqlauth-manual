---
title: "MQLAUTHENUM_SUMMERTIMECOUNTRY列挙型"
weDocsId: 5778
modified: 2021-07-10T11:57:58
originalUrl: https://manual.mql-auth.com/docs/reference/enum/mqlauthenum_summertimecountry/
---
# MQLAUTHENUM_SUMMERTIMECOUNTRY列挙型

## サマータイム基準国タイプ

MT4時間と日本時間の切り替えはAuth\_ServerTimeToJapanTime()関数や[Auth\_JapanTimeToServerTime()](https://mql-auth.com/Home/Manual#ref14)関数を使用します。

これらの関数はMQLAUTHENUM\_SUMMERTIMECOUNTRY列挙の値を使用しサマータイム基準国を指定する必要があります。

サマータイム基準国はFXブローカーのウェブサイト等で調べることができます。

| ID | 値 | 詳細 |
| --- | --- | --- |
| STC\_NONE | 0 | なし |
| STC\_US | 1 | アメリカ |
| STC\_EU | 2 | ヨーロッパ |
| STC\_AU | 3 | オーストラリア |
