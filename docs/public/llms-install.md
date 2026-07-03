# MQLAuth 実装ガイド（AIコーディングアシスタント向け）

このドキュメントは、AIコーディングアシスタント（Claude Code、Cursor、ChatGPT、GitHub Copilot等）が、ユーザーのMQL4/MQL5ソースコードにMQLAuth認証を実装するための手順書です。人間向けマニュアルは https://manual.mql-auth.com/ にあります。

対応バージョン: MQLAuth.mqh v1.09以降（2026年7月時点の配布版）

## MQLAuthとは

- MT4/MT5のEA・インジケーター向け認証サービス（https://mql-auth.com）
- EA・インジケーターの利用者をMT口座番号で認証し、利用者ごとに利用期限を設定できる
- 販売者はMQLAuthのWeb管理画面で利用者の口座番号・期限を登録する
- 認証はHTTPS経由（wininet.dll使用）でMQLAuthサーバーに問い合わせる

## この実装で追加される機能

本ガイドの標準実装（付録のボイラープレートコード）により、対象のEA・インジケーターに以下が追加される。

1. **口座番号認証** — 登録済み口座番号かつ期限内のときだけ動作。認証結果はローカルにキャッシュされ、同日中の再起動ではサーバーアクセスなしで認証される
2. **利用期限表示** — 認証成功時にエキスパートログへ期限を出力。期限切れ時はチャート上にメッセージを表示
3. **一斉メッセージ / 個別メッセージ** — 管理画面から配信したメッセージをチャート上に表示（クリックでURLオープン）
4. **アップデート通知** — 新バージョン公開時にチャート上へお知らせを表示
5. **体験版機能（オプション）** — 未登録口座を初回起動時に自動登録し、指定日数だけ利用可能にする
6. **PayPal連携・ロゴ表示（オプション）** — 期限切れ時の決済ページ誘導、チャートへのロゴ表示

## 実装前にユーザーに確認する情報

以下が提示されていない場合、**推測で埋めずに必ずユーザーに確認すること**。

1. **MQLAuth ID** — 管理画面で確認できるGUID形式のID（例: `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`）
2. **アプリケーション名** — MQLAuthの管理画面に登録したEA・インジケーターの名称（登録名と完全一致が必要）
3. （任意）体験版機能を使うか、使う場合の日数。指定がなければ体験版オフで実装する

## 前提条件（ユーザー環境）

- `MQLAuth.mqh` が `MQL4/Include/`（MT5は `MQL5/Include/`）に配置されていること（https://mql-auth.com の上部メニュー「ダウンロード」から入手）
- MT4/MT5で「DLLの使用を許可する」が必要（wininet.dll・shell32.dllを使用するため）。コードでの対応は不要だが、検証手順に含めること

## Step 0: 対象ソースコードの判別

実装前に、渡されたソースコードについて以下を判別する。

**EAかインジケーターか**
- `OnTick()` がある、`OrderSend` 等の注文関数を使う → EA
- `OnCalculate()` や `#property indicator_buffers` がある → インジケーター

**MQL4かMQL5か**
- 拡張子 `.mq4` → MQL4、`.mq5` → MQL5
- MQL5の場合は「MQL5の場合の追加手順」も適用する

**旧形式MQL4（Build 600以前の書き方）か**
- `#property strict` がなく、`init()` / `start()` / `deinit()` を使用 → 旧形式
- 旧形式でも実装可能（現行コンパイラは新旧混在を許容する）。`OnInit→init`、`OnDeinit→deinit`、`OnTick→start` と読み替える。`OnTimer` / `OnChartEvent` は旧形式には存在しないため、本ガイドの内容で新規追加する

## Step 1: ファイル先頭にdefineとincludeを追加

ソースコードの最上部に以下を追加する。

```mql4
#define MQLAUTH_ID "ここにユーザーのMQLAuth IDを入れる"
#define APPLICATION_NAME "ここに登録済みアプリケーション名を入れる"
#define _prefix APPLICATION_NAME
#define HTTP_QUERY_FLAG -2147483648
#include <MQLAuth.mqh>
#define VERSION "1.00"
#property version VERSION
//#resource "\\Include\\Images\\logo.bmp"
```

- `MQLAUTH_ID` と `APPLICATION_NAME` はユーザーから提供された値に書き換える
- **既存コードに `#property version` がある場合**: 元のバージョン番号を `#define VERSION` の値に転記し、元からある `#property version` 行は削除する（`VERSION` はアップデート通知の新旧比較にも使われる）
- `HTTP_QUERY_FLAG -2147483648` は `INTERNET_FLAG_RELOAD`（キャッシュを使わず毎回サーバーから取得）。`#include <MQLAuth.mqh>` より前に定義する必要がある
- `//#resource` 行はロゴ表示機能（オプション）用。コメントアウトのまま追加しておく
- `MQLAuth.mqh` 内部で `#property strict` が宣言されているため、includeするだけでstrictモードになる。旧形式コードでは型の警告が増える場合があるが、エラーでなければ問題ない

## Step 2: OnInit() に追記

`OnInit()`（旧形式は `init()`）の**先頭**に以下の3行を追加する。

```mql4
   if(UninitializeReason() != REASON_CHARTCHANGE)
      ObjectsDeleteAll(ChartID(), _prefix);
   EventSetMillisecondTimer(500);
```

- **既存コードに `EventSetTimer()` または `EventSetMillisecondTimer()` の記載がある場合**、3行目（`EventSetMillisecondTimer(500);`）は追加しない（既存のタイマー設定を使う）

