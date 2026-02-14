#property strict
#include <Trade/Trade.mqh>

CTrade trade;

input string GoldSymbol = "XAUUSDm";
input string BtcSymbol  = "BTCUSDm";

input double RiskPercent = 1.0;
input int MaxTradesPerSymbol = 2;

input int FastEMA = 20;
input int SlowEMA = 50;
input int RSIPeriod = 14;

input int ATRPeriod = 14;
input double SL_ATR = 1.5;
input double TP_ATR = 2.5;

int MagicGold = 20241;
int MagicBTC  = 20242;

double LotByRisk(string sym,double sl_points)
{
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double risk=balance*(RiskPercent/100.0);

   double tickval=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
   double ticksize=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   double point=SymbolInfoDouble(sym,SYMBOL_POINT);

   double valuePerPoint=tickval*(point/ticksize);
   if(valuePerPoint<=0) return 0;

   double lots=risk/(sl_points*valuePerPoint);

   double minlot=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);

   lots=MathMax(minlot,lots);
   lots=MathFloor(lots/step)*step;

   return lots;
}

double EMA(string sym,ENUM_TIMEFRAMES tf,int period)
{
   int h=iMA(sym,tf,period,0,MODE_EMA,PRICE_CLOSE);
   double buf[];
   if(CopyBuffer(h,0,0,1,buf)<1){ IndicatorRelease(h); return 0; }
   IndicatorRelease(h);
   return buf[0];
}

double RSI(string sym,ENUM_TIMEFRAMES tf,int p)
{
   int h=iRSI(sym,tf,p,PRICE_CLOSE);
   double buf[];
   if(CopyBuffer(h,0,0,1,buf)<1){ IndicatorRelease(h); return 50; }
   IndicatorRelease(h);
   return buf[0];
}

double ATR(string sym,ENUM_TIMEFRAMES tf,int p)
{
   int h=iATR(sym,tf,p);
   double buf[];
   if(CopyBuffer(h,0,0,1,buf)<1){ IndicatorRelease(h); return 0; }
   IndicatorRelease(h);
   return buf[0];
}

int CountPos(string sym,int magic)
{
   int c=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionSelectByIndex(i))
      {
         if(PositionGetString(POSITION_SYMBOL)==sym &&
            (int)PositionGetInteger(POSITION_MAGIC)==magic) c++;
      }
   }
   return c;
}

void TradeSymbol(string sym,int magic)
{
   if(CountPos(sym,magic)>=MaxTradesPerSymbol) return;

   double emaFast=EMA(sym,PERIOD_M5,FastEMA);
   double emaSlow=EMA(sym,PERIOD_M5,SlowEMA);
   double rsi=RSI(sym,PERIOD_M5,RSIPeriod);

   double atr=ATR(sym,PERIOD_M5,ATRPeriod);
   if(atr<=0) return;

   double point=SymbolInfoDouble(sym,SYMBOL_POINT);
   if(point<=0) return;

   double sl_points=(atr*SL_ATR)/point;
   double lot=LotByRisk(sym,sl_points);
   if(lot<=0) return;

   double ask=SymbolInfoDouble(sym,SYMBOL_ASK);
   double bid=SymbolInfoDouble(sym,SYMBOL_BID);

   if(emaFast>emaSlow && rsi>55)
   {
      trade.SetExpertMagicNumber(magic);
      trade.Buy(lot,sym,ask,bid-atr*SL_ATR,ask+atr*TP_ATR);
   }
   else if(emaFast<emaSlow && rsi<45)
   {
      trade.SetExpertMagicNumber(magic);
      trade.Sell(lot,sym,bid,ask+atr*SL_ATR,bid-atr*TP_ATR);
   }
}

void OnTick()
{
   TradeSymbol(GoldSymbol,MagicGold);
   TradeSymbol(BtcSymbol,MagicBTC);
}
EOFhab