# MQLAuth 実装ガイド（AIコーディングアシスタント向け）

このドキュメントは、AIコーディングアシスタント（Claude Code、Cursor、ChatGPT、GitHub Copilot等）が、ユーザーのMQL4/MQL5ソースコードにMQLAuth認証を実装するための手順書です。人間向けマニュアルは https://manual.mql-auth.com/ にあります。

対応バージョン: MQLAuth.mqh v1.09以降（2026年7月時点の配布版）

## MQLAuthとは

- MT4/MT5のEA・インジケーター向け認証サービス（https://mql-auth.com）
- EA・インジケーターの利用者を「MT口座番号」または「パスワード」で認証し、利用者ごとに利用期限を設定できる
- 販売者はMQLAuthのWeb管理画面で利用者の口座番号・期限を登録する
- 認証はHTTPS経由（wininet.dll使用）でMQLAuthサーバーに問い合わせる

## 実装前にユーザーに確認する情報

以下の情報が提示されていない場合、**推測で埋めずに必ずユーザーに確認すること**。

1. **MQLAuth ID** — 管理画面で確認できるGUID形式のID（例: `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`）
2. **アプリケーション名** — MQLAuthの管理画面に登録したEA・インジケーターの名称（完全一致が必要）
3. **認証方式** — 「口座番号認証」（標準）か「パスワード認証」か。指定がなければ口座番号認証を実装する

## 前提条件（ユーザー環境）

- `MQLAuth.mqh` が `MQL4/Include/` または `MQL5/Include/` に配置されていること（https://mql-auth.com の上部メニュー「ダウンロード」から入手）
- MT4/MT5で「DLLの使用を許可する」が必要（wininet.dll・shell32.dllを使用するため）。コードでの対応は不要だが、検証手順に含めること

## Step 0: 対象ソースコードの判別

実装前に、渡されたソースコードについて以下を判別する。

**MQL4かMQL5か**
- 拡張子 `.mq5`、`OnCalculate`/`CopyBuffer`/`MqlTradeRequest` 等のMQL5 API使用 → MQL5
- 拡張子 `.mq4`、`#property strict`、`OrderSend(Symbol(), OP_BUY, ...)` 形式 → MQL4
- 本ガイドのコードはMQL4/MQL5共通で動作する（差異がある箇所は明記する）

**EAかインジケーターか**
- `OnTick()` がある、注文関数を使う → EA
- `OnCalculate()` や `#property indicator_buffers` がある → インジケーター

**旧形式MQL4（Build 600以前の書き方）か**
- `#property strict` がなく、`init()` / `start()` / `deinit()` を使用 → 旧形式
- 旧形式の場合もこのガイドの実装は可能（現行コンパイラは新旧混在を許容する）。イベントハンドラ名は `OnInit→init` 等と読み替えるが、`OnTimer()` は旧形式に存在しないため新規追加でよい

## Step 1: ファイル先頭にdefineとincludeを追加

ソースコードの最上部（既存の `#property` や `#include` より前）に以下を追加する。

```mql4
#define MQLAUTH_ID "ここにユーザーのMQLAuth IDを入れる"
#define APPLICATION_NAME "ここに登録済みアプリケーション名を入れる"
#define HTTP_QUERY_FLAG -2147483648
#include <MQLAuth.mqh>
```

- `HTTP_QUERY_FLAG -2147483648` は `INTERNET_FLAG_RELOAD`（キャッシュを使わず毎回サーバーから取得）。`#include` より前に定義する必要がある
- `MQLAuth.mqh` 内部で `#property strict` が宣言されているため、includeするだけで strict モードになる点に注意（旧形式コードで型の警告が増える場合があるが、動作には通常影響しない）

## Step 2: 認証状態フラグをグローバルに宣言

グローバルスコープ（関数の外）に以下を追加する。`MQLAuth.mqh` には定義されていないため、必ず自分で宣言する。

```mql4
bool _isAuthorized = false;      // MQLAuth認証の成否
datetime _mqlauthNextCheck = 0;  // 次回認証チェック時刻
```

既存コードに同名変数がある場合は、衝突しない名前（例: `_mqlauthIsAuthorized`）に変えて以降のコードも一貫して置き換えること。