## Step 3: OnDeinit() に追記

グローバルに `OnDeinit()` を追加する。

```mql4
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(ChartID(), _prefix);
   if(reason == 9) {
      FolderClean("MQLAuth/");
   }
   EventKillTimer();
}
```

- **既存コードに `OnDeinit()`（旧形式は `deinit()`）がある場合**は、その**先頭**に上記の中身（`ObjectsDeleteAll` 〜 `EventKillTimer();`）を追加する
- **既存コードに `EventKillTimer()` の記載がある場合**、`EventKillTimer();` の行は追加しない
- `reason == 9`（`REASON_CLOSE` = ターミナル終了）のときに認証キャッシュフォルダを削除する処理。変更しない

## Step 4: OnTick() / OnCalculate() の先頭をガード

- **EAの場合** — `OnTick()`（旧形式は `start()`）の先頭に追加:

```mql4
   if(!_isAuthorized) return;
```

- **インジケーターの場合** — `OnCalculate()` の先頭に追加:

```mql4
   if(!_isAuthorized) return 0;
```

## Step 5: OnTimer() を追加

グローバルに `OnTimer()` を追加する。認証はこのタイマー経由で発火する（`sysfac_onCalc()` が口座情報の取得を待って認証を実行する）。

```mql4
void OnTimer(){
   sysfac_onCalc();
   if(!_isAuthorized) return;

   SYSFAC_Message();
}
```

- **既存コードに `OnTimer()` がある場合**は、その**先頭**に以下の3行を追加する（`if(!_isAuthorized) return;` により、未認証時は既存のタイマー処理も動作しなくなる。既存のタイマー処理を認証と無関係に動かす必要がある場合はユーザーに確認すること）:

```mql4
   sysfac_onCalc();
   if(!_isAuthorized) return;
   SYSFAC_Message();
```

## Step 6: OnChartEvent() を追加

グローバルに `OnChartEvent()` を追加する（メッセージ・ロゴのクリック処理に使われる）。

```mql4
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
   sysfac_onchartevent(id, sparam);
   if(!_isAuthorized) return;
}
```

- **既存コードに `OnChartEvent()` がある場合**は、その**先頭**に以下の2行を追加する:

```mql4
   sysfac_onchartevent(id, sparam);
   if(!_isAuthorized) return;
```

## Step 7: ファイル末尾にボイラープレートコードを追加

本ガイド末尾の**付録: ボイラープレートコード**の全文を、ソースコードの一番下に**一字一句そのままコピーして**追加する。

- **絶対に自分で書き直したり、要約・省略・リファクタリングをしないこと。** このコードには認証・キャッシュ・メッセージ表示・エラー表示の全実装が含まれており、変更するとMQLAuthサーバーとの互換性が壊れる恐れがある
- 変更してよいのは「カスタマイズ」セクションの変数の**値**のみ（後述）

## MQL5（.mq5）の場合の追加手順

ボイラープレートは `#ifdef __MQL5__` によりMQL5をほぼサポートしているが、`TimeHour()`（MQL4専用関数）が2箇所で使われているため、MQL5ではそのままだとコンパイルエラーになる。MQL5に実装する場合は、ボイラープレートの直前に以下のヘルパーを追加する。

```mql5
#ifdef __MQL5__
int TimeHour(datetime t) { MqlDateTime tm; TimeToStruct(t, tm); return tm.hour; }
#endif
```

- MQL4ではプリプロセッサにより無効化されるため、追加しても無害
- 本ボイラープレートの主な実績はMQL4環境のため、MQL5に実装した場合は必ず実機での動作確認をユーザーに依頼すること

## カスタマイズ変数の設定

ボイラープレート冒頭の「カスタマイズ」セクションの変数で機能をオン/オフできる。ユーザーから指定があった場合のみ値を変更する（デフォルトのままでも標準的な構成で動作する）。

| 変数 | デフォルト | 意味 |
|---|---|---|
| `PURCHASEURL` | `""` | PayPal決済ページURL（PayPal連携時のみ設定） |
| `_useApplicationMessage` | `true` | 一斉メッセージ表示を利用する |
| `_applicationMessageViewSecond` | `8` | 一斉メッセージを消すまでの秒数 |
| `_useUserMessage` | `true` | 個別メッセージ表示を利用する |
| `_userMessageViewSecond` | `8` | 個別メッセージを消すまでの秒数 |
| `_useUpdateMessage` | `true` | アップデート通知を利用する |
| `_useTrial` | `false` | 体験版機能（未登録口座の自動登録）を使用する |
| `_day` | `0` | 体験版の日数 |
| `_usePayPal` | `false` | PayPal連携を使用する |
| `_useLogo` | `false` | チャートにロゴを表示する（Step 1の `#resource` の有効化も必要） |
| `_logourl` | `""` | ロゴクリックで開くURL |
| `_useUpdateDownloadLink` | `false` | 新バージョンのダウンロードリンクを表示する |

## 実装ルール

1. **既存ロジックを変更しない。** 認証コードの追加のみを行い、既存の売買ロジック・計算ロジック・パラメータには手を付けない
2. **ボイラープレートは一字一句そのままコピーする。** 生成・再構成しない
3. **MQLAUTH_ID・アプリケーション名はユーザー提供の値のみ使用。** プレースホルダのまま残す場合は、その旨をユーザーに明確に伝える
4. 既存コードとの名前衝突（`_isAuthorized` 等がすでに定義されている等）を発見した場合は、機械的にリネームせず、ユーザーに報告して指示を仰ぐ
5. **認証頻度を勝手に上げない。** MQLAuthサーバーには同一端末30回/60秒のアクセス制限がある。ボイラープレートは初回認証後ローカルキャッシュを使う設計になっており、これを変更しない

