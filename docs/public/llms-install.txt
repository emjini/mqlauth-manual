# MQLAuth 実装ガイド（AIコーディングアシスタント向け）

このドキュメントは、AIコーディングアシスタント（Claude Code、Cursor、ChatGPT、GitHub Copilot等）が、ユーザーのMQL4/MQL5ソースコードにMQLAuth認証を実装するための手順書です。人間向けマニュアルは https://mqlauth-manual.pages.dev/ にあります。

対応バージョン: MQLAuth.mqh v1.09以降 ＋ MQLAuthBoilerplate.mqh v1.01以降（2026年7月時点の配布版）

## MQLAuthとは

- MT4/MT5のEA・インジケーター向け認証サービス（https://mql-auth.com）
- EA・インジケーターの利用者をMT口座番号で認証し、利用者ごとに利用期限を設定できる
- 販売者はMQLAuthのWeb管理画面で利用者の口座番号・期限を登録する
- 認証はHTTPS経由（wininet.dll使用）でMQLAuthサーバーに問い合わせる

## この実装で追加される機能

本ガイドの標準実装（`MQLAuthBoilerplate.mqh`）により、対象のEA・インジケーターに以下が追加される。

1. **口座番号認証** — 登録済み口座番号かつ期限内のときだけ動作。認証結果は当日分がローカルにキャッシュされ、同日中のチャート再適用や時間足変更ではサーバーアクセスなしで認証される（ターミナル終了時にキャッシュは削除される）
2. **利用期限表示** — 認証成功時にエキスパートログへ期限を出力。期限切れ時はチャート上にメッセージを表示
3. **一斉メッセージ / 個別メッセージ** — 管理画面から配信したメッセージをチャート上に表示（クリックでURLオープン）
4. **アップデート通知** — 新バージョン公開時にチャート上へお知らせを表示
5. **体験版機能（オプション）** — 未登録口座を初回起動時に自動登録し、指定日数だけ利用可能にする
6. **ロゴ表示（オプション）** — チャートへのロゴ表示

## 実装前にユーザーに確認する情報

以下が提示されていない場合、**推測で埋めずに必ずユーザーに確認すること**。

1. **MQLAuth ID** — 管理画面で確認できるGUID形式のID（例: `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`）
2. **アプリケーション名** — MQLAuthの管理画面に登録したEA・インジケーターの名称（登録名と完全一致が必要）
3. （任意）体験版機能を使うか、使う場合の日数。指定がなければ体験版オフで実装する

## 前提条件（ユーザー環境）

- 以下の2ファイルが `MQL4/Include/`（MT5は `MQL5/Include/`）に配置されていること
  - `MQLAuth.mqh` — https://mql-auth.com の上部メニュー「ダウンロード」から入手
  - `MQLAuthBoilerplate.mqh` — https://mqlauth-manual.pages.dev/MQLAuthBoilerplate.mqh から入手
- MT4/MT5で「DLLの使用を許可する」が必要（wininet.dll・shell32.dllを使用するため）。コードでの対応は不要だが、検証手順に含めること

## Step 0: 対象ソースコードの判別

実装前に、渡されたソースコードについて以下を判別する。

**EAかインジケーターか**
- `OnTick()` がある、`OrderSend` 等の注文関数を使う → EA
- `OnCalculate()` や `#property indicator_buffers` がある → インジケーター

**MQL4かMQL5か**
- 拡張子 `.mq4` → MQL4、`.mq5` → MQL5
- どちらも本ガイドの同じ手順で実装できる（`MQLAuthBoilerplate.mqh` がMQL4/MQL5両対応）

**旧形式MQL4（Build 600以前の書き方）か**
- `#property strict` がなく、`init()` / `start()` / `deinit()` を使用 → 旧形式
- 旧形式でも実装可能（現行コンパイラは新旧混在を許容する）。`OnInit→init`、`OnDeinit→deinit`、`OnTick→start` と読み替える。`OnTimer` / `OnChartEvent` は旧形式には存在しないため、本ガイドの内容で新規追加する

**MQLAuth実装済みでないか**
- ソースコード内に `SYSFAC_Auth` / `AuthByAccountNumber` / `#include <MQLAuthBoilerplate.mqh>` のいずれかが既に存在する → MQLAuth実装済み。**二重実装せず**、実装済みであることをユーザーに報告して意図を確認する
- 旧方式（ボイラープレート全文をソースコードへ貼り付ける方式）で実装済みのコードもそのまま有効。新方式への移行作業は不要

