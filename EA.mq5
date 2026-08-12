//+------------------------------------------------------------------+
//|                                                           EA.mq5 |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaTrader 5 EA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "Include/Config.mqh"
#include "Include/Indicators.mqh"
#include "Include/MarketStructure.mqh"
#include "Include/SignalScoring.mqh"
#include "Include/RiskManager.mqh"
#include "Include/TradeManager.mqh"
#include "Include/StrategyM1.mqh"
#include "Include/StrategyM5.mqh"
#include "Include/StrategyM15.mqh"
#include "Include/UI.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!InitIndicators()) return INIT_FAILED;
   
   GlobalTradingEnabled = InpEnableTrading;
   CreateTradeButton();
   
   Print(LOG_PREFIX, "EA Initialized successfully. Mode: ", EnumToString(InpTradingMode));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeinitIndicators();
   RemoveTradeButton();
   Print(LOG_PREFIX, "EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timeframe that drives entry evaluation                            |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES EntrySignalTimeframe()
{
   if(InpTradingMode == MODE_M5) return PERIOD_M5;
   if(InpTradingMode == MODE_M15) return PERIOD_M15;
   return PERIOD_M1; // M1 and AUTO both use the fastest closed signal bar.
}

bool IsNewAutoSignal(const string comment);

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Manage existing positions (Always running)
   ManagePositions();

   // 2. Safety checks for new entries
   if(!GlobalTradingEnabled || !InpEnableTrading) return;
   if(IsDailyLossLimitReached()) 
   {
      // We don't disable GlobalTradingEnabled here to allow it to reset next day, 
      // but we return early.
      static datetime lossLoggedDay = 0;
      datetime today = iTime(_Symbol, PERIOD_D1, 0);
      if(today != lossLoggedDay)
      {
         Print(LOG_PREFIX, "Daily loss limit reached. No new trades.");
         lossLoggedDay = today;
      }
      return; 
   }

   // 3. New bar detection for signal generation
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, EntrySignalTimeframe(), 0);
   if(currentBarTime <= 0) return;
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   // 4. Spread check
   MqlTick tick;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0 || !SymbolInfoTick(_Symbol, tick) || tick.ask < tick.bid) return;
   double spread = (tick.ask - tick.bid) / point;
   if(spread > InpMaxSpread)
   {
      Print(LOG_PREFIX, "Spread too high: ", spread, " > ", InpMaxSpread);
      return;
   }

   // 5. Evaluate strategy based on mode
   switch(InpTradingMode)
   {
      case MODE_M1:   ExecuteStrategy(MODE_M1); break;
      case MODE_M5:   ExecuteStrategy(MODE_M5); break;
      case MODE_M15:  ExecuteStrategy(MODE_M15); break;
      case MODE_AUTO: ExecuteAutoMode(); break;
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   OnChartEventUI(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Execute a single timeframe strategy                              |
//+------------------------------------------------------------------+
void ExecuteStrategy(ENUM_TRADING_MODE mode)
{
   SignalResult buySignal, sellSignal;
   double risk = 0, tpRR = 0;
   int maxDaily = 0;
   string comment = "";

   if(mode == MODE_M1)
   {
      buySignal = EvaluateM1(true);
      sellSignal = EvaluateM1(false);
      risk = InpM1RiskPercent;
      tpRR = InpM1TPRR;
      maxDaily = InpM1MaxTradesPerDay;
      comment = "M1_Signal";
   }
   else if(mode == MODE_M5)
   {
      buySignal = EvaluateM5(true);
      sellSignal = EvaluateM5(false);
      risk = InpM5RiskPercent;
      tpRR = InpM5TPRR;
      maxDaily = InpM5MaxTradesPerDay;
      comment = "M5_Signal";
   }
   else if(mode == MODE_M15)
   {
      buySignal = EvaluateM15(true);
      sellSignal = EvaluateM15(false);
      risk = InpM15RiskPercent;
      tpRR = InpM15TPRR;
      maxDaily = InpM15MaxTradesPerDay;
      comment = "M15_Signal";
   }

   if(AreTradeLimitsReached(maxDaily)) return;

   if(buySignal.isValid) ProcessSignal(ORDER_TYPE_BUY, buySignal, risk, tpRR, comment);
   else if(sellSignal.isValid) ProcessSignal(ORDER_TYPE_SELL, sellSignal, risk, tpRR, comment);
}

//+------------------------------------------------------------------+
//| Execute Multi-Timeframe Auto Mode                                |
//+------------------------------------------------------------------+
void ExecuteAutoMode()
{
   SignalResult m1Buy = EvaluateM1(true), m1Sell = EvaluateM1(false);
   SignalResult m5Buy = EvaluateM5(true), m5Sell = EvaluateM5(false);
   SignalResult m15Buy = EvaluateM15(true), m15Sell = EvaluateM15(false);

   SignalResult bestSignal;
   bestSignal.score = 0;
   ENUM_ORDER_TYPE bestType = (ENUM_ORDER_TYPE)-1;
   double risk = 0, tpRR = 0;
   string comment = "";
   int maxDaily = 0;

   // Select strongest signal
   if(m1Buy.isValid && m1Buy.score > bestSignal.score) { bestSignal = m1Buy; bestType = ORDER_TYPE_BUY; risk = InpM1RiskPercent; tpRR = InpM1TPRR; comment = "AUTO_M1"; maxDaily = InpM1MaxTradesPerDay; }
   if(m1Sell.isValid && m1Sell.score > bestSignal.score) { bestSignal = m1Sell; bestType = ORDER_TYPE_SELL; risk = InpM1RiskPercent; tpRR = InpM1TPRR; comment = "AUTO_M1"; maxDaily = InpM1MaxTradesPerDay; }
   
   if(m5Buy.isValid && m5Buy.score > bestSignal.score) { bestSignal = m5Buy; bestType = ORDER_TYPE_BUY; risk = InpM5RiskPercent; tpRR = InpM5TPRR; comment = "AUTO_M5"; maxDaily = InpM5MaxTradesPerDay; }
   if(m5Sell.isValid && m5Sell.score > bestSignal.score) { bestSignal = m5Sell; bestType = ORDER_TYPE_SELL; risk = InpM5RiskPercent; tpRR = InpM5TPRR; comment = "AUTO_M5"; maxDaily = InpM5MaxTradesPerDay; }
   
   if(m15Buy.isValid && m15Buy.score > bestSignal.score) { bestSignal = m15Buy; bestType = ORDER_TYPE_BUY; risk = InpM15RiskPercent; tpRR = InpM15TPRR; comment = "AUTO_M15"; maxDaily = InpM15MaxTradesPerDay; }
   if(m15Sell.isValid && m15Sell.score > bestSignal.score) { bestSignal = m15Sell; bestType = ORDER_TYPE_SELL; risk = InpM15RiskPercent; tpRR = InpM15TPRR; comment = "AUTO_M15"; maxDaily = InpM15MaxTradesPerDay; }

    if(bestType != -1 && !AreTradeLimitsReached(maxDaily) && IsNewAutoSignal(comment))
   {
      ProcessSignal(bestType, bestSignal, risk, tpRR, comment);
   }
}

//+------------------------------------------------------------------+
//| Prevent AUTO from re-entering the same higher-timeframe signal   |
//| on every subsequent M1 bar.                                     |
//+------------------------------------------------------------------+
bool IsNewAutoSignal(const string comment)
{
   ENUM_TIMEFRAMES signalTf = PERIOD_M1;
   if(StringFind(comment, "M15") >= 0) signalTf = PERIOD_M15;
   else if(StringFind(comment, "M5") >= 0) signalTf = PERIOD_M5;

   datetime signalBar = iTime(_Symbol, signalTf, 0);
   if(signalBar <= 0) return false;

   static datetime lastM1SignalBar = 0;
   static datetime lastM5SignalBar = 0;
   static datetime lastM15SignalBar = 0;

   if(signalTf == PERIOD_M1)
   {
      if(signalBar == lastM1SignalBar) return false;
      lastM1SignalBar = signalBar;
   }
   else if(signalTf == PERIOD_M5)
   {
      if(signalBar == lastM5SignalBar) return false;
      lastM5SignalBar = signalBar;
   }
   else
   {
      if(signalBar == lastM15SignalBar) return false;
      lastM15SignalBar = signalBar;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Common Signal Processing and Execution                           |
//+------------------------------------------------------------------+
void ProcessSignal(ENUM_ORDER_TYPE type, SignalResult &signal, double riskPercent, double tpRR, string comment)
{
   if(!signal.isValid || tpRR <= 0) return;

   MqlTick tick;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0 || !SymbolInfoTick(_Symbol, tick) || tick.ask < tick.bid) return;

   double spread = (tick.ask - tick.bid) / point;
   if(spread > InpMaxSpread)
   {
      Print(LOG_PREFIX, "Signal rejected: spread too high at execution time.");
      return;
   }

   // Calculate ATR for SL
   double atr = 0;
   if(StringFind(comment, "M15") >= 0) atr = GetIndicatorValue(hATR_M15, 1);
   else if(StringFind(comment, "M5") >= 0) atr = GetIndicatorValue(hATR_M5, 1);
   else if(StringFind(comment, "M1") >= 0) atr = GetIndicatorValue(hATR_M1, 1);

   if(atr <= 0) return;

   // Build both SL and TP from the same current entry price.  The
   // position size is then based on this actual initial SL distance.
   double entry = (type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   double sl = (type == ORDER_TYPE_BUY) ? entry - atr * 2.0 : entry + atr * 2.0;
   entry = NormalizeDouble(entry, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   double initialRisk = MathAbs(entry - sl);
   if(initialRisk <= 0) return;

   double tp = (type == ORDER_TYPE_BUY) ? entry + initialRisk * tpRR : entry - initialRisk * tpRR;
   tp = NormalizeDouble(tp, _Digits);
   if(!AreStopsValid(type, sl, tp, tick))
   {
      Print(LOG_PREFIX, "Signal rejected: SL/TP violates broker stop or freeze levels.");
      return;
   }

   double slPoints = initialRisk / point;
   double lot = CalculateLotSize(riskPercent, slPoints);
   
   if(lot > 0 && IsMarginSufficient(lot, type))
   {
      string tradeComment = comment + "|R=" + DoubleToString(initialRisk, _Digits);
      OpenPosition(type, lot, sl, tp, tradeComment);
   }
   else
   {
      Print(LOG_PREFIX, "Signal rejected: Lot sizing or Margin failure. Lot: ", lot);
   }
}
