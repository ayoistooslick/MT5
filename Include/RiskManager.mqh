//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percent and SL distance        |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double slPoints)
{
   if(slPoints <= 0) return 0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (riskPercent / 100.0);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickValue == 0 || tickSize == 0 || point == 0) return 0;

   // Standard MQL5 formula for lot size based on risk
   // riskMoney = lot * (slPoints * point) * (tickValue / tickSize)
   double lotSize = riskMoney / (slPoints * point * (tickValue / tickSize));
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;

   if(lotSize < minLot) return 0; 
   if(lotSize > maxLot) lotSize = maxLot;

   return lotSize;
}

//+------------------------------------------------------------------+
//| Check if daily loss limit is reached                             |
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached()
{
   if(!InpEnableDailyLossLimit) return false;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profitToday = 0;
   
   // Calculate today's profit from history
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today > 0 && HistorySelect(today, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
         {
            profitToday += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            profitToday += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            profitToday += HistoryDealGetDouble(ticket, DEAL_SWAP);
         }
      }
   }

   // Include current floating profit (Filtered by Magic Number)
   double floatingProfit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            floatingProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }

   double totalProfitToday = profitToday + floatingProfit;
   double maxLossMoney = balance * (InpMaxDailyLossPercent / 100.0);
   
   if(totalProfitToday < -maxLossMoney)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if trade limits are reached                                |
//+------------------------------------------------------------------+
bool AreTradeLimitsReached(int maxDailyTrades)
{
   // 1. Max simultaneous positions
   int currentPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            currentPositions++;
            if(InpOnePositionPerSymbol && PositionGetString(POSITION_SYMBOL) == _Symbol)
               return true;
         }
      }
   }

   if(currentPositions >= InpMaxSimultaneousPositions) return true;

   // 2. Max daily trades
   int tradesToday = 0;
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(HistorySelect(today, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber && 
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            tradesToday++;
         }
      }
   }

   if(tradesToday >= maxDailyTrades) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check if margin is sufficient                                    |
//+------------------------------------------------------------------+
bool IsMarginSufficient(double lot, ENUM_ORDER_TYPE type)
{
   double margin;
   if(!OrderCalcMargin(type, _Symbol, lot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin))
      return false;
   
   return margin < AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}