## Step 3: 認証関数をグローバルに追加

以下の関数をソースコードに追加する（口座番号認証の場合）。

```mql4
void MQLAuth_Check() {
   if(TimeLocal() < _mqlauthNextCheck) return;
   if(AccountInfoInteger(ACCOUNT_LOGIN) == 0) return; // 口座情報取得前は次のタイマーで再試行
   _mqlauthNextCheck = TimeLocal() + 86400; // 認証チェックは1日1回
   if(AuthByAccountNumber_ReturnBool(MQLAUTH_ID, APPLICATION_NAME)) {
      _isAuthorized = true;
      Print("[MQLAuth] 認証成功（口座番号: ", AccountInfoInteger(ACCOUNT_LOGIN), "）");
   } else {
      _isAuthorized = false;
      Print("[MQLAuth] 認証失敗: この口座番号（", AccountInfoInteger(ACCOUNT_LOGIN), "）は未登録か、利用期限が過ぎています。");
   }
}
```

- `AccountInfoInteger(ACCOUNT_LOGIN)` はMQL4（Build 600以降）/MQL5共通で使える
- **認証頻度を上げないこと。** MQLAuthサーバーには同一端末30回/60秒のアクセス制限があり、超過すると認証がエラーになる。`OnTick` 内で毎ティック認証する実装は絶対にしない

## Step 4: タイマーで認証を起動する

起動直後は口座情報が取得できない場合があるため、認証は `OnInit` ではなくタイマー経由で行う。

**ケースA: 既存コードがタイマーを使っていない場合**（`EventSetTimer` / `EventSetMillisecondTimer` / `OnTimer` がない）

`OnInit()` の先頭に追加:

```mql4
EventSetTimer(1);
```

グローバルに `OnTimer()` を新規追加:

```mql4
void OnTimer() {
   MQLAuth_Check();
}
```

`OnDeinit()` に `EventKillTimer();` を追加（`OnDeinit` がなければ新規追加）:

```mql4
void OnDeinit(const int reason) {
   EventKillTimer();
}
```

**ケースB: 既存コードが既にタイマーを使っている場合**

- `OnInit` の `EventSetTimer` 系は既存のまま変更しない（追加もしない）
- 既存 `OnTimer()` の先頭に `MQLAuth_Check();` を1行追加する
- 既存の `EventKillTimer` もそのまま
- 注意: 既存タイマー間隔が長い場合（例: 60秒）、初回認証がその間隔分遅れる。これは許容範囲。ただし間隔が極端に長い（数時間等）場合はユーザーに報告する

## Step 5: 全イベント経路を `_isAuthorized` でガードする

認証が成功するまで、製品の本来の機能が一切動作しないようにする。**ガード漏れが1箇所でもあると認証の意味がなくなるため、以下を機械的に全て適用すること。**

- **EAの場合** — `OnTick()` の先頭に追加:

```mql4
if(!_isAuthorized) return;
```

- **インジケーターの場合** — `OnCalculate()` の先頭に追加:

```mql4
if(!_isAuthorized) return(0);
```

- **既存の `OnTimer()` がある場合** — `MQLAuth_Check();` の直後に `if(!_isAuthorized) return;` を追加し、既存のタイマー処理が未認証時に動かないようにする（新規追加したOnTimerなら不要）
- **その他のハンドラ** — `OnChartEvent` / `OnTrade` / `OnTradeTransaction` / `OnBookEvent` / `start()`（旧形式）等、製品の機能に到達するハンドラが存在する場合は、それぞれの先頭にも同じガードを追加する（戻り値の型に合わせて `return;` / `return(0);` を使い分ける）
- 旧形式の `start()` は `OnTick`/`OnCalculate` に相当するため、同様にガードする

## パスワード認証の場合（口座番号認証の代わり）

Step 3・4 の代わりに、input変数と `OnInit` 内の認証を実装する（パスワード認証は口座情報に依存しないため `OnInit` で直接呼べる）。

```mql4
input string MQLAuthPassword = "";//認証パスワード
```

`OnInit()` の先頭に追加:

