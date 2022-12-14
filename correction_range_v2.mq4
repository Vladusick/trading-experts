//+------------------------------------------------------------------+
//|                                          correction_range_v2.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
// Правильно находит начало и конец коррекции
// Правильно фильтрует
// Правильно заходит в лонг (щорты пока не сделал)
// может ставить динамический тейк в на перехай перелой коррекции

// todo
// сделать мартингейл
// сделать мартин со стопом
// сделать мартин со стопом и траллом

#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
extern string fast_ma_str = "Настройки для быстрой МА";
extern int fast_ma_period = 10; // Период МА
extern int fast_ma_shift = 0; // Сдвиг МА
extern ENUM_MA_METHOD fast_ma_method = 0; // Метод МА
extern ENUM_APPLIED_PRICE fast_ma_applied_price = 0; // Тип Цены МА

extern string slow_ma_str = "Настройки для медленной МА";
extern int slow_ma_ma_period = 50; // Период МА
extern int slow_ma_shift = 0; // Сдвиг МА
extern ENUM_MA_METHOD slow_ma_method = 0; // Метод МА
extern ENUM_APPLIED_PRICE slow_ma_applied_price = 0; // Тип Цены МА

extern double lot = 0.01; // Лот
extern int takeProfit = 200;
extern int stopLoss = 200;
extern int slip = 50; // Проскальзывание
extern int magic = 72511;
extern int lifeTimeMinutes = 360;


extern int trailingStop = 300; 
extern int trailingStep = 100;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

   lifeTimeMinutes = lifeTimeMinutes * 60;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   double d1_fast_ma = iMA(_Symbol, PERIOD_D1, 10, 0, MODE_SMA, PRICE_CLOSE, 1);
   double d1_slow_ma = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE, 1);

   double h4_fast_ma = iMA(_Symbol, PERIOD_H4, 10, 0, MODE_SMA, PRICE_CLOSE, 1);
   double h4_slow_ma = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_SMA, PRICE_CLOSE, 1);

   double h1_fast_ma = iMA(_Symbol, PERIOD_H1, 10, 0, MODE_SMA, PRICE_CLOSE, 1);
   double h1_slow_ma = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_SMA, PRICE_CLOSE, 1);

   double m15_fast_ma = iMA(_Symbol, PERIOD_M15, 10, 0, MODE_SMA, PRICE_CLOSE, 1);
   double m15_slow_ma = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_SMA, PRICE_CLOSE, 1);

   double fast_ma_first_bar = iMA(_Symbol, PERIOD_CURRENT, fast_ma_period, fast_ma_shift, fast_ma_method, fast_ma_applied_price, 1);
   double fast_ma_second_bar = iMA(_Symbol, PERIOD_CURRENT, fast_ma_period, fast_ma_shift, fast_ma_method, fast_ma_applied_price, 2);
   double slow_ma_first_bar = iMA(_Symbol, PERIOD_CURRENT, slow_ma_ma_period, slow_ma_shift, slow_ma_method, slow_ma_applied_price, 1);
   double slow_ma_second_bar = iMA(_Symbol, PERIOD_CURRENT, slow_ma_ma_period, slow_ma_shift, slow_ma_method, slow_ma_applied_price, 2);


   datetime search_first_correction_bar_start_time;
   datetime correction_bar_end_time;

   int search_first_correction_bar;
   datetime firstCorrectionBarTime;

   int signal_correction_bar;
   datetime signal_correction_bar_time;
   double signal_price;
   
   // бар чтобы пихать туда тейк на перехай перелой
   int take_profit_bar;
   double take_profit_price;

// количество баров, которые будут прибавляться к началу коррекции по МА, чтобы убрать запаздание МА и поставть цену ниже
   int anti_lag_bar_count_filter = 3;


   if(OrdersTotal() == 0)
     {
   // фильтр по старшим ТФ
      if(/*d1_fast_ma > d1_slow_ma && h4_fast_ma > h4_slow_ma && */ h1_fast_ma > h1_slow_ma && m15_fast_ma > m15_slow_ma)
        {
         //выход из коррекции (окончание коррекции)
         if(fast_ma_first_bar > slow_ma_first_bar && fast_ma_second_bar < slow_ma_second_bar)
           {
            correction_bar_end_time = iTime(_Symbol, PERIOD_CURRENT, 1);
            Print("Время бара с которого закончилась коррекция " + correction_bar_end_time);

            //цикл обратно в историю, поиск начала коррекции
            for(int i = 1; i <= Bars; i++)
              {
               fast_ma_first_bar = iMA(_Symbol, PERIOD_CURRENT, fast_ma_period, fast_ma_shift, fast_ma_method, fast_ma_applied_price, i);
               fast_ma_second_bar = iMA(_Symbol, PERIOD_CURRENT, fast_ma_period, fast_ma_shift, fast_ma_method, fast_ma_applied_price, i+1);
               slow_ma_first_bar = iMA(_Symbol, PERIOD_CURRENT, slow_ma_ma_period, slow_ma_shift, slow_ma_method, slow_ma_applied_price, i);
               slow_ma_second_bar = iMA(_Symbol, PERIOD_CURRENT, slow_ma_ma_period, slow_ma_shift, slow_ma_method, slow_ma_applied_price, i+1);

               // нашли начало коррекции
               if(fast_ma_first_bar < slow_ma_first_bar && fast_ma_second_bar > slow_ma_second_bar)
                 {
                  search_first_correction_bar = i;
                  search_first_correction_bar_start_time = iTime(_Symbol, PERIOD_CURRENT, i);

                  Print("Время найденного бара (начало коррекции) " + search_first_correction_bar_start_time);
                  Print("Номер найденого бара (начало коррекции) " + search_first_correction_bar);

                  // Когда буду переделывать для конкретного направление можно изменить моде клоуз на моде хай или лой в зависимости от направления
                  signal_correction_bar = iLowest(_Symbol, PERIOD_CURRENT, MODE_CLOSE,
                                                  search_first_correction_bar + anti_lag_bar_count_filter, 1);
                  Print("Номер макc-мин бара из диапазона " + signal_correction_bar);

                  // Время мин-микс бара (экстремума), просто чтобы сверять его в логах, больше ни для чего это время не нужно
                  signal_correction_bar_time = iTime(_Symbol, PERIOD_CURRENT, signal_correction_bar);
                  Print("Время макс-мин бара из диапазона " + signal_correction_bar_time);

                  signal_price = Low[signal_correction_bar];
                  Print("Цена для входа = " + signal_price);
                  
                  //это допчик, тут считается динамический тейк
                  take_profit_bar = iHighest(_Symbol, PERIOD_CURRENT, MODE_CLOSE, search_first_correction_bar, 1);
                  Print("Номер бара для тейка " + take_profit_bar);
                  
                  take_profit_price = High[take_profit_bar];
                  Print("Цена для выхода по тейку = " + take_profit_price);
                  

                  // отправка ордера
                  // тейк динамический = (take_profit_price),
                  // тейк статический = NormalizeDouble(signal_price + takeProfit * _Point, _Digits),
                  if(OrderSend(_Symbol, OP_BUYLIMIT, lot, signal_price, slip,
                               NormalizeDouble(signal_price - stopLoss * _Point, _Digits),
                               NormalizeDouble(signal_price + takeProfit * _Point, _Digits),
                               "Comment", magic, TimeCurrent() + lifeTimeMinutes, clrBlue)!= -1)
                    {
                     Print("buy");
                    }
                  else
                     Print("Error ", GetLastError());
                  break;
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+

