//+------------------------------------------------------------------+
//|                                        EA_Supertrend_PSAR_H1.mq5 |
//|                                           Protocolo de la Verdad |
//+------------------------------------------------------------------+
#property copyright "Protocolo de la Verdad"
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Parámetros de Gestión de Lotaje
input double InpLotBase  = 0.01;          // Lotaje PSAR (Contra Supertrend)
input double InpLotAlign = 0.02;          // Lotaje PSAR + Supertrend (Alineados)
input ulong  InpMagicNumber = 123456;     // Identificador Mágico

//--- Parámetros del Indicador (Debe coincidir con Supertrend_PSAR_Combined.mq5)
input string Grp1 = "=== SUPERTREND ===";
input int    InpAtrLength = 2;      
input double InpAtrFactor = 10.0;     
input string Grp2 = "=== PSAR ===";
input double InpPsarStep = 0.1;       
input double InpPsarMax = 0.19;       

CTrade trade;
int ind_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Inicialización estricta en temporalidad de 1 Hora (H1)
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
   // Restricción de ejecución: Procesar solo al cierre de la vela H1
   static datetime time_prev = 0;
   datetime time_curr = iTime(_Symbol, PERIOD_H1, 0);
   if(time_curr == time_prev) return;
   
   double buy_sig[], sell_sig[];
   double st_up[], st_dn[];
   
   // Extracción de datos de la vela 1 (vela anterior cerrada)
   if(CopyBuffer(ind_handle, 3, 1, 1, buy_sig) <= 0) return;  // Señal PSAR Buy
   if(CopyBuffer(ind_handle, 4, 1, 1, sell_sig) <= 0) return; // Señal PSAR Sell
   if(CopyBuffer(ind_handle, 0, 1, 1, st_up) <= 0) return;    // Línea Supertrend alcista
   if(CopyBuffer(ind_handle, 1, 1, 1, st_dn) <= 0) return;    // Línea Supertrend Bajista

   bool isPsarBuy  = (buy_sig[0] > 0.0);
   bool isPsarSell = (sell_sig[0] > 0.0);

   // Lógica de Entrada, Salida y Lotaje Dinámico
   if(isPsarBuy)
     {
      // 1. Cierre y Reverso: Cerrar cualquier posición previa
      if(PositionsTotal() > 0) CloseAll();
      
      // 2. Filtro de Lotaje: ¿Está el Supertrend alineado (Alcista)?
      double lotToOpen = (st_up[0] > 0.0) ? InpLotAlign : InpLotBase;
      
      // 3. Ejecución
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(lotToOpen, _Symbol, ask, 0, 0, "PSAR Reversal Buy");
      time_prev = time_curr;
     }
   else if(isPsarSell)
     {
      // 1. Cierre y Reverso: Cerrar cualquier posición previa
      if(PositionsTotal() > 0) CloseAll();
      
      // 2. Filtro de Lotaje: ¿Está el Supertrend alineado (Bajista)?
      double lotToOpen = (st_dn[0] > 0.0) ? InpLotAlign : InpLotBase;
      
      // 3. Ejecución
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(lotToOpen, _Symbol, bid, 0, 0, "PSAR Reversal Sell");
      time_prev = time_curr;
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