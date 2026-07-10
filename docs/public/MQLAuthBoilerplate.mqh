//+------------------------------------------------------------------+
//|                                           MQLAuthBoilerplate.mqh |
//|                MQLAuth 標準実装（認証フロー・メッセージ・UI表示） |
//+------------------------------------------------------------------+
// MQLAuth認証の標準実装コードです（実装ガイド付録のボイラープレートを
// includeファイル化したもの）。中身は改変せずそのまま使ってください。
//
// 使い方（AI向け実装ガイド）: https://mqlauth-manual.pages.dev/llms-install.md
//
// 前提: このファイルをincludeする前に、以下が定義されていること
//   1. #define MQLAUTH_ID / APPLICATION_NAME / _prefix / HTTP_QUERY_FLAG / VERSION
//   2. カスタマイズ変数群（_useApplicationMessage 等）
//   3. #include <MQLAuth.mqh>
//
// 対応: MQL4 / MQL5 両対応（MQLAuth.mqh v1.09以降）
// Version 1.01 (2026-07-10) - PayPal連携（未使用機能）を削除、内部リファクタ（動作への影響なし）
// Version 1.02 (2026-07-10) - 重複コードのヘルパー関数化（表示内容・動作は変更なし）
//+------------------------------------------------------------------+
#ifndef __MQLAUTH_BOILERPLATE_MQH__
#define __MQLAUTH_BOILERPLATE_MQH__

#ifdef __MQL5__
// MQL4専用関数 TimeHour() の互換ヘルパー（MQL4では組み込み関数のため定義不要）
int TimeHour(datetime t) { MqlDateTime tm; TimeToStruct(t, tm); return tm.hour; }
#endif

//+------------------------------------------------------------------+
//|  表示・動作の定数                                                   |
//+------------------------------------------------------------------+
#define MQLAUTH_FONT_NAME          "Meiryo" // チャート表示のフォント
#define MQLAUTH_FONT_SIZE          12       // チャート表示のフォントサイズ
#define MQLAUTH_LINE_HEIGHT        20       // メッセージ1行の高さ（px）
#define MQLAUTH_MSG_X_DEFAULT      20       // メッセージ表示のX位置
#define MQLAUTH_MSG_X_WITH_LOGO    80       // メッセージ表示のX位置（ロゴ表示時）
#define MQLAUTH_MSG_Y_DEFAULT      20       // メッセージ表示のY位置
#define MQLAUTH_ZORDER_AUTH_MSG    180      // 認証エラー表示のZオーダー
#define MQLAUTH_ZORDER_INFO_MSG    8        // 更新通知・体験版表示のZオーダー
#define MQLAUTH_ZORDER_LOGO        99       // ロゴ表示のZオーダー
#define MQLAUTH_SECONDS_PER_DAY    86400    // 1日の秒数
#define MQLAUTH_TIMER_INTERVAL_SEC 1        // 認証成功後のタイマー周期（秒）

//+------------------------------------------------------------------+
//|  グローバル変数                                                     |
//+------------------------------------------------------------------+
//--- 口座認証に利用する変数
bool _isAuthorized = false; // 口座認証の成否を表す変数
bool _authAttempted = false;// 認証を試行済みかのフラグ（初回のみSYSFAC_Authを呼ぶためのガード）
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

