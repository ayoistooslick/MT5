//+------------------------------------------------------------------+
//|                                                   TradeManager.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "Config.mqh"

CTrade Trade;

bool AreStopsValid(ENUM_ORDER_TYPE type, double sl, double tp, const MqlTick &tick);

bool IsTradeRetcodeSuccessful(uint retcode)
{
   return retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED ||
          retcode == TRADE_RETCODE_DONE_PARTIAL || retcode == TRADE_RETCODE_NO_CHANGES;
}

bool IsOpenRetcodeSuccessful(uint retcode)
{
   return retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED ||
          retcode == TRADE_RETCODE_DONE_PARTIAL;
}

double NormalizePriceToTickSize(const string symbol, const double price)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) return NormalizeDouble(price, digits);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
}

bool AreStopsValidForSymbol(const string symbol, ENUM_ORDER_TYPE type, double sl, double tp, const MqlTick &tick)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0 || sl <= 0 || tp <= 0) return false;

   long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDistance = (double)MathMax(stopsLevel, freezeLevel) * point;

   if(type == ORDER_TYPE_BUY)
      return sl < tick.bid && tp > tick.bid &&
             (minDistance == 0 || (tick.bid - sl >= minDistance && tp - tick.bid >= minDistance));

   if(type == ORDER_TYPE_SELL)
      return sl > tick.ask && tp < tick.ask &&
             (minDistance == 0 || (sl - tick.ask >= minDistance && tick.ask - tp >= minDistance));

   return false;
}