## 実装後の自己チェックリスト

実装を終えたら、以下を確認して結果をユーザーに報告すること。

- [ ] Step 1のdefine群＋`#include <MQLAuth.mqh>` がファイル先頭にある（`HTTP_QUERY_FLAG` がincludeより前）
- [ ] 既存の `#property version` があった場合、`#define VERSION` に統合し、元の行を削除した
- [ ] `OnInit` 先頭に3行（既存タイマーがある場合は2行）追加した
- [ ] `OnDeinit` に追記した（既存 `EventKillTimer` との重複なし）
- [ ] `OnTick`（EA）または `OnCalculate`（インジケーター）の先頭に `_isAuthorized` ガードがある
- [ ] `OnTimer` / `OnChartEvent` を追加（既存がある場合は先頭に追記）した
- [ ] ファイル末尾にボイラープレート全文を**改変なしで**追加した
- [ ] MQL5の場合、`TimeHour` ヘルパーを追加した
- [ ] 既存ロジックに認証以外の変更を加えていない

## ユーザーに伝える検証手順

コードの実装が終わったら、ユーザーに以下の検証を依頼すること。

1. MetaEditorでコンパイルし、0 errors であることを確認
2. MT4/MT5のオプションで「DLLの使用を許可する」（またはEA適用時のダイアログでDLL許可）をONにしてチャートに適用
3. MQLAuthに**未登録**の口座番号で、チャート上にエラーメッセージが表示され、EA・インジケーターの機能が動作しないことを確認
4. 管理画面で口座番号を登録後、MT4/MT5を再起動（またはEAを再適用）し、エキスパートログに「利用期限： ○年○月○日 まで」が出て正常動作することを確認
5. 管理画面からテストメッセージを配信し、チャート上に表示されることを確認（メッセージ機能を使う場合）

## トラブルシューティング

- **コンパイルエラー: can't open "MQLAuth.mqh"** → `MQL4/Include/`（MT5は `MQL5/Include/`）に MQLAuth.mqh が配置されているか確認
- **コンパイルエラー: 'TimeHour' - function not defined（MQL5）** → 「MQL5の場合の追加手順」のヘルパーを追加
- **認証が常に失敗する** → (1) MQLAuth IDの綴り、(2) アプリケーション名が管理画面の登録名と完全一致か、(3) 口座番号が管理画面に登録済みか・期限内か、を確認
- **「認証アクセス過多です」のアラート** → サーバーのアクセス制限（30回/60秒）超過。時間を置いてから再試行
- **Error:000「DLLの使用が許可されていません」がチャートに表示される** → MT4/MT5の設定で「DLLの使用を許可する」をON
- **口座番号を登録・期限更新したのに反映されない** → 認証結果は当日分がローカルキャッシュされる。MT4/MT5を再起動するか、EA・インジケーターをチャートに再適用する

---

## 付録: ボイラープレートコード

以下をソースコードの一番下に一字一句そのままコピーして追加する（Step 7）。

