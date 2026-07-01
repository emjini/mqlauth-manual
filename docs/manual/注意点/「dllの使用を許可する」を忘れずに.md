---
title: "「DLLの使用を許可する」を忘れずに"
weDocsId: 5979
modified: 2021-07-10T12:09:21
originalUrl: https://manual.mql-auth.com/docs/manual/%e6%b3%a8%e6%84%8f%e7%82%b9/%e3%80%8cdll%e3%81%ae%e4%bd%bf%e7%94%a8%e3%82%92%e8%a8%b1%e5%8f%af%e3%81%99%e3%82%8b%e3%80%8d%e3%82%92%e5%bf%98%e3%82%8c%e3%81%9a%e3%81%ab/
---
# 「DLLの使用を許可する」を忘れずに

MQLAuthはデータベースサーバとのやりとりにwininit.dllを利用しています。 そのため、MQLAuthを実装したEA等を使用する場合は、MT4のオプションで「DLLの使用を許可する」にチェックを入れる必要があります。

[![](/images/2021/07/manual_35.png)](/images/2021/07/manual_35.png)
