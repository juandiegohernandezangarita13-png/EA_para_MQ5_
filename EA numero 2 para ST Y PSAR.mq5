//+------------------------------------------------------------------+
//|                                        EA_Supertrend_PSAR_H1.mq5 |
//|                                           Protocolo de la Verdad |
//+------------------------------------------------------------------+
#property copyright "Protocolo de la Verdad"
#property version   "2.10"

#include <Trade\Trade.mqh>

//--- Parámetros de Gestión de Lotaje
input double InpLotBase     = 0.01;      // Lotaje PSAR (Contra Supertrend)
input double InpLotAlign    = 0.02;      // Lotaje PSAR + Supertrend (Alineados)
input ulong  InpMagicNumber = 123456;    // Identificador Mágico

//--- Parámetros del Indicador
input string Grp1         = "=== SUPERTREND ===";
input int    InpAtrLength = 2;      
input double InpAtrFactor = 10.0;     
input string Grp2         = "=== PSAR ===";
input double InpPsarStep  = 0.1;       
input double InpPsarMax   = 0.19;       

CTrade trade;
int ind_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   ind_handle = iCustom(_Symbol, PERIOD_M5, "Supertrend_PSAR_Combined", 
                        Grp1, InpAtrLength, InpAtrFactor, 
                        Grp2, InpPsarStep, InpPsarMax);
                        
   if(ind_handle == INVALID_HANDLE)
     {
      Print("Error crítico: Fallo al cargar el indicador Supertrend_PSAR_Combined.");
      return(INIT_FAILED);
     }
     
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(ind_handle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // ================================================================
   // 1. REGLA DE SALIDA INMEDIATA (Ejecución continua en cada tick)
   // ================================================================
   CheckPsarTouchExit();

   // ================================================================
   // 2. REGLA DE ENTRADA (Solo al cierre/apertura de la vela H1)
   // ================================================================
   static datetime time_prev = 0;
   datetime time_curr = iTime(_Symbol, PERIOD_H1, 0);
   if(time_curr == time_prev) return; // Si la vela no ha cambiado, no evalúa aperturas
   time_prev = time_curr;             // Registro del nuevo ciclo H1

   double buy_sig[], sell_sig[];
   double st_up[], st_dn[];
   
   // Extracción de señales de la vela 1 (confirmada)
   if(CopyBuffer(ind_handle, 3, 1, 1, buy_sig) <= 0) return;  // Señal PSAR Buy
   if(CopyBuffer(ind_handle, 4, 1, 1, sell_sig) <= 0) return; // Señal PSAR Sell
   if(CopyBuffer(ind_handle, 0, 1, 1, st_up) <= 0) return;    // Supertrend alcista
   if(CopyBuffer(ind_handle, 1, 1, 1, st_dn) <= 0) return;    // Supertrend bajista

   bool isPsarBuy  = (buy_sig[0] > 0.0);
   bool isPsarSell = (sell_sig[0] > 0.0);

   if(isPsarBuy)
     {
      if(PositionsTotal() > 0) CloseAll();
      double lotToOpen = (st_up[0] > 0.0) ? InpLotAlign : InpLotBase;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(lotToOpen, _Symbol, ask, 0, 0, "PSAR Reversal Buy");
     }
   else if(isPsarSell)
     {
      if(PositionsTotal() > 0) CloseAll();
      double lotToOpen = (st_dn[0] > 0.0) ? InpLotAlign : InpLotBase;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(lotToOpen, _Symbol, bid, 0, 0, "PSAR Reversal Sell");
     }
  }

//+------------------------------------------------------------------+
//| Cierre instantáneo si el precio toca el PSAR actual              |
//+------------------------------------------------------------------+
void CheckPsarTouchExit()
  {
   if(PositionsTotal() == 0) return;

   // Extraer el PSAR de la vela en curso (Vela 0, Buffer 2)
   double psar_curr[];
   if(CopyBuffer(ind_handle, 2, 0, 1, psar_curr) <= 0) return;
   double psar_level = psar_curr[0];

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         long type = PositionGetInteger(POSITION_TYPE);

         // Compra: El PSAR está por debajo. Si el Bid toca o cae bajo el PSAR -> Cierre
         if(type == POSITION_TYPE_BUY && bid <= psar_level)
           {
            trade.PositionClose(ticket);
           }
         // Venta: El PSAR está por encima. Si el Ask toca o sube sobre el PSAR -> Cierre
         else if(type == POSITION_TYPE_SELL && ask >= psar_level)
           {
            trade.PositionClose(ticket);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Cierre de todas las posiciones abiertas por el EA                |
//+------------------------------------------------------------------+
void CloseAll()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         trade.PositionClose(ticket);
        }
     }
  }