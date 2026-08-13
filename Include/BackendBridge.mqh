//+------------------------------------------------------------------+
//|                                                   BackendBridge.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict

#define BACKEND_TIMER_SECONDS           30
#define BACKEND_HTTP_TIMEOUT_MS         2000
#define BACKEND_HEARTBEAT_INTERVAL      60
#define BACKEND_SNAPSHOT_INTERVAL       60
#define BACKEND_COMMAND_POLL_INTERVAL   30
#define BACKEND_SIGNAL_RETRY_INTERVAL   30
#define BACKEND_MAX_SIGNAL_QUEUE        20

string g_backendSignalQueue[];
datetime g_backendLastHeartbeat = 0;
datetime g_backendLastSnapshot = 0;
datetime g_backendLastCommandPoll = 0;
datetime g_backendLastSignalAttempt = 0;

//+------------------------------------------------------------------+
//| Return whether the bridge has enough configuration to operate    |
//+------------------------------------------------------------------+
bool BackendBridgeIsConfigured()
{
   return StringLen(BackendURL) > 0;
}

//+------------------------------------------------------------------+
//| Remove trailing slashes from the configured backend URL           |
//+------------------------------------------------------------------+
string BackendBridgeBaseUrl()
{
   string url = BackendURL;
   while(StringLen(url) > 0 && StringGetCharacter(url, StringLen(url) - 1) == '/')
      url = StringSubstr(url, 0, StringLen(url) - 1);
   return url;
}

//+------------------------------------------------------------------+
//| Escape values placed inside JSON strings                         |
//+------------------------------------------------------------------+
string BackendBridgeJsonEscape(const string value)
{
   string escaped = "";
   int length = StringLen(value);

   for(int i = 0; i < length; i++)
   {
      ushort character = StringGetCharacter(value, i);
      switch(character)
      {
         case 8:  escaped += "\\b"; break;
         case 9:  escaped += "\\t"; break;
         case 10: escaped += "\\n"; break;
         case 13: escaped += "\\r"; break;
         case 34: escaped += "\\\""; break;
         case 92: escaped += "\\\\"; break;
         default: escaped += StringSubstr(value, i, 1); break;
      }
   }

   return escaped;
}

//+------------------------------------------------------------------+
//| Convert a boolean to its JSON representation                      |
//+------------------------------------------------------------------+
string BackendBridgeJsonBool(const bool value)
{
   return value ? "true" : "false";
}

