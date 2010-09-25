// Order types
#define OP_BUY 0
#define OP_SELL 1
#define OP_BUYLIMIT 2
#define OP_SELLLIMIT 3
#define OP_BUYSTOP 4
#define OP_SELLSTOP 5

// Orders pool
#define MODE_TRADES 0
#define MODE_HISTORY 1

// Selecting method
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1

/**
 * Struct that represent an order
 */
struct Order {
   double closePrice;
   datetime closeTime;
   string comment;
   double commission;
   datetime expiration;
   double lots;
   int magicNumber;
   double openPrice;
   datetime openTime;
   double profit;
   double stopLoss;
   double swap;
   string symbol;
   double takeProfit;
   ulong ticket;
   int type;
};

/**
 * Main class for the Virtual Position Manager for MQL5
 */
class VPM5 {

   private:

   // The session file & id
   int _sessionFile;
   int _sessionId;

   int _selectedPool;
   int _selectedOrder;

   // Flag that indicates if history is used
   bool _historyUsed;
   
   // Opened and pending orders
   Order _tradingPool[];
   
   // Closed and cancelled orders
   Order _historyPool[];
   
   int _limitedTicket;

   public:

   void VPM5() {
      _selectedOrder = (-1);

      _limitedTicket = -1000000;
   }

   void ~VPM5() {
   }

   /**
    * Load session information from disk.
    *
    * @param sessionId The session id.
    * @param historyUsed Indicates if the EA will use the history pool or not.
    */
   void init(int sessionId, bool historyUsed = false, bool debug = false) {
      _sessionId = sessionId;
      _historyUsed = historyUsed;

      _sessionFile = FileOpen("SESSION_" + IntegerToString(_sessionId) + ".dat", FILE_READ | FILE_CSV, ';');
      if (_sessionFile != INVALID_HANDLE) {

         // Cargar sesión
      
         FileClose(_sessionFile);         
      }
   }

