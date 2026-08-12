//+------------------------------------------------------------------+
//|                                                   TradeManager.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "Config.mqh"

CTrade Trade;

//+------------------------------------------------------------------+
//| Open a position                                                  |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE type, double lot, double sl, double tp, string comment)
{
   Trade.SetExpertMagicNumber(InpMagicNumber);
   
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(Trade.PositionOpen(_Symbol, type, lot, price, sl, tp, comment))
   {
      Print(LOG_PREFIX, "Trade opened: ", comment, " Type: ", EnumToString(type), " Lot: ", lot, " SL: ", sl, " TP: ", tp);
      return true;
   }
   else
   {
      Print(LOG_PREFIX, "Trade failed: ", comment, " Error: ", Trade.ResultRetcode(), " - ", Trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Manage active positions (Break-even, Trailing, Max Holding Time) |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ApplyBreakEven(ticket);
            ApplyTrailingStop(ticket);
            CheckMaxHoldingTime(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Break-Even logic                                           |
//+------------------------------------------------------------------+
void ApplyBreakEven(ulong ticket)
{
   if(!InpEnableBreakEven) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double pipsToTP = MathAbs(tp - openPrice);
   if(pipsToTP == 0) return;

   double currentProfitRR = MathAbs(currentPrice - openPrice) / pipsToTP;

   if(currentProfitRR >= InpBETriggerRR)
   {
      double newSL = (type == POSITION_TYPE_BUY) ? openPrice + InpBEOffsetPoints * _Point : openPrice - InpBEOffsetPoints * _Point;
      
      // Only move if it's better than current SL
      if((type == POSITION_TYPE_BUY && newSL > sl) || (type == POSITION_TYPE_SELL && (newSL < sl || sl == 0)))
      {
         Trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop logic                                        |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket)
{
   if(!InpEnableTrailingStop) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double pipsToTP = MathAbs(tp - openPrice);
   if(pipsToTP == 0) return;

   double currentProfitRR = MathAbs(currentPrice - openPrice) / pipsToTP;

   if(currentProfitRR >= InpTrailingStartRR)
   {
      double newSL = (type == POSITION_TYPE_BUY) ? currentPrice - InpTrailingDistancePoints * _Point : currentPrice + InpTrailingDistancePoints * _Point;
      
      // Only move if it's better than current SL
      if((type == POSITION_TYPE_BUY && newSL > sl) || (type == POSITION_TYPE_SELL && (newSL < sl || sl == 0)))
      {
         Trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Check and enforce Maximum Holding Time                           |
//+------------------------------------------------------------------+
void CheckMaxHoldingTime(ulong ticket)
{
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   int elapsedMinutes = (int)(TimeCurrent() - openTime) / 60;
   
   string comment = PositionGetString(POSITION_COMMENT);
   int maxMinutes = 0;
   
   if(StringFind(comment, "M1") >= 0) maxMinutes = InpM1MaxHoldingTime;
   else if(StringFind(comment, "M5") >= 0) maxMinutes = InpM5MaxHoldingTime;
   else if(StringFind(comment, "M15") >= 0) maxMinutes = InpM15MaxHoldingTime;
   
   if(maxMinutes > 0 && elapsedMinutes >= maxMinutes)
   {
      Trade.PositionClose(ticket);
      Print(LOG_PREFIX, "Position closed due to Max Holding Time: ", ticket);
   }
}