```mql4
//+------------------------------------------------------------------+
//|  カスタマイズ                                                        |
//+------------------------------------------------------------------+
#define PURCHASEURL "" //
bool _useApplicationMessage = true; // 一斉メッセージを利用する
int _applicationMessageViewSecond = 8; // 一斉メッセージを消すまでの秒数
bool _useUserMessage = true; // 個別メッセージを利用する
int _userMessageViewSecond = 8; // 個別メッセージを消すまでの秒数
bool _useUpdateMessage = true; // アップデートのお知らせを利用する
bool _useTrial = false;//体験版機能を使用する
int _day = 0;//体験版の日数
bool _usePayPal = false;//PayPal連携を使用する
bool _useLogo = false; // ロゴを表示する
string _logourl = ""; //ロゴクリックで開くページ
bool _useUpdateDownloadLink = false; //新しいバージョンのダウンロードリンクを表示する

//+------------------------------------------------------------------+
//|  グローバル変数                                                     |
//+------------------------------------------------------------------+
//--- 口座認証に利用する変数
bool _isAuthorized = false; // 口座認証の成否を表す変数
bool _isAuthed = false;// 口座認証済みかを確認する変数
datetime _date; // 口座認証を行った時間を保存する変数
int _messageXDistance;
int _messageYDistance;
//--- 口座認証に利用する変数

//--- 一斉メッセージに利用する変数
datetime _receiveApplicationMessage; // 前回メッセージを受信した日時
string _applicationMessageurl; // メッセージをクリックしたときに開くURLを格納する変数
long _viewApplicationMessageTime = 0; // メッセージを表示した日時を格納する変数
string _applicationMessage; //メッセージ内容
//--- 一斉メッセージに利用する変数

//--- 個別メッセージに利用する変数
datetime _receiveUserMessage; // 前回メッセージを受信した日時
string _userMessageurl; // メッセージをクリックしたときに開くURLを格納する変数
long _viewUserMessageTime = 0; // メッセージを表示した日時を格納する変数
string _userMessage; //メッセージ内容
//--- 個別メッセージに利用する変数

//--- アップデートのお知らせに利用する変数
string _updateurl; // アップデートのお知らせをクリックしたときに開くURLを格納する変数
string _newestVersion;
//--- アップデートのお知らせに利用する変数

string _downloadurl = "";
bool _sysfac_isChecked = false;
datetime sysfac_time;
datetime _sysfac_indicatorPeriod;//利用期限
string _randId;// 認証ファイルの名称
long _AuthTime;//認証した時間

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sysfac_onchartevent(int id, string sparam) {
   string _labelUpdateMessage = _prefix + "updateMessage"; // アップデートのお知らせを表示するラベル名
   string _labelUpdateMessage2 = _prefix + "updateMessage2"; // アップデートのお知らせを表示するラベル名
   string _labelApplicationMessage = _prefix + "applicationMessage"; // メッセージを表示するラベル名
   string _labelUserMessage = _prefix + "userMessage"; // メッセージを表示するラベル名
   string _objectLogo = _prefix + "SYSFAC_LOGO"; // ロゴを表示するラベル名

   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(StringFind(sparam, _labelApplicationMessage) >= 0)
         if(_applicationMessageurl != "") {
            bool result = Auth_OpenURL(_applicationMessageurl);
         }
      if(StringFind(sparam, _labelUserMessage) >= 0)
         if(_userMessageurl != "") {
            bool result = Auth_OpenURL(_userMessageurl);
         }
      if(StringFind(sparam, _labelUpdateMessage) >= 0)
         if(_updateurl != "") {
            bool result = Auth_OpenURL(_updateurl);
         }
      if(StringFind(sparam,  _objectLogo) >= 0)
         if(_logourl != "") {
            bool result = Auth_OpenURL(_logourl);
         }
      if(_usePayPal) {
         if(StringFind(sparam,  _prefix + "objectAuthMessage") >= 0)
            if(PURCHASEURL != "") {
               bool result = Auth_OpenURL(PURCHASEURL + "&custom=" + (string)AccountInfoInteger(ACCOUNT_LOGIN));
               if(!result)
                  Print("PayPal決済ページを開くのに失敗しました。");
               else
                  MessageBox("PayPal決済が済みましたら、期限を更新するため、一度MT4を再起動してください。", "ご注意");
            }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sysfac_onCalc() {
   if(_useLogo)
      _messageXDistance = 80;
   else
      _messageXDistance = 20;

   _messageYDistance = 20;

   if(_useLogo) {
      string _objectLogo = _prefix + "SYSFAC_LOGO"; // ロゴオブジェクトの名前
      Auth_SYSFACShowBMPIMG("\\Include\\Images\\logo.bmp", _objectLogo, CORNER_LEFT_LOWER);
   }

   if(AccountInfoInteger(ACCOUNT_LOGIN) != 0 && !_isAuthed) {
      _isAuthed = true;
      SYSFAC_Auth();
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckDLLsAllowed() {
   if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
      int errorcode = 000;//DLL許可なし
      string errormessages = "DLLの使用が許可されていません。,「DLLの使用を許可する」にチェックを入れてください。";
      ShowErrorMessage(errorcode, errormessages);
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ShowErrorMessage(int errorcode, string errormessages) {
   string _ObjectAuthMessage1 = _prefix + "objectAuthMessage1"; // 認証メッセージを表示するラベル名1
   string _ObjectAuthMessage2 = _prefix + "objectAuthMessage2"; // 認証メッセージを表示するラベル名2
   string _ObjectAuthMessage3 = _prefix + "objectAuthMessage3"; // 認証メッセージを表示するラベル名3

   string errormessage[];
   StringSplit(errormessages, ',', errormessage);

   ObjectCreate(ChartID(), _ObjectAuthMessage1, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_BACK, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTED, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_XDISTANCE, _messageXDistance);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_YDISTANCE, _messageYDistance + 40);
   ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_TEXT, "[" + APPLICATION_NAME + "] Error:" + (string)errorcode);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_FONTSIZE, 12);
   ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_FONT, "Meiryo");
   ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));

   ObjectCreate(ChartID(), _ObjectAuthMessage2, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_BACK, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTED, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_XDISTANCE, _messageXDistance);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_YDISTANCE, _messageYDistance + 20);
   ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_TEXT, errormessage[0]);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_FONTSIZE, 12);
   ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_FONT, "Meiryo");
   ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));

   ObjectCreate(ChartID(), _ObjectAuthMessage3, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_BACK, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_SELECTED, false);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_XDISTANCE, _messageXDistance);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_YDISTANCE, _messageYDistance);
   ObjectSetString(ChartID(), _ObjectAuthMessage3, OBJPROP_TEXT, errormessage[1]);
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_FONTSIZE, 12);
   ObjectSetString(ChartID(), _ObjectAuthMessage3, OBJPROP_FONT, "Meiryo");
   ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
}
//+------------------------------------------------------------------+
//|  口座認証のための関数                                               |
//+------------------------------------------------------------------+
bool SYSFAC_Auth() {
   string _ObjectAuthMessage1 = _prefix + "objectAuthMessage1"; // 認証メッセージを表示するラベル名1
   string _ObjectAuthMessage2 = _prefix + "objectAuthMessage2"; // 認証メッセージを表示するラベル名2
   string _ObjectAuthMessage3 = _prefix + "objectAuthMessage3"; // 認証メッセージを表示するラベル名3

   if(!CheckDLLsAllowed()) return false;

   string text   = APPLICATION_NAME + TimeToString(TimeCurrent(), TIME_DATE) + (string)AccountInfoInteger(ACCOUNT_LOGIN);
   string keystr = MQLAUTH_ID;
   uchar array_src[];
   uchar array_dst[];
   uchar array_key[];
   int   res;

   StringToCharArray(keystr, array_key);
   StringToCharArray(text, array_src);

   res = CryptEncode(CRYPT_HASH_SHA256, array_src, array_key, array_dst);

   _randId = ArrayToHex(array_dst);

   if(res > 0) {

   } else {
      Alert("認証エラー。 エラーコード =", GetLastError(), "\r\nこのエラーが連続で出るときは、配布元に連絡してください。");
      return false;
   }

   int errorcode = 0;
   string errormessages = "";

   if(!FileIsExist("MQLAuth\\" + ArrayToHex(array_dst))) {
      bool result = false;
      if(_useTrial) {
         result = AuthByAccountNumberWithAddUser(MQLAUTH_ID, APPLICATION_NAME, _day, _sysfac_indicatorPeriod, _userMessage, errorcode, errormessages);
      } else {
         result = AuthByAccountNumber(MQLAUTH_ID, APPLICATION_NAME, _sysfac_indicatorPeriod, _userMessage, errorcode, errormessages);
      }
      if(result) {
         if(_sysfac_indicatorPeriod >= TimeLocal()) {
            _AuthTime = GetTickCount();
            //--- バージョン情報を確認し、更新がある場合はお知らせを表示する
            if(_useUpdateMessage) {
               _newestVersion = Auth_GetNewestVersion(MQLAUTH_ID, APPLICATION_NAME, _updateurl);
            }
            //--- バージョン情報を確認し、更新がある場合はお知らせを表示する
            if(_useApplicationMessage) {
               _applicationMessage = Auth_GetApplicationMessage(MQLAUTH_ID, APPLICATION_NAME);
               StringReplace(_applicationMessage, "\n", "");
            }
            if(_useUserMessage) {
               StringReplace(_userMessage, "\n", "");
            }
            CreateFile("MQLAuth\\" + ArrayToHex(array_dst), TimeToString(_sysfac_indicatorPeriod, TIME_DATE | TIME_SECONDS), _newestVersion, _updateurl, _applicationMessage, _userMessage);
#ifdef __MQL5__
            MqlDateTime tm;
            TimeToStruct(_sysfac_indicatorPeriod, tm);
            int timeYear = tm.year;
            int timeMonth = tm.mon;
            int timeDay = tm.day;
#else
            int timeYear = TimeYear(_sysfac_indicatorPeriod);
            int timeMonth = TimeMonth(_sysfac_indicatorPeriod);
            int timeDay = TimeDay(_sysfac_indicatorPeriod);
#endif
            Print(APPLICATION_NAME + "利用期限： ", timeYear, "年 ", timeMonth, "月 ", timeDay, "日 まで");
         } else {
            _isAuthorized = false;
            ObjectsDeleteAll(ChartID(), _prefix);
            //--- 認証メッセージを表示するラベルの作成 ---
            ObjectCreate(ChartID(), _ObjectAuthMessage2, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_BACK, false);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTED, false);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_HIDDEN, true);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_XDISTANCE, _messageXDistance);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_YDISTANCE, _messageYDistance + 40);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_TEXT, "[" + _prefix + "]利用期間が終了しました。");
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_ZORDER, 180);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_FONTSIZE, 12);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_FONT, "Meiryo");
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));

            if(_usePayPal) {
               ObjectCreate(ChartID(), _ObjectAuthMessage3, OBJ_LABEL, 0, 0, 0);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_BACK, false);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_SELECTED, false);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_HIDDEN, true);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_CORNER, CORNER_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_XDISTANCE, _messageXDistance);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_YDISTANCE, _messageYDistance + 20);
               ObjectSetString(ChartID(), _ObjectAuthMessage3, OBJPROP_TEXT, "引き続きご利用になる場合はこちらをクリックしてください。");
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_ZORDER, 180);
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_FONTSIZE, 12);
               ObjectSetString(ChartID(), _ObjectAuthMessage3, OBJPROP_FONT, "Meiryo");
               ObjectSetInteger(ChartID(), _ObjectAuthMessage3, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
            }
            //--- 認証メッセージを表示するラベルの作成 ---

            return false;
         }
      } else {
         _isAuthorized = false;
         ShowErrorMessage(errorcode, errormessages);
         return false;
      }
   } else {
      _AuthTime = GetTickCount();
      int filehandle = FileOpen("MQLAuth\\" + ArrayToHex(array_dst), FILE_SHARE_READ | FILE_CSV, ',');
      _sysfac_indicatorPeriod = StringToTime(FileReadString(filehandle));
      _newestVersion = FileReadString(filehandle);
      _updateurl = FileReadString(filehandle);
      _applicationMessage = FileReadString(filehandle);
      _userMessage = FileReadString(filehandle);
      FileClose(filehandle);
#ifdef __MQL5__
      MqlDateTime tm;
      TimeToStruct(_sysfac_indicatorPeriod, tm);
      int timeYear = tm.year;
      int timeMonth = tm.mon;
      int timeDay = tm.day;
#else
      int timeYear = TimeYear(_sysfac_indicatorPeriod);
      int timeMonth = TimeMonth(_sysfac_indicatorPeriod);
      int timeDay = TimeDay(_sysfac_indicatorPeriod);
#endif
      Print(APPLICATION_NAME + "利用期限： ", timeYear, "年 ", timeMonth, "月 ", timeDay, "日 まで");
   }
   _isAuthorized = true;
   EventSetTimer(1);

   return true;
}
//+------------------------------------------------------------------+
//|   メッセージを取得し表示する関数                                       |
//+------------------------------------------------------------------+
void SYSFAC_Message() {
   string _labelUpdateMessage = _prefix + "updateMessage"; // アップデートのお知らせを表示するラベル名
   string _labelUpdateMessage2 = _prefix + "updateMessage2"; // アップデートのお知らせを表示するラベル名
   string _labelApplicationMessage = _prefix + "applicationMessage"; // メッセージを表示するラベル名
   string _labelUserMessage = _prefix + "userMessage"; // メッセージを表示するラベル名
   string _ObjectAuthMessage1 = _prefix + "objectAuthMessage1"; // 認証メッセージを表示するラベル名1
   string _ObjectAuthMessage2 = _prefix + "objectAuthMessage2"; // 認証メッセージを表示するラベル名2
   string _ObjectPeriodMessage = _prefix + "objectPeriodMessage"; // 期限を表示するラベル名

   if(_isAuthorized
         && _useApplicationMessage
         && TimeHour(TimeLocal()) != TimeHour(_receiveApplicationMessage)) {
      _receiveApplicationMessage = TimeLocal();

      string messages = _applicationMessage;
      if(messages != "") {
         if(StringFind(messages, "#", 0) >= 0) {
            string result[];
            StringSplit(messages, '#', result);
            string message[];
            StringSplit(result[0], '\r', message);

            for(int i = 0; i < ArraySize(message); i++) {
               ObjectCreate(ChartID(), _labelApplicationMessage + (string)i, OBJ_LABEL, 0, 0, 0);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_BACK, false);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_SELECTED, false);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_HIDDEN, true);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_CORNER, CORNER_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_XDISTANCE, _messageXDistance);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_YDISTANCE, _messageYDistance + 20 * (ArraySize(message) - 1 - i));
               ObjectSetString(ChartID(),  _labelApplicationMessage + (string)i, OBJPROP_TEXT, message[i]);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_FONTSIZE, 12);
               ObjectSetString(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_FONT, "Meiryo");
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
            }
            _applicationMessageurl = result[1];
         } else {
            string message[];
            StringSplit(messages, '\r', message);

            for(int i = 0; i < ArraySize(message); i++) {
               ObjectCreate(ChartID(), _labelApplicationMessage + (string)i, OBJ_LABEL, 0, 0, 0);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_BACK, false);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_SELECTED, false);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_HIDDEN, true);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_CORNER, CORNER_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_XDISTANCE, _messageXDistance);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_YDISTANCE, _messageYDistance + 20 * (ArraySize(message) - 1 - i));
               ObjectSetString(ChartID(),  _labelApplicationMessage + (string)i, OBJPROP_TEXT, message[i]);
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_FONTSIZE, 12);
               ObjectSetString(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_FONT, "Meiryo");
               ObjectSetInteger(ChartID(), _labelApplicationMessage + (string)i, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
            }
            _applicationMessageurl = "";
         }
         _viewApplicationMessageTime = GetTickCount();
      } else {
         _viewApplicationMessageTime = 1;
      }
   }
   if(_isAuthorized
         && _useUserMessage
         && GetTickCount() - _viewApplicationMessageTime > _applicationMessageViewSecond * 1000
         && TimeHour(TimeLocal()) !=  TimeHour(_receiveUserMessage)) {
      _receiveUserMessage = TimeLocal();
      ObjectsDeleteAll(ChartID(), _labelApplicationMessage);

      string messages = _userMessage;

      if(messages != "") {
         if(StringFind(messages, "#", 0) >= 0) {
            string result[];
            StringSplit(messages, '#', result);
            string message[];
            StringTrimRight(result[0]);
            StringSplit(result[0], '\r', message);

            for(int i = 0; i < ArraySize(message); i++) {
               ObjectCreate(ChartID(), _labelUserMessage + (string)i, OBJ_LABEL, 0, 0, 0);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_BACK, false);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_SELECTED, false);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_HIDDEN, true);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_CORNER, CORNER_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_XDISTANCE, _messageXDistance);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_YDISTANCE, _messageYDistance + 20 * (ArraySize(message) - 1 - i));
               ObjectSetString(ChartID(), _labelUserMessage + (string)i, OBJPROP_TEXT, message[i]);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_FONTSIZE, 12);
               ObjectSetString(ChartID(), _labelUserMessage + (string)i, OBJPROP_FONT, "Meiryo");
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
            }
            _userMessageurl = result[1];
         } else {
            string message[];
            StringSplit(messages, '\r', message);

            for(int i = 0; i < ArraySize(message); i++) {
               ObjectCreate(ChartID(), _labelUserMessage + (string)i, OBJ_LABEL, 0, 0, 0);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_BACK, false);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_SELECTED, false);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_HIDDEN, true);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_CORNER, CORNER_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_XDISTANCE, _messageXDistance);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_YDISTANCE, _messageYDistance + 20 * (ArraySize(message) - 1 - i));
               ObjectSetString(ChartID(), _labelUserMessage + (string)i, OBJPROP_TEXT, message[i]);
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_FONTSIZE, 12);
               ObjectSetString(ChartID(), _labelUserMessage + (string)i, OBJPROP_FONT, "Meiryo");
               ObjectSetInteger(ChartID(), _labelUserMessage + (string)i, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
            }
            _userMessageurl = "";
         }
         _viewUserMessageTime = GetTickCount();
      } else {
         _viewUserMessageTime = 1;
      }
   }
   if(_useUserMessage && _viewUserMessageTime != 0 && GetTickCount() - _viewUserMessageTime > _userMessageViewSecond * 1000) {
      ObjectsDeleteAll(ChartID(), _labelUserMessage);
      if(_newestVersion != "" && StringToDouble(VERSION) < StringToDouble(_newestVersion)) {
         ObjectCreate(ChartID(), _labelUpdateMessage, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_SELECTED, false);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_HIDDEN, true);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_XDISTANCE, _messageXDistance);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_YDISTANCE, _messageYDistance + 40);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_ZORDER, 8);
         ObjectSetString(ChartID(), _labelUpdateMessage, OBJPROP_TEXT, "[" + APPLICATION_NAME + "]新しいバージョン " + _newestVersion + " があります。");
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_FONTSIZE, 12);
         ObjectSetString(ChartID(), _labelUpdateMessage, OBJPROP_FONT, "Meiryo");
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         if(_useUpdateDownloadLink){
            ObjectCreate(ChartID(), _labelUpdateMessage2, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_SELECTED, false);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_HIDDEN, true);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_XDISTANCE, _messageXDistance);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_YDISTANCE, _messageYDistance + 20);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_ZORDER, 8);
            ObjectSetString(ChartID(), _labelUpdateMessage2, OBJPROP_TEXT, "ダウンロードするにはここをクリック");
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_FONTSIZE, 12);
            ObjectSetString(ChartID(), _labelUpdateMessage2, OBJPROP_FONT, "Meiryo");
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         }
      } else if(_sysfac_indicatorPeriod - _day * 86400 <= TimeLocal()) {
         ObjectCreate(ChartID(), _ObjectAuthMessage1, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTED, false);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_HIDDEN, true);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_XDISTANCE, _messageXDistance);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_YDISTANCE, _messageYDistance + 40);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_ZORDER, 8);
         string date = TimeToString(_sysfac_indicatorPeriod, TIME_DATE | TIME_SECONDS);
         StringReplace(date, ".", "/");
         ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_TEXT, "[" + APPLICATION_NAME + "体験版] 利用期限： " + date);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_FONTSIZE, 12);
         ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_FONT, "Meiryo");
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         if(PURCHASEURL != ""){
            ObjectCreate(ChartID(), _ObjectAuthMessage2, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTED, false);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_HIDDEN, true);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_XDISTANCE, _messageXDistance);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_YDISTANCE, _messageYDistance + 20);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_ZORDER, 8);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_TEXT, "ご購入はここをクリック");
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_FONTSIZE, 12);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_FONT, "Meiryo");
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         }
      } else {
      }
   } else if(!_useUserMessage && _viewApplicationMessageTime != 0 && GetTickCount() - _viewApplicationMessageTime > _applicationMessageViewSecond * 1000) {
      ObjectsDeleteAll(ChartID(), _labelApplicationMessage);
      if(_newestVersion != "" && StringToDouble(VERSION) < StringToDouble(_newestVersion)) {
         ObjectCreate(ChartID(), _labelUpdateMessage, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_SELECTED, false);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_HIDDEN, true);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_XDISTANCE, _messageXDistance);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_YDISTANCE, _messageYDistance + 40);
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_ZORDER, 8);
         ObjectSetString(ChartID(), _labelUpdateMessage, OBJPROP_TEXT, "[" + APPLICATION_NAME + "]新しいバージョン " + _newestVersion + " があります。");
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_FONTSIZE, 12);
         ObjectSetString(ChartID(), _labelUpdateMessage, OBJPROP_FONT, "Meiryo");
         ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         if(_useUpdateDownloadLink){
            ObjectCreate(ChartID(), _labelUpdateMessage2, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_SELECTED, false);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_HIDDEN, true);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_XDISTANCE, _messageXDistance);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_YDISTANCE, _messageYDistance + 20);
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_ZORDER, 8);
            ObjectSetString(ChartID(), _labelUpdateMessage2, OBJPROP_TEXT, "ダウンロードするにはここをクリック");
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_FONTSIZE, 12);
            ObjectSetString(ChartID(), _labelUpdateMessage2, OBJPROP_FONT, "Meiryo");
            ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         }
      } else if(_sysfac_indicatorPeriod - _day * 86400 <= TimeLocal()) {
         ObjectCreate(ChartID(), _ObjectAuthMessage1, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTED, false);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_HIDDEN, true);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_XDISTANCE, _messageXDistance);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_YDISTANCE, _messageYDistance + 40);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_ZORDER, 8);
         string date = TimeToString(_sysfac_indicatorPeriod, TIME_DATE | TIME_SECONDS);
         StringReplace(date, ".", "/");
         ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_TEXT, "[" + APPLICATION_NAME + "体験版] 利用期限： " + date);
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_FONTSIZE, 12);
         ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_FONT, "Meiryo");
         ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         if(PURCHASEURL != ""){
            ObjectCreate(ChartID(), _ObjectAuthMessage2, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_SELECTED, false);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_HIDDEN, true);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_XDISTANCE, _messageXDistance);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_YDISTANCE, _messageYDistance + 20);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_ZORDER, 8);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_TEXT, "ご購入はここをクリック");
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_FONTSIZE, 12);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_FONT, "Meiryo");
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
         }
      } else {
      }
   }
   if(_sysfac_indicatorPeriod <= TimeLocal()) {
      if(FileIsExist("MQLAuth\\" + _randId)) {
         FileDelete("MQLAuth\\" + _randId);
         _AuthTime = 4294967295;
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AuthByAccountNumber(string ManagerName, string ApplicationName, datetime &period, string &message, int &errorcode, string &errormessage) {
   Print("Auth for All MQL - MQLAuth https://mql-auth.com/");

   string url = _url + "an?name=" + ManagerName + "&appname=" + ApplicationName + "&accountno=" + (string)AccountInfoInteger(ACCOUNT_LOGIN);
   string result = AccessToInternetGetMethod(url, NULL);
   if(result == "") {
      errorcode = 200;//パスワード未入力
      errormessage = "サーバとの接続に失敗しました。,ネットワークの接続を確認してください。";
      period = 0;
      return false;
   }

   CJAVal json;
   json.Deserialize(result);
   if(json["status"].ToStr() == "429") {
      errorcode = 300;//パスワード未入力
      errormessage = "認証アクセス過多です。,時間を置いてから、再度インジケーターを挿入してください。";
      period = 0;
      return false;
   }
   if(json["title"].ToStr() == "Not Found") {
      errorcode = 400;//口座番号登録なし
      errormessage = "口座番号が登録されていません。, ";
      period = 0;
      return false;
   }

   string userPeriod = json["userPeriod"].ToStr();
   period = JsonToDatetime(userPeriod);

   datetime messageViewStart = JsonToDatetime(json["messageViewStart"].ToStr());
   datetime messageViewPeriod = JsonToDatetime(json["messageViewPeriod"].ToStr());
   if(messageViewStart < TimeLocal() && TimeLocal() < messageViewPeriod)
      message = json["message"].ToStr();
   else
      message = "";

   return true;
}
bool AuthByAccountNumberWithAddUser(string ManagerName, string ApplicationName, int day, datetime &period, string &message, int &errorcode, string &errormessage) {
   Print("Auth for All MQL - MQLAuth https://mql-auth.com/");

   string url = _url + "tr?name=" + ManagerName + "&appname=" + ApplicationName + "&accountno=" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "&period=" + (string)day;
   string result = AccessToInternetGetMethod(url, NULL);
   if(result == "") {
      errorcode = 200;//パスワード未入力
      errormessage = "サーバとの接続に失敗しました。,ネットワークの接続を確認してください。";
      period = 0;
      return false;
   }

   CJAVal json;
   json.Deserialize(result);
   if(json["status"].ToStr() == "429") {
      errorcode = 300;//パスワード未入力
      errormessage = "認証アクセス過多です。,時間を置いてから、再度インジケーターを挿入してください。";
      period = 0;
      return false;
   }
   if(json["title"].ToStr() == "Not Found") {
      errorcode = 400;//口座番号登録なし
      errormessage = "口座番号が登録されていません。,この口座では利用できません。";
      period = 0;
      return false;
   }

   string userPeriod = json["userPeriod"].ToStr();
   period = JsonToDatetime(userPeriod);

   datetime messageViewStart = JsonToDatetime(json["messageViewStart"].ToStr());
   datetime messageViewPeriod = JsonToDatetime(json["messageViewPeriod"].ToStr());
   if(messageViewStart < TimeLocal() && TimeLocal() < messageViewPeriod)
      message = json["message"].ToStr();
   else
      message = "";

   return true;
}

//+------------------------------------------------------------------+
void CreateFile(string m_filename, string period, string m_text1, string m_text2, string m_text3, string m_text4) {
   int handle;
   handle = FileOpen(m_filename, FILE_READ | FILE_WRITE, ",");
   if(handle > 0) {
      FileWrite(handle, period, m_text1 + "," + m_text2 + "," + m_text3 + "," + m_text4);
      FileClose(handle);
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ArrayToHex(uchar &arr[], int count = -1) {
   string res = "";
   if(count < 0 || count > ArraySize(arr)) {
      count = ArraySize(arr);
   }

   for(int i = 0; i < count; i++) {
      res += StringFormat("%.2X", arr[i]);
   }

   return(res);
}
//+------------------------------------------------------------------+
void Auth_SYSFACShowBMPIMG(string imgpath, string imgname, ENUM_BASE_CORNER m_corner = 0, int xdistance = 20, int ydistance = 20, int zorder = 99) {
   ObjectCreate(ChartID(), imgname, OBJ_BITMAP_LABEL, 0, 0, 0);
   ObjectSetString(ChartID(), imgname, OBJPROP_BMPFILE, "::" + StringSubstr(imgpath, 1));
   ObjectSetInteger(ChartID(), imgname, OBJPROP_BACK, false);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_SELECTED, false);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_CORNER, m_corner);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_ZORDER, zorder);
   switch(m_corner) {
   case CORNER_LEFT_UPPER:
      ObjectSetInteger(ChartID(), imgname, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      break;
   case CORNER_LEFT_LOWER:
      ObjectSetInteger(ChartID(), imgname, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      break;
   case CORNER_RIGHT_UPPER:
      ObjectSetInteger(ChartID(), imgname, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      break;
   case CORNER_RIGHT_LOWER:
      ObjectSetInteger(ChartID(), imgname, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      break;
   }
   ObjectSetInteger(ChartID(), imgname, OBJPROP_XDISTANCE, xdistance);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_YDISTANCE, ydistance);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_XOFFSET, 0);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_YOFFSET, 0);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_XSIZE, 0);
   ObjectSetInteger(ChartID(), imgname, OBJPROP_YSIZE, 0);
}
//+------------------------------------------------------------------+
```