## Step 1: ファイル先頭にdefine・カスタマイズ変数・includeを追加

ソースコードの最上部に以下のブロック全体を追加する。

```mql4
#define MQLAUTH_ID "ここにユーザーのMQLAuth IDを入れる"
#define APPLICATION_NAME "ここに登録済みアプリケーション名を入れる"
#define _prefix APPLICATION_NAME
#define HTTP_QUERY_FLAG -2147483648
#include <MQLAuth.mqh>
#define VERSION "1.00"
#property version VERSION
//#resource "\\Include\\Images\\logo.bmp"

//--- MQLAuth カスタマイズ
bool _useApplicationMessage = true; // 一斉メッセージを利用する
int _applicationMessageViewSecond = 8; // 一斉メッセージを消すまでの秒数
bool _useUserMessage = true; // 個別メッセージを利用する
int _userMessageViewSecond = 8; // 個別メッセージを消すまでの秒数
bool _useUpdateMessage = true; // アップデートのお知らせを利用する
bool _useTrial = false;//体験版機能を使用する
int _day = 0;//体験版の日数
bool _useLogo = false; // ロゴを表示する
string _logourl = ""; //ロゴクリックで開くページ
bool _useUpdateDownloadLink = false; //新しいバージョンのダウンロードリンクを表示する

#include <MQLAuthBoilerplate.mqh>
```

- `MQLAUTH_ID` と `APPLICATION_NAME` はユーザーから提供された値に書き換える
- **既存コードに `#property version` がある場合**: 元のバージョン番号を `#define VERSION` の値に転記し、元からある `#property version` 行は削除する（`VERSION` はアップデート通知の新旧比較にも使われる）
- `HTTP_QUERY_FLAG -2147483648` は `INTERNET_FLAG_RELOAD`（キャッシュを使わず毎回サーバーから取得）。`#include <MQLAuth.mqh>` より前に定義する必要がある
- **`#include <MQLAuthBoilerplate.mqh>` は必ずカスタマイズ変数ブロックの後に置く。** `MQLAuthBoilerplate.mqh` 内の関数がこれらの変数・defineを参照するため、順序を入れ替えるとコンパイルエラーになる
- カスタマイズ変数の値の変更はユーザー指定があった場合のみ（後述「カスタマイズ変数の設定」）
- `//#resource` 行はロゴ表示機能（オプション）用。コメントアウトのまま追加しておく
- 旧形式MQL4コードでは、実装後に型の警告が増える場合があるが、エラーでなければ問題ない

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
- **旧形式（`int deinit()`）の場合**、`reason` 引数が存在しないため `if(reason == 9)` の代わりに `if(UninitializeReason() == 9)` とする
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

- **旧形式（`int start()`）の場合** — EA・インジケーターとも `int` を返す必要があるため、以下を先頭に追加:

```mql4
   if(!_isAuthorized) return(0);
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

- 認証成功後、標準実装はタイマー周期を1秒に再設定する。既存のタイマー処理が特定の周期（`EventSetTimer` / `EventSetMillisecondTimer` の設定値）に依存している場合は、その旨をユーザーに確認すること

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

以上で実装は完了。認証・キャッシュ・メッセージ表示・エラー表示の実装本体は `MQLAuthBoilerplate.mqh` に含まれているため、ソースコードへ認証ロジックを書き足す必要はない。

## カスタマイズ変数の設定

Step 1で追加した「MQLAuth カスタマイズ」ブロックの変数で機能をオン/オフできる。ユーザーから指定があった場合のみ値を変更する（デフォルトのままでも標準的な構成で動作する）。

| 変数 | デフォルト | 意味 |
|---|---|---|
| `_useApplicationMessage` | `true` | 一斉メッセージ表示を利用する |
| `_applicationMessageViewSecond` | `8` | 一斉メッセージを消すまでの秒数 |
| `_useUserMessage` | `true` | 個別メッセージ表示を利用する |
| `_userMessageViewSecond` | `8` | 個別メッセージを消すまでの秒数 |
| `_useUpdateMessage` | `true` | アップデート通知を利用する |
| `_useTrial` | `false` | 体験版機能（未登録口座の自動登録）を使用する |
| `_day` | `0` | 体験版の日数 |
| `_useLogo` | `false` | チャートにロゴを表示する（Step 1の `#resource` の有効化も必要） |
| `_logourl` | `""` | ロゴクリックで開くURL |
| `_useUpdateDownloadLink` | `false` | 新バージョンのダウンロードリンクを表示する |

