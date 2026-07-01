---
title: "複数の異なるEAを同じ認証情報に紐づける"
weDocsId: 6399
modified: 2024-02-26T10:56:00
originalUrl: https://manual.mql-auth.com/docs/practicalmanual/practice/%e8%a4%87%e6%95%b0%e3%81%ae%e7%95%b0%e3%81%aa%e3%82%8bea%e3%82%92%e5%90%8c%e3%81%98%e8%aa%8d%e8%a8%bc%e6%83%85%e5%a0%b1%e3%81%ab%e7%b4%90%e3%81%a5%e3%81%91%e3%82%8b/
---
# 複数の異なるEAを同じ認証情報に紐づける

複数の異なるEAに対し、同一のEAとして認証を行うことができます。こうすることで、複数のEAをひとつのシリーズとして配布し、EA利用者が口座番号変更した際に全てのEAで変更後の口座番号で認証できるようになります。また、[月額利用料](https://interactivebrokers.work/upgrade/#MQLAuth-4)も1つのEAに登録された口座番号の分で済むため、利用料の節約にもなります。

例えば、“XXXXXXXX-XXXXX-XXXXXXXXXXXXX”というMQLAuthIDのアカウントが“SampleEA”というEAをMQLAuthに登録し、認証をする場合は、インジケーターのソースコードには以下のように記述することになります。

```

				
					#define MQLAUTH_ID "XXXXXXXX-XXXXX-XXXXXXXXXXXXX"
#define APPLICATION_NAME "NewEA"
#include <MQLAuth.mqh>				
			
```

通常であればこの記述はインジケーター毎にAPPLICATION\_NAMEの部分をそれぞれのEA名に変更します。例えば“NewEA”というEAの場合は以下のとおりです。

```

				
					#define MQLAUTH_ID "XXXXXXXX-XXXXX-XXXXXXXXXXXXX"
    #define APPLICATION_NAME "SampleEA"
    #include <MQLAuth.mqh>
				
			
```

ここで、APPLICATION\_NAMEの部分を”NewEA”ではなく”SampleEA”にすることで、“SampleEA”と” NewEA”を同じMQLAuthに登録したEA”SampleEA”として認証することができます。すなわち、同じ口座番号で認証したいEAのソースコード内に記述するAPPLICATION\_NAMEをすべて“SampleEA”と記述すると、MQLAuthに登録するEAは“SampleEA”1つのみで、複数EAを同じ口座番号で認証することができます。