bool ModifyPositionStopsByTicket(ulong ticket, double newSL, const string operation)
{
   if(!PositionSelectByTicket(ticket))
   {
      Print(LOG_PREFIX, operation, " failed: position no longer exists (ticket ", ticket, ").");
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   ENUM_ORDER_TYPE orderType = (positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double currentTP = PositionGetDouble(POSITION_TP);
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
   {
      Print(LOG_PREFIX, operation, " failed: unable to read market data for ", symbol, " (ticket ", ticket, ").");
      return false;
   }

   double normalizedSL = NormalizePriceToTickSize(symbol, newSL);
   double normalizedTP = NormalizePriceToTickSize(symbol, currentTP);
   if(!AreStopsValidForSymbol(symbol, orderType, normalizedSL, normalizedTP, tick))
   {
      Print(LOG_PREFIX, operation, " rejected: invalid stops for ", symbol, " (ticket ", ticket,
            ", SL ", normalizedSL, ", TP ", normalizedTP, ").");
      return false;
   }

   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = symbol;
   request.magic = InpMagicNumber;
   request.sl = normalizedSL;
   request.tp = normalizedTP;

   ResetLastError();
   bool sent = OrderSend(request, result);
   if(!sent || !IsTradeRetcodeSuccessful(result.retcode))
   {
      Print(LOG_PREFIX, operation, " modification failed for ticket ", ticket,
            " (symbol ", symbol, "): retcode ", result.retcode,
            " - ", result.comment, ", error ", GetLastError());
      return false;
   }

   return true;
}

void SetMarketRequestFilling(const string symbol, MqlTradeRequest &request)
{
   ENUM_SYMBOL_TRADE_EXECUTION execution =
      (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
   if(execution != SYMBOL_TRADE_EXECUTION_MARKET && execution != SYMBOL_TRADE_EXECUTION_EXCHANGE)
      return;

   uint filling = (uint)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      request.type_filling = ORDER_FILLING_FOK;
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      request.type_filling = ORDER_FILLING_IOC;
   else
      request.type_filling = ORDER_FILLING_RETURN;
}

bool ClosePositionByTicket(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
   {
      Print(LOG_PREFIX, "Max holding time close failed: position no longer exists (ticket ", ticket, ").");
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double volume = PositionGetDouble(POSITION_VOLUME);
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) || volume <= 0)
   {
      Print(LOG_PREFIX, "Max holding time close failed: invalid market data or volume for ", symbol,
            " (ticket ", ticket, ").");
      return false;
   }

   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = symbol;
   request.magic = InpMagicNumber;
   request.volume = volume;
   request.type = (positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (positionType == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
   request.deviation = 10;
   SetMarketRequestFilling(symbol, request);

   ResetLastError();
   bool sent = OrderSend(request, result);
   if(!sent || !IsTradeRetcodeSuccessful(result.retcode))
   {
      Print(LOG_PREFIX, "Max holding time close failed for ticket ", ticket,
            " (symbol ", symbol, "): retcode ", result.retcode,
            " - ", result.comment, ", error ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Open a position                                                  |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE type, double lot, double sl, double tp, string comment)
{
   Trade.SetExpertMagicNumber(InpMagicNumber);

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   double price = (type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double normalizedLot = (lotStep > 0) ? MathFloor(lot / lotStep + 1e-9) * lotStep : 0;
   if(price <= 0 || lot < minLot || lot > maxLot || lotStep <= 0 ||
      MathAbs(normalizedLot - lot) > 1e-7 || !AreStopsValid(type, sl, tp, tick))
   {
      Print(LOG_PREFIX, "Trade rejected: invalid price, volume, SL or TP.");
      return false;
   }

   if(Trade.PositionOpen(_Symbol, type, lot, price, sl, tp, comment))
   {
      uint retcode = Trade.ResultRetcode();
      if(IsOpenRetcodeSuccessful(retcode))
      {
         Print(LOG_PREFIX, "Trade opened: ", comment, " Type: ", EnumToString(type), " Lot: ", lot, " SL: ", sl, " TP: ", tp);
         return true;
      }
   }

   Print(LOG_PREFIX, "Trade failed: ", comment, " Error: ", Trade.ResultRetcode(), " - ", Trade.ResultRetcodeDescription());
   return false;
}

//+------------------------------------------------------------------+
//| Validate broker stop and freeze distances                         |
//+------------------------------------------------------------------+
bool AreStopsValid(ENUM_ORDER_TYPE type, double sl, double tp, const MqlTick &tick)
{
   return AreStopsValidForSymbol(_Symbol, type, sl, tp, tick);
}

//+------------------------------------------------------------------+
//| Get the configured R:R for a position's source timeframe          |
//+------------------------------------------------------------------+
double GetPositionRR(const string comment)
{
   if(StringFind(comment, "M15") >= 0) return InpM15TPRR;
   if(StringFind(comment, "M5") >= 0) return InpM5TPRR;
   if(StringFind(comment, "M1") >= 0) return InpM1TPRR;
   return 0;
}

//+------------------------------------------------------------------+
//| Recover initial risk from the unchanged TP and opening price      |
//+------------------------------------------------------------------+
double GetInitialRisk()
{
   string comment = PositionGetString(POSITION_COMMENT);
   int riskMarker = StringFind(comment, "|R=");
   if(riskMarker >= 0)
   {
      double storedRisk = StringToDouble(StringSubstr(comment, riskMarker + 3));
      if(storedRisk > 0) return storedRisk;
   }

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp = PositionGetDouble(POSITION_TP);
   double rr = GetPositionRR(comment);
   if(openPrice <= 0 || tp <= 0 || rr <= 0) return 0;
   return MathAbs(tp - openPrice) / rr;
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
   if(!PositionSelectByTicket(ticket)) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double currentPrice = (type == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
   double sl = PositionGetDouble(POSITION_SL);

   double initialRisk = GetInitialRisk();
   if(initialRisk <= 0) return;

   double favorableMove = (type == POSITION_TYPE_BUY) ? currentPrice - openPrice : openPrice - currentPrice;
   double currentProfitRR = favorableMove / initialRisk;

   if(currentProfitRR >= InpBETriggerRR)
   {
      double newSL = (type == POSITION_TYPE_BUY) ? openPrice + InpBEOffsetPoints * _Point : openPrice - InpBEOffsetPoints * _Point;
      newSL = NormalizePriceToTickSize(_Symbol, newSL);

      // Only move if it's better than current SL
      if((type == POSITION_TYPE_BUY && newSL > sl) || (type == POSITION_TYPE_SELL && (newSL < sl || sl == 0)))
      {
         ModifyPositionStopsByTicket(ticket, newSL, "Break-even");
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop logic                                        |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket)
{
   if(!InpEnableTrailingStop) return;
   if(!PositionSelectByTicket(ticket)) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double currentPrice = (type == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
   double sl = PositionGetDouble(POSITION_SL);

   double initialRisk = GetInitialRisk();
   if(initialRisk <= 0) return;

   double favorableMove = (type == POSITION_TYPE_BUY) ? currentPrice - openPrice : openPrice - currentPrice;
   double currentProfitRR = favorableMove / initialRisk;

   if(currentProfitRR >= InpTrailingStartRR)
   {
      double newSL = (type == POSITION_TYPE_BUY) ? currentPrice - InpTrailingDistancePoints * _Point : currentPrice + InpTrailingDistancePoints * _Point;
      newSL = NormalizePriceToTickSize(_Symbol, newSL);

      // Only move if it's better than current SL
      if((type == POSITION_TYPE_BUY && newSL > sl) || (type == POSITION_TYPE_SELL && (newSL < sl || sl == 0)))
      {
         ModifyPositionStopsByTicket(ticket, newSL, "Trailing-stop");
      }
   }
}

//+------------------------------------------------------------------+
//| Check and enforce Maximum Holding Time                           |
//+------------------------------------------------------------------+
void CheckMaxHoldingTime(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   int elapsedMinutes = (int)(TimeCurrent() - openTime) / 60;

   string comment = PositionGetString(POSITION_COMMENT);
   int maxMinutes = 0;

   if(StringFind(comment, "M15") >= 0) maxMinutes = InpM15MaxHoldingTime;
   else if(StringFind(comment, "M5") >= 0) maxMinutes = InpM5MaxHoldingTime;
   else if(StringFind(comment, "M1") >= 0) maxMinutes = InpM1MaxHoldingTime;

   if(maxMinutes > 0 && elapsedMinutes >= maxMinutes)
   {
      if(ClosePositionByTicket(ticket))
         Print(LOG_PREFIX, "Position closed due to Max Holding Time: ", ticket);
   }
}