## 実装ルール

1. **既存ロジックを変更しない。** 認証コードの追加のみを行い、既存の売買ロジック・計算ロジック・パラメータには手を付けない
2. **`MQLAuthBoilerplate.mqh` の中身を書き換えたり、内容をソースコードへ展開コピーしたりしない。** includeのまま使う。このファイルには認証・キャッシュ・メッセージ表示・エラー表示の全実装が含まれており、変更するとMQLAuthサーバーとの互換性が壊れる恐れがある
3. **MQLAUTH_ID・アプリケーション名はユーザー提供の値のみ使用。** プレースホルダのまま残す場合は、その旨をユーザーに明確に伝える
4. 既存コードとの名前衝突（`_isAuthorized` 等がすでに定義されている等）を発見した場合は、機械的にリネームせず、ユーザーに報告して指示を仰ぐ
5. **認証頻度を勝手に上げない。** MQLAuthサーバーには同一端末30回/60秒のアクセス制限がある。標準実装は初回認証後ローカルキャッシュを使う設計になっており、これを変更しない
6. 標準実装の主な実績はMQL4環境のため、MQL5に実装した場合は必ず実機での動作確認をユーザーに依頼すること

## 実装後の自己チェックリスト

実装を終えたら、以下を確認して結果をユーザーに報告すること。

- [ ] Step 1のdefine群＋`#include <MQLAuth.mqh>` がファイル先頭にある（`HTTP_QUERY_FLAG` がincludeより前）
- [ ] カスタマイズ変数ブロックの**後**に `#include <MQLAuthBoilerplate.mqh>` がある
- [ ] 既存の `#property version` があった場合、`#define VERSION` に統合し、元の行を削除した
- [ ] `OnInit` 先頭に3行（既存タイマーがある場合は2行）追加した
- [ ] `OnDeinit` に追記した（既存 `EventKillTimer` との重複なし）
- [ ] `OnTick`（EA）または `OnCalculate`（インジケーター）の先頭に `_isAuthorized` ガードがある
- [ ] `OnTimer` / `OnChartEvent` を追加（既存がある場合は先頭に追記）した
- [ ] `MQLAuthBoilerplate.mqh` の中身を改変・展開コピーしていない
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
- **コンパイルエラー: can't open "MQLAuthBoilerplate.mqh"** → 同じIncludeフォルダに MQLAuthBoilerplate.mqh が配置されているか確認（入手先: https://mqlauth-manual.pages.dev/MQLAuthBoilerplate.mqh ）
- **コンパイルエラー: undeclared identifier（`_useApplicationMessage` 等）** → `#include <MQLAuthBoilerplate.mqh>` がカスタマイズ変数ブロックより**前**に置かれていないか確認（正しい順序: カスタマイズ変数 → include）
- **コンパイルエラー: 'TimeHour' - function already defined（MQL5）** → ユーザーのソースコードに同名の `TimeHour` ヘルパーが既にある。実装が同一（`MqlDateTime` 経由でhourを返すだけ）ならユーザー側の定義を削除してよい。異なる実装ならユーザーに確認する（`MQLAuthBoilerplate.mqh` 側は変更しない）
- **認証が常に失敗する** → (1) MQLAuth IDの綴り、(2) アプリケーション名が管理画面の登録名と完全一致か、(3) 口座番号が管理画面に登録済みか・期限内か、を確認
- **「認証アクセス過多です」のアラート** → サーバーのアクセス制限（30回/60秒）超過。時間を置いてから再試行
- **Error:000「DLLの使用が許可されていません」がチャートに表示される** → MT4/MT5の設定で「DLLの使用を許可する」をON
- **口座番号を登録・期限更新したのに反映されない** → 認証結果は当日分がローカルキャッシュされる。MT4/MT5を再起動するか、EA・インジケーターをチャートに再適用する