datetime _sysfac_indicatorPeriod;//利用期限
string _randId;// 認証ファイルの名称

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sysfac_onchartevent(int id, string sparam) {
   string _labelUpdateMessage = _prefix + "updateMessage"; // アップデートのお知らせを表示するラベル名
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
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sysfac_onCalc() {
   if(_useLogo)
      _messageXDistance = MQLAUTH_MSG_X_WITH_LOGO;
   else
      _messageXDistance = MQLAUTH_MSG_X_DEFAULT;

   _messageYDistance = MQLAUTH_MSG_Y_DEFAULT;

   if(_useLogo) {
      string _objectLogo = _prefix + "SYSFAC_LOGO"; // ロゴオブジェクトの名前
      Auth_SYSFACShowBMPIMG("\\Include\\Images\\logo.bmp", _objectLogo, CORNER_LEFT_LOWER);
   }

   if(AccountInfoInteger(ACCOUNT_LOGIN) != 0 && !_authAttempted) {
      _authAttempted = true;
      SYSFAC_Auth();
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MQLAuth_CheckDLLsAllowed() {
   if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
      int errorcode = 000;//DLL許可なし
      string errormessages = "DLLの使用が許可されていません。,「DLLの使用を許可する」にチェックを入れてください。";
      MQLAuth_ShowErrorMessage(errorcode, errormessages);
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  認証エラーラベルを1行分作成する（内部ヘルパー）                      |
//+------------------------------------------------------------------+
void MQLAuth_CreateErrorLabel(string name, int yOffset, string text) {
   ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(ChartID(), name, OBJPROP_BACK, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTED, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, _messageXDistance);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, _messageYDistance + yOffset);
   ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
   ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, MQLAUTH_FONT_SIZE);
   ObjectSetString(ChartID(), name, OBJPROP_FONT, MQLAUTH_FONT_NAME);
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MQLAuth_ShowErrorMessage(int errorcode, string errormessages) {
   string _ObjectAuthMessage1 = _prefix + "objectAuthMessage1"; // 認証メッセージを表示するラベル名1
   string _ObjectAuthMessage2 = _prefix + "objectAuthMessage2"; // 認証メッセージを表示するラベル名2
   string _ObjectAuthMessage3 = _prefix + "objectAuthMessage3"; // 認証メッセージを表示するラベル名3

   string errormessage[];
   StringSplit(errormessages, ',', errormessage);

   MQLAuth_CreateErrorLabel(_ObjectAuthMessage1, MQLAUTH_LINE_HEIGHT * 2, "[" + APPLICATION_NAME + "] Error:" + (string)errorcode);
   MQLAuth_CreateErrorLabel(_ObjectAuthMessage2, MQLAUTH_LINE_HEIGHT, errormessage[0]);
   MQLAuth_CreateErrorLabel(_ObjectAuthMessage3, 0, errormessage[1]);
}
//+------------------------------------------------------------------+
//|  口座認証のための関数                                               |
//+------------------------------------------------------------------+
bool SYSFAC_Auth() {
   string _ObjectAuthMessage2 = _prefix + "objectAuthMessage2"; // 認証メッセージを表示するラベル名2

   if(!MQLAuth_CheckDLLsAllowed()) return false;

   string text   = APPLICATION_NAME + TimeToString(TimeCurrent(), TIME_DATE) + (string)AccountInfoInteger(ACCOUNT_LOGIN);
   string keystr = MQLAUTH_ID;
   uchar array_src[];
   uchar array_dst[];
   uchar array_key[];
   int   res;

   StringToCharArray(keystr, array_key);
   StringToCharArray(text, array_src);

   res = CryptEncode(CRYPT_HASH_SHA256, array_src, array_key, array_dst);

   _randId = MQLAuth_ArrayToHex(array_dst);

   if(res > 0) {

   } else {
      Alert("認証エラー。 エラーコード =", GetLastError(), "\r\nこのエラーが連続で出るときは、配布元に連絡してください。");
      return false;
   }

   int errorcode = 0;
   string errormessages = "";

   if(!FileIsExist("MQLAuth\\" + MQLAuth_ArrayToHex(array_dst))) {
      bool result = false;
      if(_useTrial) {
         result = AuthByAccountNumberWithAddUser(MQLAUTH_ID, APPLICATION_NAME, _day, _sysfac_indicatorPeriod, _userMessage, errorcode, errormessages);
      } else {
         result = AuthByAccountNumber(MQLAUTH_ID, APPLICATION_NAME, _sysfac_indicatorPeriod, _userMessage, errorcode, errormessages);
      }
      if(result) {
         if(_sysfac_indicatorPeriod >= TimeLocal()) {
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
            MQLAuth_CreateCacheFile("MQLAuth\\" + MQLAuth_ArrayToHex(array_dst), TimeToString(_sysfac_indicatorPeriod, TIME_DATE | TIME_SECONDS), _newestVersion, _updateurl, _applicationMessage, _userMessage);
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
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_YDISTANCE, _messageYDistance + MQLAUTH_LINE_HEIGHT * 2);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_TEXT, "[" + _prefix + "]利用期間が終了しました。");
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_ZORDER, MQLAUTH_ZORDER_AUTH_MSG);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_FONTSIZE, MQLAUTH_FONT_SIZE);
            ObjectSetString(ChartID(), _ObjectAuthMessage2, OBJPROP_FONT, MQLAUTH_FONT_NAME);
            ObjectSetInteger(ChartID(), _ObjectAuthMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));

            //--- 認証メッセージを表示するラベルの作成 ---

            return false;
         }
      } else {
         _isAuthorized = false;
         MQLAuth_ShowErrorMessage(errorcode, errormessages);
         return false;
      }
   } else {
      int filehandle = FileOpen("MQLAuth\\" + MQLAuth_ArrayToHex(array_dst), FILE_SHARE_READ | FILE_CSV, ',');
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
   EventSetTimer(MQLAUTH_TIMER_INTERVAL_SEC);

   return true;
}
//+------------------------------------------------------------------+
//|  受信メッセージを行ごとにラベル表示する（内部ヘルパー）               |
//+------------------------------------------------------------------+
void MQLAuth_ShowMessageLines(string label, string &message[]) {
   for(int i = 0; i < ArraySize(message); i++) {
      ObjectCreate(ChartID(), label + (string)i, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_BACK, false);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_SELECTED, false);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_HIDDEN, true);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_XDISTANCE, _messageXDistance);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_YDISTANCE, _messageYDistance + MQLAUTH_LINE_HEIGHT * (ArraySize(message) - 1 - i));
      ObjectSetString(ChartID(), label + (string)i, OBJPROP_TEXT, message[i]);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_FONTSIZE, MQLAUTH_FONT_SIZE);
      ObjectSetString(ChartID(), label + (string)i, OBJPROP_FONT, MQLAUTH_FONT_NAME);
      ObjectSetInteger(ChartID(), label + (string)i, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
   }
}
//+------------------------------------------------------------------+
//|  メッセージ表示終了後の後続表示（更新通知／体験版期限）（内部ヘルパー）|
//+------------------------------------------------------------------+
void MQLAuth_ShowFollowupInfo(string labelToClear) {
   string _labelUpdateMessage = _prefix + "updateMessage"; // アップデートのお知らせを表示するラベル名
   string _labelUpdateMessage2 = _prefix + "updateMessage2"; // アップデートのお知らせを表示するラベル名
   string _ObjectAuthMessage1 = _prefix + "objectAuthMessage1"; // 認証メッセージを表示するラベル名1

   ObjectsDeleteAll(ChartID(), labelToClear);
   if(_newestVersion != "" && StringToDouble(VERSION) < StringToDouble(_newestVersion)) {
      ObjectCreate(ChartID(), _labelUpdateMessage, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_SELECTED, false);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_HIDDEN, true);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_XDISTANCE, _messageXDistance);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_YDISTANCE, _messageYDistance + MQLAUTH_LINE_HEIGHT * 2);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_ZORDER, MQLAUTH_ZORDER_INFO_MSG);
      ObjectSetString(ChartID(), _labelUpdateMessage, OBJPROP_TEXT, "[" + APPLICATION_NAME + "]新しいバージョン " + _newestVersion + " があります。");
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_FONTSIZE, MQLAUTH_FONT_SIZE);
      ObjectSetString(ChartID(), _labelUpdateMessage, OBJPROP_FONT, MQLAUTH_FONT_NAME);
      ObjectSetInteger(ChartID(), _labelUpdateMessage, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
      if(_useUpdateDownloadLink){
         ObjectCreate(ChartID(), _labelUpdateMessage2, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_SELECTED, false);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_HIDDEN, true);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_XDISTANCE, _messageXDistance);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_YDISTANCE, _messageYDistance + MQLAUTH_LINE_HEIGHT);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_ZORDER, MQLAUTH_ZORDER_INFO_MSG);
         ObjectSetString(ChartID(), _labelUpdateMessage2, OBJPROP_TEXT, "ダウンロードするにはここをクリック");
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_FONTSIZE, MQLAUTH_FONT_SIZE);
         ObjectSetString(ChartID(), _labelUpdateMessage2, OBJPROP_FONT, MQLAUTH_FONT_NAME);
         ObjectSetInteger(ChartID(), _labelUpdateMessage2, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
      }
   } else if(_sysfac_indicatorPeriod - _day * MQLAUTH_SECONDS_PER_DAY <= TimeLocal()) {
      ObjectCreate(ChartID(), _ObjectAuthMessage1, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_SELECTED, false);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_HIDDEN, true);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_XDISTANCE, _messageXDistance);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_YDISTANCE, _messageYDistance + MQLAUTH_LINE_HEIGHT * 2);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_ZORDER, MQLAUTH_ZORDER_INFO_MSG);
      string date = TimeToString(_sysfac_indicatorPeriod, TIME_DATE | TIME_SECONDS);
      StringReplace(date, ".", "/");
      ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_TEXT, "[" + APPLICATION_NAME + "体験版] 利用期限： " + date);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_FONTSIZE, MQLAUTH_FONT_SIZE);
      ObjectSetString(ChartID(), _ObjectAuthMessage1, OBJPROP_FONT, MQLAUTH_FONT_NAME);
      ObjectSetInteger(ChartID(), _ObjectAuthMessage1, OBJPROP_COLOR, (color)ChartGetInteger(ChartID(), CHART_COLOR_FOREGROUND));
   } else {
   }
}
//+------------------------------------------------------------------+
//|   メッセージを取得し表示する関数                                       |
//+------------------------------------------------------------------+
void SYSFAC_Message() {
   string _labelApplicationMessage = _prefix + "applicationMessage"; // メッセージを表示するラベル名
   string _labelUserMessage = _prefix + "userMessage"; // メッセージを表示するラベル名

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
            MQLAuth_ShowMessageLines(_labelApplicationMessage, message);
            _applicationMessageurl = result[1];
         } else {
            string message[];
            StringSplit(messages, '\r', message);
            MQLAuth_ShowMessageLines(_labelApplicationMessage, message);
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
            StringTrimRight(result[0]); // 一斉メッセージ側には無い既存の非対称（挙動保存のため維持）
            StringSplit(result[0], '\r', message);
            MQLAuth_ShowMessageLines(_labelUserMessage, message);
            _userMessageurl = result[1];
         } else {
            string message[];
            StringSplit(messages, '\r', message);
            MQLAuth_ShowMessageLines(_labelUserMessage, message);
            _userMessageurl = "";
         }
         _viewUserMessageTime = GetTickCount();
      } else {
         _viewUserMessageTime = 1;
      }
   }
   if(_useUserMessage && _viewUserMessageTime != 0 && GetTickCount() - _viewUserMessageTime > _userMessageViewSecond * 1000) {
      MQLAuth_ShowFollowupInfo(_labelUserMessage);
   } else if(!_useUserMessage && _viewApplicationMessageTime != 0 && GetTickCount() - _viewApplicationMessageTime > _applicationMessageViewSecond * 1000) {
      MQLAuth_ShowFollowupInfo(_labelApplicationMessage);
   }
   if(_sysfac_indicatorPeriod <= TimeLocal()) {
      if(FileIsExist("MQLAuth\\" + _randId)) {
         FileDelete("MQLAuth\\" + _randId);
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
      errorcode = 200;//サーバ接続失敗
      errormessage = "サーバとの接続に失敗しました。,ネットワークの接続を確認してください。";
      period = 0;
      return false;
   }

   CJAVal json;
   json.Deserialize(result);
   if(json["status"].ToStr() == "429") {
      errorcode = 300;//認証アクセス過多（30回/60秒制限）
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
      errorcode = 200;//サーバ接続失敗
      errormessage = "サーバとの接続に失敗しました。,ネットワークの接続を確認してください。";
      period = 0;
      return false;
   }

   CJAVal json;
   json.Deserialize(result);
   if(json["status"].ToStr() == "429") {
      errorcode = 300;//認証アクセス過多（30回/60秒制限）
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
void MQLAuth_CreateCacheFile(string m_filename, string period, string m_text1, string m_text2, string m_text3, string m_text4) {
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
string MQLAuth_ArrayToHex(uchar &arr[], int count = -1) {
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
void Auth_SYSFACShowBMPIMG(string imgpath, string imgname, ENUM_BASE_CORNER m_corner = 0, int xdistance = 20, int ydistance = 20, int zorder = MQLAUTH_ZORDER_LOGO) {
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

#endif // __MQLAUTH_BOILERPLATE_MQH__
