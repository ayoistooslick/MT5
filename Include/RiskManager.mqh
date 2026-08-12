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
   if(riskPercent <= 0 || slPoints <= 0) return 0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * (riskPercent / 100.0);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(riskMoney <= 0 || tickValue <= 0 || tickSize <= 0 || point <= 0 ||
      minLot <= 0 || maxLot < minLot || lotStep <= 0) return 0;

   // Standard MQL5 formula for lot size based on risk
   // riskMoney = lot * (slPoints * point) * (tickValue / tickSize)
   double lotSize = riskMoney / (slPoints * point * (tickValue / tickSize));
   
   // Normalize down so the requested risk is never exceeded.
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathFloor(lotSize / lotStep + 1e-9) * lotStep;
   lotSize = NormalizeDouble(lotSize, 8);

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
            profitToday += HistoryDealGetDouble(ticket, DEAL_FEE);
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
   double maxLossMoney = 0;
   double percentLimit = AccountInfoDouble(ACCOUNT_BALANCE) * (InpMaxDailyLossPercent / 100.0);
   if(percentLimit > 0) maxLossMoney = percentLimit;
   if(InpMaxDailyLossMoney > 0 && (maxLossMoney == 0 || InpMaxDailyLossMoney < maxLossMoney))
      maxLossMoney = InpMaxDailyLossMoney;
   
   if(maxLossMoney > 0 && totalProfitToday <= -maxLossMoney)
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
   if(today > 0 && HistorySelect(today, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
          long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
          if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
             (entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT))
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
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   double price = (type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   if(price <= 0 || !OrderCalcMargin(type, _Symbol, lot, price, margin))
      return false;
   
   return margin > 0 && margin < AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}