```mql4
if(AuthByPassword_ReturnBool(MQLAUTH_ID, APPLICATION_NAME, MQLAuthPassword)) {
   _isAuthorized = true;
   Print("[MQLAuth] パスワード認証に成功しました。");
} else {
   Print("[MQLAuth] パスワード認証に失敗しました。パスワードが正しいか確認してください。");
   return(INIT_FAILED);
}
```

Step 2 のフラグ宣言と Step 5 のガードは口座番号認証と同様に必要（`_mqlauthNextCheck` は不要）。

## オプション: 利用期限の表示

認証成功時に利用期限をログ表示したい場合は、`AuthByAccountNumber_ReturnDatetime`（戻り値: 期限のdatetime、失敗時は0）を使える。

```mql4
datetime period = AuthByAccountNumber_ReturnDatetime(MQLAUTH_ID, APPLICATION_NAME);
if(TimeLocal() <= period) {
   _isAuthorized = true;
   Print("[MQLAuth] 認証成功。利用期限: ", TimeToString(period, TIME_DATE));
}
```

パスワード認証版は `AuthByPassword_ReturnDatetime(MQLAUTH_ID, APPLICATION_NAME, MQLAuthPassword)`。

## 実装ルール

1. **既存ロジックを変更しない。** 認証コードの追加のみを行い、既存の売買ロジック・計算ロジック・パラメータには手を付けない
2. **MQLAUTH_ID・アプリケーション名はユーザー提供の値のみ使用。** プレースホルダのまま残す場合は、その旨をユーザーに明確に伝える
3. **認証失敗時の再認証はEA・インジケーターのチャートへの再適用で行われる**（次回チェックは1日後のため）。利用者向けの説明にこの点を含めるようユーザーに伝える
4. 変数名・関数名が既存コードと衝突する場合は、`_mqlauth` プレフィックスを付けた名前に変更する

## 実装後の自己チェックリスト

実装を終えたら、以下を確認して結果をユーザーに報告すること。

- [ ] `#define` 2行（MQLAUTH_ID / APPLICATION_NAME）+ `HTTP_QUERY_FLAG` + `#include <MQLAuth.mqh>` がファイル先頭にある
- [ ] `_isAuthorized` がグローバルに宣言され、初期値 `false`
- [ ] 認証処理がタイマー経由（口座番号認証）または `OnInit`（パスワード認証）で1回だけ実行される構造になっている（毎ティック認証していない）
- [ ] `OnTick` / `OnCalculate` / `start()` の先頭に `_isAuthorized` ガードがある
- [ ] `OnChartEvent` / `OnTrade` 等、存在する全ハンドラにガードがある
- [ ] 既存の `EventSetTimer` / `OnTimer` / `EventKillTimer` と重複・競合していない
- [ ] 既存ロジックに認証以外の変更を加えていない

## ユーザーに伝える検証手順

コードの実装が終わったら、ユーザーに以下の検証を依頼すること。

1. MetaEditorでコンパイルし、0 errors であることを確認
2. MT4/MT5のオプションで「DLLの使用を許可する」（またはEA適用時のダイアログでDLL許可）をONにしてチャートに適用
3. MQLAuthに**登録済み**の口座番号で「認証成功」のログ（エキスパートタブ）が出て、EA・インジケーターが動作することを確認
4. **未登録**の口座番号で「認証失敗」のログが出て、機能が動作しないことを確認

## トラブルシューティング

- **コンパイルエラー: can't open "MQLAuth.mqh"** → `MQL4/Include/`（MT5は `MQL5/Include/`）に MQLAuth.mqh が配置されているか確認
- **認証が常に失敗する** → (1) MQLAuth IDの綴り、(2) アプリケーション名が管理画面の登録名と完全一致か、(3) 口座番号が管理画面に登録済みか・期限内か、を確認
- **「認証アクセス過多です」のアラート** → サーバーのアクセス制限（30回/60秒）超過。認証の呼び出し頻度を下げ、時間を置いて再試行
- **認証は成功するがEAが動かない** → ガードの追加位置を確認（`return` がEA本来の処理より前にあるか、逆に必要な初期化まで止めていないか）