   /**
    * Refreshes the opened operations and pending orders.
    */
   void refreshTradingPool() {
      for (int i = ArraySize(_tradingPool) - 1; i >= 0; i--) {
         double bid = SymbolInfoDouble(_tradingPool[i].symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_tradingPool[i].symbol, SYMBOL_ASK);

         if (_tradingPool[i].type == OP_BUYLIMIT && ask <= _tradingPool[i].openPrice) {
            if (orderSend(_tradingPool[i].symbol, OP_BUY, _tradingPool[i].lots, ask, 30, _tradingPool[i].stopLoss, _tradingPool[i].takeProfit, _tradingPool[i].comment, _tradingPool[i].magicNumber, _tradingPool[i].expiration) != (-1)) {
               orderDelete(_tradingPool[i].ticket);
            }
         }
         else if (_tradingPool[i].type == OP_SELLLIMIT && bid >= _tradingPool[i].openPrice) {
            if (orderSend(_tradingPool[i].symbol, OP_SELL, _tradingPool[i].lots, bid, 30, _tradingPool[i].stopLoss, _tradingPool[i].takeProfit, _tradingPool[i].comment, _tradingPool[i].magicNumber, _tradingPool[i].expiration) != (-1)) {
               orderDelete(_tradingPool[i].ticket);
            }
         }
      }

      for (int i = ArraySize(_tradingPool) - 1; i >= 0; i--) {
         if (_tradingPool[i].type == OP_BUY || _tradingPool[i].type == OP_SELL) {
            double bid = SymbolInfoDouble(_tradingPool[i].symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_tradingPool[i].symbol, SYMBOL_ASK);

            _tradingPool[i].closePrice = (_tradingPool[i].type == OP_BUY ? bid : ask);
            _tradingPool[i].profit = _tradingPool[i].lots * (_tradingPool[i].closePrice - _tradingPool[i].openPrice) / SymbolInfoDouble(_tradingPool[i].symbol, SYMBOL_POINT) * SymbolInfoDouble(_tradingPool[i].symbol, SYMBOL_TRADE_TICK_VALUE);
            if (_tradingPool[i].type == OP_SELL)
               _tradingPool[i].profit *= (-1);

            PositionSelect(_tradingPool[i].symbol);
            _tradingPool[i].commission = _tradingPool[i].lots * PositionGetDouble(POSITION_COMMISSION) / PositionGetDouble(POSITION_VOLUME); 
            _tradingPool[i].swap = _tradingPool[i].lots * PositionGetDouble(POSITION_SWAP) / PositionGetDouble(POSITION_VOLUME);
            if (_tradingPool[i].type == OP_BUY && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL
                  || _tradingPool[i].type == OP_SELL && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               _tradingPool[i].swap *= (-1);

            if (_tradingPool[i].type == OP_BUY 
                  && (_tradingPool[i].takeProfit > 0.001 && bid >= _tradingPool[i].takeProfit
                  || _tradingPool[i].stopLoss > 0.001 && bid <= _tradingPool[i].stopLoss)
                  || _tradingPool[i].type == OP_SELL 
                  && (_tradingPool[i].takeProfit > 0.001 && ask <= _tradingPool[i].takeProfit
                  || _tradingPool[i].stopLoss > 0.001 && ask >= _tradingPool[i].stopLoss)) {
               orderClose(_tradingPool[i].ticket, _tradingPool[i].lots, _tradingPool[i].closePrice, 1000);      
            }
         }
      }
   }

   //+--------------------+
   //| ordersHistoryTotal |
   //| ordersTotal        |
   //+--------------------+

   /**
    * Returns the closed orders and deleted orders count. 
    */
   int ordersHistoryTotal() {
      return ArraySize(_historyPool);
   }

   /**
    * Returns the market orders and pending orders count.
    */
   int ordersTotal() {
      return ArraySize(_tradingPool);
   }

   //+------------------+
   //| orderClosePrice  |
   //| orderCloseTime   |
   //| orderComment     |
   //| orderCommission  |
   //| orderExpiration  |
   //| orderLots        |
   //| orderMagicNumber |
   //| orderOpenPrice   |
   //| orderOpenTime    |
   //| orderProfit      |
   //| orderStopLoss    |
   //| orderSwap        |
   //| orderSymbol      |
   //| orderTakeProfit  |
   //| orderTicket      |
   //| orderType        |
   //+------------------+

   /**
    * Returns close price for the currently selected order.
    */
   double orderClosePrice() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].closePrice;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].closePrice;
      }
      return 0.0;
   } 
   
   /**
    * Returns close time for the currently selected order. 
    * If order close time is not 0 then the order selected has been closed and retrieved from the account history. 
    * Opened and pending orders close time is equal to 0.
    */
   datetime orderCloseTime() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].closeTime;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].closeTime;
      }
      return 0;
   }

   /**
    * Returns comment for the selected order.
    */
   string orderComment() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].comment;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].comment;
      }
      return "";
   }

   /**
    * Returns calculated commission for the currently selected order.
    */
   double orderCommission() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].commission;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].commission;
      }
      return 0.0;
   }

   /**
    * Returns expiration date for the selected pending order.
    */
   datetime orderExpiration() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].expiration;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].expiration;
      }
      return 0;
   }

   /**
    * Returns amount of lots for the selected order.
    */
   double orderLots() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].lots;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].lots;
      }
      return 0.0;
   }

   /**
    * Returns an identifying (magic) number for the currently selected order.
    */
   int orderMagicNumber() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].magicNumber;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].magicNumber;
      }
      return 0;
   }

   /**
    * Returns open price for the currently selected order.
    */
   double orderOpenPrice() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].openPrice;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].openPrice;
      }
      return 0.0;
   }

   /**
    * Returns open time for the currently selected order.
    */
   datetime orderOpenTime() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].openTime;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].openTime;
      }
      return 0;
   }

   /**
    * Returns the net profit value (without swaps or commissions) for the selected order. 
    */
   double orderProfit() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].profit;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].profit;
      }
      return 0.0;
   }

   /**
    * Returns the selected order stop loss.
    */
   double orderStopLoss() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].stopLoss;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].stopLoss;
      }
      return 0.0;
   }

   /**
    * Returns the selected order swap.
    */
   double orderSwap() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].swap;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].swap;
      }
      return 0.0;
   }

   /**
    * Returns the selected order symbol.
    */
   string orderSymbol() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].symbol;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].symbol;
      }
      return "";
   }

   /**
    * Returns the selected order take profit.
    */
   double orderTakeProfit() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].takeProfit;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].takeProfit;
      }
      return 0.0;
   }

   /**
    * Returns the selected order ticket.
    */
   ulong orderTicket() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].ticket;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].ticket;
      }
      return 0;
   }

   /**
    * Returns the selected order type.
    */
   int orderType() {
      if (_selectedOrder != (-1)) {
         if (_selectedPool == MODE_TRADES)
            return _tradingPool[_selectedOrder].type;
         else if (_selectedPool == MODE_HISTORY)
            return _historyPool[_selectedOrder].type;
      }
      return 0;
   }

   //+-------------+
   //| orderClose  |
   //| orderDelete |
   //| orderModify |
   //| orderSelect |
   //| orderSend   |
   //+-------------+

   /**
    * Closes an opened order. 
    * If the function succeeds, the return value is true. 
    * If the function fails, the return value is false. 
    *
    * @param ticket The order ticket. 
    * @param lots The number of lots. 
    * @param price The preferred closing price. 
    * @param slippage The maximum price slippage in points. 
    */
   bool orderClose(ulong ticket, double lots, double price, int slippage) {
      for (int i = 0; i < ArraySize(_tradingPool); i++) {
         if (_tradingPool[i].ticket == ticket && (_tradingPool[i].type == OP_BUY || _tradingPool[i].type == OP_SELL)) {

            MqlTradeCheckResult checkResult;
         
            MqlTradeRequest request;
            request.action = TRADE_ACTION_DEAL;
            request.type = (_tradingPool[i].type == OP_SELL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
            request.symbol = _tradingPool[i].symbol;
            request.volume = NormalizeDouble(lots, 2);
            request.price = price;
            request.sl = 0;
            request.tp = 0;
            request.deviation = slippage;
            request.magic = 0;
            request.comment = "";
            request.type_filling = ORDER_FILLING_AON;
            request.type_time = ORDER_TIME_GTC;

            MqlTradeResult result;

            if (OrderCheck(request, checkResult) && OrderSend(request, result)) {
               if (result.retcode == TRADE_RETCODE_DONE) {
                  // if (result.volume < _tradingPool[i].lots) se convierte a ... por el tema de la coma flotante
                  if (_tradingPool[i].lots - result.volume > 0.009) {

                     
                     if (_historyUsed) {
   
                        // Copy operation to history pool
                        int j = ArraySize(_historyPool) + 1;
                        ArrayResize(_historyPool, j);
   
                        int k = 0;
   
                        // Search position to insert in an ordered fashion ;-)
                        for (k = 0; k < j - 1; k++) {
                           if (_historyPool[k].openTime >= _tradingPool[i].openTime)
                              break;
                        }
   
                        for (int l = j - 1; l > k; l--) {
                           _historyPool[l].closePrice = _historyPool[l - 1].closePrice;
                           _historyPool[l].closeTime = _historyPool[l - 1].closeTime;
                           _historyPool[l].comment = _historyPool[l - 1].comment;
                           _historyPool[l].commission = _historyPool[l - 1].commission;
                           _historyPool[l].expiration = _historyPool[l - 1].expiration;
                           _historyPool[l].lots = _historyPool[l - 1].lots;
                           _historyPool[l].magicNumber = _historyPool[l - 1].magicNumber;
                           _historyPool[l].openPrice = _historyPool[l - 1].openPrice;
                           _historyPool[l].openTime = _historyPool[l - 1].openTime;
                           _historyPool[l].profit = _historyPool[l - 1].profit;
                           _historyPool[l].stopLoss = _historyPool[l - 1].stopLoss;
                           _historyPool[l].swap = _historyPool[l - 1].swap;
                           _historyPool[l].symbol = _historyPool[l - 1].symbol;
                           _historyPool[l].takeProfit = _historyPool[l - 1].takeProfit;
                           _historyPool[l].ticket = _historyPool[l - 1].ticket;
                           _historyPool[l].type = _historyPool[l - 1].type;
                        }
   
                        _historyPool[k].closePrice = _tradingPool[i].closePrice;
                        _historyPool[k].closeTime = _tradingPool[i].closeTime;
                        _historyPool[k].comment = _tradingPool[i].comment;
                        _historyPool[k].commission = _tradingPool[i].commission;
                        _historyPool[k].expiration = _tradingPool[i].expiration;
                        _historyPool[k].lots = result.volume;
                        _historyPool[k].magicNumber = _tradingPool[i].magicNumber;
                        _historyPool[k].openPrice = _tradingPool[i].openPrice;
                        _historyPool[k].openTime = _tradingPool[i].openTime;
                        _historyPool[k].profit = _tradingPool[i].profit;
                        _historyPool[k].stopLoss = _tradingPool[i].stopLoss;
                        _historyPool[k].swap = _tradingPool[i].swap;
                        _historyPool[k].symbol = _tradingPool[i].symbol;
                        _historyPool[k].takeProfit = _tradingPool[i].takeProfit;
                        _historyPool[k].ticket = _tradingPool[i].ticket;
                        _historyPool[k].type = _tradingPool[i].type;
                     }
                     
                     _tradingPool[i].lots -= result.volume;

                     refreshTradingPool();
                  }
                  else {

                     if (_historyUsed) {
                        // Copy operation to history pool
                        int j = ArraySize(_historyPool) + 1;
                        ArrayResize(_historyPool, j);
   
                        int k = 0;
                        
                        // Search position to insert in an ordered fashion ;-)
                        for (k = 0; k < j - 1; k++) {
                           if (_historyPool[k].openTime >= _tradingPool[i].openTime)
                              break;
                        }
                        
                        for (int l = j - 1; l > k; l--) {
                           _historyPool[l].closePrice = _historyPool[l - 1].closePrice;
                           _historyPool[l].closeTime = _historyPool[l - 1].closeTime;
                           _historyPool[l].comment = _historyPool[l - 1].comment;
                           _historyPool[l].commission = _historyPool[l - 1].commission;
                           _historyPool[l].expiration = _historyPool[l - 1].expiration;
                           _historyPool[l].lots = _historyPool[l - 1].lots;
                           _historyPool[l].magicNumber = _historyPool[l - 1].magicNumber;
                           _historyPool[l].openPrice = _historyPool[l - 1].openPrice;
                           _historyPool[l].openTime = _historyPool[l - 1].openTime;
                           _historyPool[l].profit = _historyPool[l - 1].profit;
                           _historyPool[l].stopLoss = _historyPool[l - 1].stopLoss;
                           _historyPool[l].swap = _historyPool[l - 1].swap;
                           _historyPool[l].symbol = _historyPool[l - 1].symbol;
                           _historyPool[l].takeProfit = _historyPool[l - 1].takeProfit;
                           _historyPool[l].ticket = _historyPool[l - 1].ticket;
                           _historyPool[l].type = _historyPool[l - 1].type;
                        }
   
                        _historyPool[k].closePrice = _tradingPool[i].closePrice;
                        _historyPool[k].closeTime = _tradingPool[i].closeTime;
                        _historyPool[k].comment = _tradingPool[i].comment;
                        _historyPool[k].commission = _tradingPool[i].commission;
                        _historyPool[k].expiration = _tradingPool[i].expiration;
                        _historyPool[k].lots = _tradingPool[i].lots;
                        _historyPool[k].magicNumber = _tradingPool[i].magicNumber;
                        _historyPool[k].openPrice = _tradingPool[i].openPrice;
                        _historyPool[k].openTime = _tradingPool[i].openTime;
                        _historyPool[k].profit = _tradingPool[i].profit;
                        _historyPool[k].stopLoss = _tradingPool[i].stopLoss;
                        _historyPool[k].swap = _tradingPool[i].swap;
                        _historyPool[k].symbol = _tradingPool[i].symbol;
                        _historyPool[k].takeProfit = _tradingPool[i].takeProfit;
                        _historyPool[k].ticket = _tradingPool[i].ticket;
                        _historyPool[k].type = _tradingPool[i].type;
                     }
                     
                     if (i < ArraySize(_tradingPool) - 1) {
                        for (int j = i; j < ArraySize(_tradingPool) - 1; j++) {
                           _tradingPool[j].closePrice = _tradingPool[j + 1].closePrice;
                           _tradingPool[j].closeTime = _tradingPool[j + 1].closeTime;
                           _tradingPool[j].comment = _tradingPool[j + 1].comment;
                           _tradingPool[j].commission = _tradingPool[j + 1].commission;
                           _tradingPool[j].expiration = _tradingPool[j + 1].expiration;
                           _tradingPool[j].lots = _tradingPool[j + 1].lots;
                           _tradingPool[j].magicNumber = _tradingPool[j + 1].magicNumber;
                           _tradingPool[j].openPrice = _tradingPool[j + 1].openPrice;
                           _tradingPool[j].openTime = _tradingPool[j + 1].openTime;
                           _tradingPool[j].profit = _tradingPool[j + 1].profit;
                           _tradingPool[j].stopLoss = _tradingPool[j + 1].stopLoss;
                           _tradingPool[j].swap = _tradingPool[j + 1].swap;
                           _tradingPool[j].symbol = _tradingPool[j + 1].symbol;
                           _tradingPool[j].takeProfit = _tradingPool[j + 1].takeProfit;
                           _tradingPool[j].ticket = _tradingPool[j + 1].ticket;
                           _tradingPool[j].type = _tradingPool[j + 1].type;
                        }
                     }
                     ArrayResize(_tradingPool, ArraySize(_tradingPool) - 1);
                  }

                  return true;
               }
            }
         }
      }
      return false;
   } 
 
   /**
    * Deletes previously opened pending order. 
    * If the function succeeds, the return value is true. 
    * If the function fails, the return value is false.
    * 
    * @param ticket The order ticket. 
    */
   bool orderDelete(ulong ticket) {
      for (int i = 0; i < ArraySize(_tradingPool); i++) {
         if (_tradingPool[i].ticket == ticket && (_tradingPool[i].type == OP_BUYLIMIT || _tradingPool[i].type == OP_SELLLIMIT)) {

            if (i < ArraySize(_tradingPool) - 1) {
               for (int j = i; j < ArraySize(_tradingPool) - 1; j++) {
                  _tradingPool[j].closePrice = _tradingPool[j + 1].closePrice;
                  _tradingPool[j].closeTime = _tradingPool[j + 1].closeTime;
                  _tradingPool[j].comment = _tradingPool[j + 1].comment;
                  _tradingPool[j].commission = _tradingPool[j + 1].commission;
                  _tradingPool[j].expiration = _tradingPool[j + 1].expiration;
                  _tradingPool[j].lots = _tradingPool[j + 1].lots;
                  _tradingPool[j].magicNumber = _tradingPool[j + 1].magicNumber;
                  _tradingPool[j].openPrice = _tradingPool[j + 1].openPrice;
                  _tradingPool[j].openTime = _tradingPool[j + 1].openTime;
                  _tradingPool[j].profit = _tradingPool[j + 1].profit;
                  _tradingPool[j].stopLoss = _tradingPool[j + 1].stopLoss;
                  _tradingPool[j].swap = _tradingPool[j + 1].swap;
                  _tradingPool[j].symbol = _tradingPool[j + 1].symbol;
                  _tradingPool[j].takeProfit = _tradingPool[j + 1].takeProfit;
                  _tradingPool[j].ticket = _tradingPool[j + 1].ticket;
                  _tradingPool[j].type = _tradingPool[j + 1].type;
               }
            }
            ArrayResize(_tradingPool, ArraySize(_tradingPool) - 1);

            return true;
         }
      }
      return false;
   }

   /**
    * Modifies the characteristics for the previously opened position or pending orders. 
    * If the function succeeds, the returned value will be TRUE. 
    * If the function fails, the returned value will be FALSE. 
    * To get the detailed error information, call GetLastError() function.
    * Notes: Open price and expiration time can be changed only for pending orders.
    * If unchanged values are passed as the function parameters, the error 1 (ERR_NO_RESULT) will be generated.
    * Pending order expiration time can be disabled in some trade servers. In this case, when a non-zero value is specified in the expiration parameter, the error 147 (ERR_TRADE_EXPIRATION_DENIED) will be generated. 
    * 
    * @param ticket The order ticket. 
    * @param price The new open price of the pending order. 
    * @param stoploss The new StopLoss level. 
    * @param takeprofit The new TakeProfit level. 
    * @param expiration The pending order expiration time. 
    */
   bool orderModify(ulong ticket, double price, double stopLoss, double takeProfit, datetime expiration) {
      for (int i = 0; i < ArraySize(_tradingPool); i++) {
         if (_tradingPool[i].ticket == ticket) {

            if (_tradingPool[i].type == OP_BUY || _tradingPool[i].type == OP_SELL
                  || _tradingPool[i].type == OP_BUYLIMIT || _tradingPool[i].type == OP_SELLLIMIT) {
            
               _tradingPool[i].stopLoss = stopLoss;
               _tradingPool[i].takeProfit = takeProfit;            

               return true;
            }
         }
      }
      return false;
   }

   /**
    * Selects an order for further processing. 
    * It returns true if the function succeeds. 
    * It returns false if the function fails. 
    * The pool parameter is ignored if the order is selected by the ticket number. 
    * To find out from what list the order has been selected, its close time must be analyzed. 
    * If the order close time equals to 0, the order is open or pending and taken from the terminal open positions list. 
    * One can distinguish an open position from a pending order by the order type. 
    * If the order close time does not equal to 0, the order is a closed order or a deleted pending order and was selected from the terminal history. 
    * They also differ from each other by their order types.
    * 
    * @param index The order index or order ticket depending on the second parameter. 
    * @param select The Selecting flags. It can be any of the following values:
    * @param pool The order pool index. Used when the selected parameter is SELECT_BY_POS.
    */
   bool orderSelect(int index, int select, int pool = MODE_TRADES) {
      if (pool == MODE_TRADES) {
         if (select == SELECT_BY_POS) {
            if (index >= 0 && index < ArraySize(_tradingPool)) {
               _selectedPool = MODE_TRADES;
               _selectedOrder = index;
               return true;
            }
         }
         else if (select == SELECT_BY_TICKET) {
            for (int i = 0; i < ArraySize(_tradingPool); i++) {
               if (_tradingPool[i].ticket == index) {
                  _selectedPool = MODE_TRADES;
                  _selectedOrder = i;
                  return true;
               }
            }
         }      
      }
      else if (pool == MODE_HISTORY) {
         if (select == SELECT_BY_POS) {
            if (index >= 0 && index < ArraySize(_historyPool)) {
               _selectedPool = MODE_HISTORY;
               _selectedOrder = index;
               return true;
            }
         }
         else if (select == SELECT_BY_TICKET) {
            for (int i = 0; i < ArraySize(_historyPool); i++) {
               if (_historyPool[i].ticket == index) {
                  _selectedPool = MODE_HISTORY;
                  _selectedOrder = i;
                  return true;
               }
            }
         }      
      }
      
      _selectedOrder = (-1);
      return false;
   }

   /**
    * Sends an order to be executed.
    *
    * @param symbol the symbol. 
    * @param cmd The operation type.
    * @param volume The number of lots. 
    * @param price The price. 
    * @param slippage The maximum price slippage in points. 
    * @param stopLoss The stop loss level. 
    * @param takeProfit The take profit level. 
    * @param comment The order comment. 
    * @param magicNumber The magic number. 
    * @param expiration The order expiration time (for pending orders only). 
    *
    * Returns number of the ticket assigned to the order by the trade server or -1 if it fails. 
    */
   ulong orderSend(string symbol, int cmd, double volume, double price, int slippage, double stopLoss, double takeProfit, string comment = "", int magicNumber = 0, datetime expiration = 0) {
      
      if (cmd == OP_BUY || cmd == OP_SELL) {

         MqlTradeCheckResult checkResult;
      
         MqlTradeRequest request;
         request.action = TRADE_ACTION_DEAL;
         request.type = (cmd == OP_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
         request.symbol = symbol;
         request.volume = NormalizeDouble(volume, 2);
         request.price = (cmd == OP_BUY ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID));
         request.sl = 0;
         request.tp = 0;
         request.deviation = slippage;
         request.magic = magicNumber;
         request.comment = comment;
         request.type_filling = ORDER_FILLING_AON;
         request.type_time = ORDER_TIME_GTC;
   
         MqlTradeResult result;
   
         if (OrderCheck(request, checkResult) && OrderSend(request, result)) {
            if (result.retcode == TRADE_RETCODE_DONE) {
               int i = ArraySize(_tradingPool);
               ArrayResize(_tradingPool, i + 1);
               _tradingPool[i].ticket = result.order;
               _tradingPool[i].symbol = symbol;
               _tradingPool[i].type = cmd;
               _tradingPool[i].lots = result.volume;
               // We assume that open price is the same as the desired price because result.ask is returning 0
               //_tradingPool[i].openPrice = result.price;
               _tradingPool[i].openPrice = price;
               _tradingPool[i].closePrice = (cmd == OP_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK));
               _tradingPool[i].openTime = TimeCurrent();
               _tradingPool[i].stopLoss = stopLoss;
               _tradingPool[i].takeProfit = takeProfit;
               _tradingPool[i].comment = comment;
               _tradingPool[i].magicNumber = magicNumber;
               _tradingPool[i].expiration = expiration;

               _selectedPool = MODE_TRADES;
               _selectedOrder = i;

               return result.order;
            }
         }
      }
      else if (cmd == OP_BUYLIMIT || cmd == OP_BUYSTOP || cmd == OP_SELLLIMIT || cmd == OP_SELLSTOP) {
         int i = ArraySize(_tradingPool);
         ArrayResize(_tradingPool, i + 1);
         _tradingPool[i].ticket = _limitedTicket;
         _tradingPool[i].symbol = symbol;
         _tradingPool[i].type = cmd;
         _tradingPool[i].lots = volume;
         _tradingPool[i].openPrice = price;
         _tradingPool[i].closePrice = 0.0;
         _tradingPool[i].openTime = TimeCurrent();
         _tradingPool[i].stopLoss = stopLoss;
         _tradingPool[i].takeProfit = takeProfit;
         _tradingPool[i].comment = comment;
         _tradingPool[i].magicNumber = magicNumber;
         _tradingPool[i].expiration = expiration;

         _selectedPool = MODE_TRADES;
         _selectedOrder = i;

         _limitedTicket++;

         return _tradingPool[i].ticket;
      }
      return (-1);
   }

   void cleanHistory(datetime date) {

      int i = ArraySize(_historyPool);
      
      int j = 0;
      for (j = 0; j < i; j++) {
         if (_historyPool[j].openTime >= date)
            break;
      }

      int l = 0;

      for (int k = j; k < i; k++) {
         _historyPool[l].closePrice = _historyPool[k].closePrice;
         _historyPool[l].closeTime = _historyPool[k].closeTime;
         _historyPool[l].comment = _historyPool[k].comment;
         _historyPool[l].commission = _historyPool[k].commission;
         _historyPool[l].expiration = _historyPool[k].expiration;
         _historyPool[l].lots = _historyPool[k].lots;
         _historyPool[l].magicNumber = _historyPool[k].magicNumber;
         _historyPool[l].openPrice = _historyPool[k].openPrice;
         _historyPool[l].openTime = _historyPool[k].openTime;
         _historyPool[l].profit = _historyPool[k].profit;
         _historyPool[l].stopLoss = _historyPool[k].stopLoss;
         _historyPool[l].swap = _historyPool[k].swap;
         _historyPool[l].symbol = _historyPool[k].symbol;
         _historyPool[l].takeProfit = _historyPool[k].takeProfit;
         _historyPool[l].ticket = _historyPool[k].ticket;
         _historyPool[l].type = _historyPool[k].type;
         l++;
      }

      if (j > 0)
         ArrayResize(_historyPool, i - j);
   }
};