//+------------------------------------------------------------------+
//| Convert an order type to a dashboard-friendly direction           |
//+------------------------------------------------------------------+
string BackendBridgeOrderDirection(const ENUM_ORDER_TYPE type)
{
   if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT ||
      type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT)
      return "BUY";
   if(type == ORDER_TYPE_SELL || type == ORDER_TYPE_SELL_LIMIT ||
      type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_STOP_LIMIT)
      return "SELL";
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Convert a position type to a dashboard-friendly direction         |
//+------------------------------------------------------------------+
string BackendBridgePositionDirection(const ENUM_POSITION_TYPE type)
{
   if(type == POSITION_TYPE_BUY) return "BUY";
   if(type == POSITION_TYPE_SELL) return "SELL";
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Identify the timeframe represented by the existing signal label  |
//+------------------------------------------------------------------+
string BackendBridgeSignalTimeframe(const string comment)
{
   if(StringFind(comment, "M15") >= 0) return "M15";
   if(StringFind(comment, "M5") >= 0) return "M5";
   return "M1";
}

//+------------------------------------------------------------------+
//| Perform one HTTP request without affecting trading decisions      |
//+------------------------------------------------------------------+
bool BackendBridgeHttpRequest(const string method,
                              const string path,
                              const string payload,
                              string &response)
{
   response = "";
   if(!BackendBridgeIsConfigured()) return false;

   string headers = "Content-Type: application/json\r\n";
   if(StringLen(BackendAPIKey) > 0)
      headers += "Authorization: Bearer " + BackendAPIKey + "\r\n";

   uchar requestData[];
   if(StringLen(payload) > 0)
   {
      int requestBytes = StringToCharArray(
         payload, requestData, 0, WHOLE_ARRAY, CP_UTF8
      );
      if(requestBytes > 0)
         ArrayResize(requestData, requestBytes - 1);
   }

   uchar result[];
   string resultHeaders = "";
   ResetLastError();

   int status = WebRequest(method,
                           BackendBridgeBaseUrl() + path,
                           headers,
                           BACKEND_HTTP_TIMEOUT_MS,
                           requestData,
                           result,
                           resultHeaders);
   int requestError = GetLastError();

   if(status == -1)
   {
      Print(LOG_PREFIX, "Backend request failed: ", method, " ", path,
            " error=", requestError);
      return false;
   }

   response = CharArrayToString(result, 0, -1, CP_UTF8);
   if(status < 200 || status >= 300)
   {
      Print(LOG_PREFIX, "Backend returned HTTP ", status, " for ",
            method, " ", path, ". Response bytes: ", ArraySize(result));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Send a JSON payload to a backend API endpoint                    |
//+------------------------------------------------------------------+
bool BackendBridgePost(const string path, const string payload)
{
   string response = "";
   return BackendBridgeHttpRequest("POST", path, payload, response);
}

//+------------------------------------------------------------------+
//| Build the signal JSON without performing network I/O              |
//+------------------------------------------------------------------+
string BackendBridgeBuildSignalPayload(const ENUM_ORDER_TYPE type,
                                       const int score,
                                       const string reason,
                                       const double riskPercent,
                                       const double tpRR,
                                       const string comment)
{
   return "{" +
      "\"type\":\"signal\"," +
      "\"timestamp\":" + (string)(long)TimeCurrent() + "," +
      "\"symbol\":\"" + BackendBridgeJsonEscape(_Symbol) + "\"," +
      "\"timeframe\":\"" + BackendBridgeSignalTimeframe(comment) + "\"," +
      "\"direction\":\"" + BackendBridgeOrderDirection(type) + "\"," +
      "\"score\":" + IntegerToString(score) + "," +
      "\"reason\":\"" + BackendBridgeJsonEscape(reason) + "\"," +
      "\"risk_percent\":" + DoubleToString(riskPercent, 4) + "," +
      "\"take_profit_rr\":" + DoubleToString(tpRR, 4) + "," +
      "\"source\":\"" + BackendBridgeJsonEscape(comment) + "\"" +
      "}";
}

//+------------------------------------------------------------------+
//| Queue a detected signal for delivery from OnTimer                 |
//+------------------------------------------------------------------+
void BackendBridgeQueueSignal(const ENUM_ORDER_TYPE type,
                              const int score,
                              const string reason,
                              const double riskPercent,
                              const double tpRR,
                              const string comment)
{
   if(!BackendBridgeIsConfigured()) return;

   int count = ArraySize(g_backendSignalQueue);
   if(count >= BACKEND_MAX_SIGNAL_QUEUE)
   {
      for(int i = 1; i < count; i++)
         g_backendSignalQueue[i - 1] = g_backendSignalQueue[i];
      count--;
      ArrayResize(g_backendSignalQueue, count);
   }

   ArrayResize(g_backendSignalQueue, count + 1);
   g_backendSignalQueue[count] = BackendBridgeBuildSignalPayload(
      type, score, reason, riskPercent, tpRR, comment
   );
}

//+------------------------------------------------------------------+
//| Remove the oldest queued signal after successful delivery         |
//+------------------------------------------------------------------+
void BackendBridgeRemoveOldestSignal()
{
   int count = ArraySize(g_backendSignalQueue);
   if(count <= 0) return;

   for(int i = 1; i < count; i++)
      g_backendSignalQueue[i - 1] = g_backendSignalQueue[i];
   ArrayResize(g_backendSignalQueue, count - 1);
}

//+------------------------------------------------------------------+
//| Deliver at most one queued signal per timer cycle                 |
//+------------------------------------------------------------------+
void BackendBridgeFlushSignalQueue(const datetime now)
{
   int count = ArraySize(g_backendSignalQueue);
   if(count <= 0) return;
   if(g_backendLastSignalAttempt > 0 &&
      now - g_backendLastSignalAttempt < BACKEND_SIGNAL_RETRY_INTERVAL)
      return;

   g_backendLastSignalAttempt = now;
   if(BackendBridgePost("/api/v1/ea/signals", g_backendSignalQueue[0]))
      BackendBridgeRemoveOldestSignal();
}

//+------------------------------------------------------------------+
//| Build the current position snapshot for this EA and symbol        |
//+------------------------------------------------------------------+
string BackendBridgeBuildPositionsPayload()
{
   string positions = "[";
   bool first = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      if(!first) positions += ",";
      first = false;

      ENUM_POSITION_TYPE positionType =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      positions += "{" +
         "\"ticket\":\"" + (string)ticket + "\"," +
         "\"symbol\":\"" + BackendBridgeJsonEscape(PositionGetString(POSITION_SYMBOL)) + "\"," +
         "\"direction\":\"" + BackendBridgePositionDirection(positionType) + "\"," +
         "\"volume\":" + DoubleToString(PositionGetDouble(POSITION_VOLUME), 8) + "," +
         "\"open_price\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), _Digits) + "," +
         "\"current_price\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), _Digits) + "," +
         "\"stop_loss\":" + DoubleToString(PositionGetDouble(POSITION_SL), _Digits) + "," +
         "\"take_profit\":" + DoubleToString(PositionGetDouble(POSITION_TP), _Digits) + "," +
         "\"profit\":" + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2) + "," +
         "\"swap\":" + DoubleToString(PositionGetDouble(POSITION_SWAP), 2) + "," +
         "\"magic\":" + (string)PositionGetInteger(POSITION_MAGIC) + "," +
         "\"comment\":\"" + BackendBridgeJsonEscape(PositionGetString(POSITION_COMMENT)) + "\"," +
         "\"opened_at\":" + (string)PositionGetInteger(POSITION_TIME) +
         "}";
   }
   positions += "]";

   return "{" +
      "\"type\":\"positions\"," +
      "\"timestamp\":" + (string)(long)TimeCurrent() + "," +
      "\"symbol\":\"" + BackendBridgeJsonEscape(_Symbol) + "\"," +
      "\"account\":{" +
         "\"login\":" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "," +
         "\"balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "," +
         "\"equity\":" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "," +
         "\"margin\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) + "," +
         "\"free_margin\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) +
      "}," +
      "\"positions\":" + positions +
      "}";
}

//+------------------------------------------------------------------+
//| Build one closed-candle object                                   |
//+------------------------------------------------------------------+
string BackendBridgeBuildCandle(const ENUM_TIMEFRAMES timeframe,
                                const string timeframeName)
{
   datetime candleTime = iTime(_Symbol, timeframe, 1);
   if(candleTime <= 0)
      return "{\"timeframe\":\"" + timeframeName + "\",\"available\":false}";

   return "{" +
      "\"timeframe\":\"" + timeframeName + "\"," +
      "\"available\":true," +
      "\"time\":" + (string)(long)candleTime + "," +
      "\"open\":" + DoubleToString(iOpen(_Symbol, timeframe, 1), _Digits) + "," +
      "\"high\":" + DoubleToString(iHigh(_Symbol, timeframe, 1), _Digits) + "," +
      "\"low\":" + DoubleToString(iLow(_Symbol, timeframe, 1), _Digits) + "," +
      "\"close\":" + DoubleToString(iClose(_Symbol, timeframe, 1), _Digits) + "," +
      "\"volume\":" + (string)iVolume(_Symbol, timeframe, 1) +
      "}";
}

//+------------------------------------------------------------------+
//| Build the market and closed-candle snapshot                       |
//+------------------------------------------------------------------+
string BackendBridgeBuildMarketPayload()
{
   MqlTick tick;
   bool hasTick = SymbolInfoTick(_Symbol, tick);
   double spreadPoints = 0;
   if(hasTick && _Point > 0)
      spreadPoints = (tick.ask - tick.bid) / _Point;

   return "{" +
      "\"type\":\"market\"," +
      "\"timestamp\":" + (string)(long)TimeCurrent() + "," +
      "\"symbol\":\"" + BackendBridgeJsonEscape(_Symbol) + "\"," +
      "\"digits\":" + IntegerToString(_Digits) + "," +
      "\"point\":" + DoubleToString(_Point, 10) + "," +
      "\"tick\":{" +
         "\"available\":" + BackendBridgeJsonBool(hasTick) + "," +
         "\"bid\":" + DoubleToString(hasTick ? tick.bid : 0, _Digits) + "," +
         "\"ask\":" + DoubleToString(hasTick ? tick.ask : 0, _Digits) + "," +
         "\"spread_points\":" + DoubleToString(spreadPoints, 2) +
      "}," +
      "\"candles\":[" +
         BackendBridgeBuildCandle(PERIOD_M1, "M1") + "," +
         BackendBridgeBuildCandle(PERIOD_M5, "M5") + "," +
         BackendBridgeBuildCandle(PERIOD_M15, "M15") +
      "]" +
      "}";
}

//+------------------------------------------------------------------+
//| Send the current position snapshot                               |
//+------------------------------------------------------------------+
void BackendBridgeSendPositions()
{
   BackendBridgePost("/api/v1/ea/positions", BackendBridgeBuildPositionsPayload());
}

//+------------------------------------------------------------------+
//| Send market and candle information                               |
//+------------------------------------------------------------------+
void BackendBridgeSendMarket()
{
   BackendBridgePost("/api/v1/ea/market", BackendBridgeBuildMarketPayload());
}

//+------------------------------------------------------------------+
//| Send a periodic EA heartbeat                                     |
//+------------------------------------------------------------------+
void BackendBridgeSendHeartbeat()
{
   string payload = "{" +
      "\"type\":\"heartbeat\"," +
      "\"timestamp\":" + (string)(long)TimeCurrent() + "," +
      "\"symbol\":\"" + BackendBridgeJsonEscape(_Symbol) + "\"," +
      "\"account_login\":" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "," +
      "\"magic\":" + IntegerToString(InpMagicNumber) + "," +
      "\"trading_enabled\":" + BackendBridgeJsonBool(
         GlobalTradingEnabled && InpEnableTrading
      ) + "," +
      "\"backend_configured\":" + BackendBridgeJsonBool(
         BackendBridgeIsConfigured()
      ) + "," +
      "\"terminal_build\":" + (string)TerminalInfoInteger(TERMINAL_BUILD) +
      "}";

   BackendBridgePost("/api/v1/ea/heartbeat", payload);
}

//+------------------------------------------------------------------+
//| Poll for commands without executing any command yet               |
//+------------------------------------------------------------------+
void BackendBridgePollCommands()
{
   string path = "/api/v1/ea/commands?symbol=" +
      BackendBridgeJsonEscape(_Symbol) +
      "&magic=" + IntegerToString(InpMagicNumber);
   string response = "";

   if(!BackendBridgeHttpRequest("GET", path, "", response)) return;
   if(StringLen(response) > 0)
   {
      Print(LOG_PREFIX,
            "Backend returned pending command data. Command execution is not enabled.");
   }
}

//+------------------------------------------------------------------+
//| Initialize the bridge state                                     |
//+------------------------------------------------------------------+
void BackendBridgeInit()
{
   ArrayResize(g_backendSignalQueue, 0);
   g_backendLastHeartbeat = 0;
   g_backendLastSnapshot = 0;
   g_backendLastCommandPoll = 0;
   g_backendLastSignalAttempt = 0;

   if(BackendBridgeIsConfigured())
      Print(LOG_PREFIX, "Backend bridge enabled: ", BackendBridgeBaseUrl());
   else
      Print(LOG_PREFIX, "Backend bridge disabled: BackendURL is empty.");
}

//+------------------------------------------------------------------+
//| Release bridge state                                            |
//+------------------------------------------------------------------+
void BackendBridgeShutdown()
{
   ArrayFree(g_backendSignalQueue);
}

//+------------------------------------------------------------------+
//| Periodic communication entry point, called from OnTimer          |
//+------------------------------------------------------------------+
void BackendBridgeOnTimer()
{
   if(!BackendBridgeIsConfigured()) return;

   datetime now = TimeCurrent();
   if(now <= 0) now = TimeLocal();

   BackendBridgeFlushSignalQueue(now);

   if(g_backendLastHeartbeat == 0 ||
      now - g_backendLastHeartbeat >= BACKEND_HEARTBEAT_INTERVAL)
   {
      g_backendLastHeartbeat = now;
      BackendBridgeSendHeartbeat();
   }

   if(g_backendLastSnapshot == 0 ||
      now - g_backendLastSnapshot >= BACKEND_SNAPSHOT_INTERVAL)
   {
      g_backendLastSnapshot = now;
      BackendBridgeSendPositions();
      BackendBridgeSendMarket();
   }

   if(g_backendLastCommandPoll == 0 ||
      now - g_backendLastCommandPoll >= BACKEND_COMMAND_POLL_INTERVAL)
   {
      g_backendLastCommandPoll = now;
      BackendBridgePollCommands();
   }
}