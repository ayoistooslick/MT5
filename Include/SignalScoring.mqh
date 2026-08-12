//+------------------------------------------------------------------+
//|                                              SignalScoring.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"

struct SignalResult
{
   int score;
   bool criticalPassed;
   bool isValid;
   string reason;
};

//+------------------------------------------------------------------+
//| Calculate Signal Score for a given timeframe and direction      |
//+------------------------------------------------------------------+
SignalResult CalculateScore(ENUM_TIMEFRAMES tf, bool bullish, double ema_short, double ema_medium, double ema_trend, double rsi, double atr, bool structure, bool pullback, bool confirmation)
{
   SignalResult result;
   result.score = 0;
   result.criticalPassed = false;
   result.isValid = false;
   result.reason = "";

   // Critical Conditions (Must pass to even consider the score)
   bool ema_trend_ok = bullish ? (iClose(_Symbol, tf, 1) > ema_trend) : (iClose(_Symbol, tf, 1) < ema_trend);
   bool ema_cross_ok = bullish ? (ema_short > ema_medium) : (ema_short < ema_medium);
   
   if(!ema_trend_ok) { result.reason = "Trend EMA failure"; return result; }
   if(!ema_cross_ok) { result.reason = "EMA Cross failure"; return result; }
   if(!structure) { result.reason = "Market Structure failure"; return result; }
   if(!confirmation) { result.reason = "Confirmation candle failure"; return result; }

   result.criticalPassed = true;

   // Scoring Logic (Weighted)
   int score = 40; // Base score for passing criticals

   // Trend Alignment (20 points)
   // We'll check this against higher timeframes in the strategy engines, 
   // but for the scoring engine itself, we can reward strong local trend.
   score += 20;

   // RSI Confirmation (15 points)
   if(bullish && rsi > 50) score += 15;
   else if(!bullish && rsi < 50) score += 15;

   // Pullback Quality (15 points)
   if(pullback) score += 15;

   // Volatility Reward (10 points)
   if(atr > 0) score += 10;

   result.score = score;
   result.isValid = true;
   
   return result;
}
