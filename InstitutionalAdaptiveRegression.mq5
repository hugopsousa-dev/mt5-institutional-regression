//+------------------------------------------------------------------+
//|                  InstitutionalAdaptiveRegression_v2.0.mq5       |
//|              Regressão Linear Adaptativa de Nível Institucional |
//|                           O Santo Graal das Médias Móveis       |
//+------------------------------------------------------------------+
#property copyright "Institutional Grade Adaptive Regression v2.0"
#property link      ""
#property version   "2.00"
#property description "Regressão linear adaptativa com múltiplos filtros institucionais"
#property description "Detecta tendências reais, elimina sinais falsos, identifica pontos de inflexão"

#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   5

// Plot 1: Linha Principal de Regressão
#property indicator_label1  "Regressão Institucional"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  4

// Plot 2: Banda Superior de Confiança
#property indicator_label2  "Banda Superior"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightSkyBlue
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

// Plot 3: Banda Inferior de Confiança
#property indicator_label3  "Banda Inferior"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLightSkyBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

// Plot 4: Sinal de Mudança de Tendência (Alta)
#property indicator_label4  "Reversão Alta"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3

// Plot 5: Sinal de Mudança de Tendência (Baixa)
#property indicator_label5  "Reversão Baixa"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_style5  STYLE_SOLID
#property indicator_width5  3

//+------------------------------------------------------------------+
//| PARÂMETROS DE ENTRADA - NÍVEL INSTITUCIONAL                     |
//+------------------------------------------------------------------+

//--- Configurações Principais
input group "═══ CONFIGURAÇÕES PRINCIPAIS ═══"
input int         InpBasePeriod = 100;              // Período Base da Regressão (50-500)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Preço Aplicado
input bool        InpUseVolumeWeight = true;         // Usar Peso por Volume
input bool        InpUseVolatilityAdaptive = true;  // Adaptação por Volatilidade

//--- Sistema Multi-Timeframe
input group "═══ ANÁLISE MULTI-TIMEFRAME ═══"
input bool        InpUseMTF = true;                  // Usar Múltiplos Timeframes
input ENUM_TIMEFRAMES InpTF1 = PERIOD_CURRENT;      // Timeframe 1 (Principal)
input ENUM_TIMEFRAMES InpTF2 = PERIOD_H1;           // Timeframe 2 (Intermediário)
input ENUM_TIMEFRAMES InpTF3 = PERIOD_H4;           // Timeframe 3 (Maior)
input double      InpMTFWeight1 = 0.5;              // Peso TF1 (0.0-1.0)
input double      InpMTFWeight2 = 0.3;              // Peso TF2 (0.0-1.0)
input double      InpMTFWeight3 = 0.2;              // Peso TF3 (0.0-1.0)

//--- Filtro Kalman (Elimina ruído de mercado)
input group "═══ FILTRO KALMAN (Anti-Ruído) ═══"
input bool        InpUseKalman = true;               // Ativar Filtro Kalman
input double      InpKalmanQ = 0.001;               // Process Noise (0.0001-0.01)
input double      InpKalmanR = 0.1;                 // Measurement Noise (0.01-1.0)

//--- Detecção de Regime de Mercado
input group "═══ DETECÇÃO DE REGIME ═══"
input bool        InpAutoRegime = true;              // Detecção Automática de Regime
input double      InpTrendThreshold = 0.7;          // Threshold Tendência (0.5-1.0)
input int         InpADXPeriod = 14;                // Período ADX
input double      InpADXStrong = 25.0;              // ADX Tendência Forte

//--- Validação Estatística
input group "═══ VALIDAÇÃO ESTATÍSTICA ═══"
input double      InpMinRSquared = 0.65;            // R² Mínimo (0.5-0.95)
input double      InpMinConfidence = 80.0;          // Confiança Mínima % (70-99)
input bool        InpShowConfidence = true;          // Mostrar Bandas de Confiança

//--- Detecção de Inflexão (Mudança de Tendência)
input group "═══ DETECÇÃO DE INFLEXÃO ═══"
input bool        InpDetectInflection = true;        // Detectar Pontos de Inflexão
input int         InpInflectionBars = 3;            // Barras para Confirmar (2-10)
input double      InpInflectionStrength = 1.5;      // Força da Inflexão (1.0-3.0)
input bool        InpConfirmWithPrice = true;       // Confirmar com Ação do Preço

//--- Filtro de Sinais Falsos
input group "═══ FILTRO DE SINAIS FALSOS ═══"
input bool        InpFilterWhipsaw = true;           // Filtrar Whipsaws
input int         InpMinBarsBetweenSignals = 10;    // Barras Mínimas Entre Sinais
input double      InpMinAngleChange = 15.0;         // Mudança Mínima Ângulo (graus)
input bool        InpRequireVolumeConfirm = true;   // Exigir Confirmação Volume

//--- Alertas e Notificações
input group "═══ ALERTAS E NOTIFICAÇÕES ═══"
input bool        InpShowAlerts = true;              // Alertas de Reversão
input bool        InpShowDashboard = true;           // Dashboard Institucional
input bool        InpSendNotifications = false;      // Enviar Notificações Push
input bool        InpShowStats = true;               // Mostrar Estatísticas

//--- Configurações Visuais
input group "═══ CONFIGURAÇÕES VISUAIS ═══"
input color       InpLineColorUp = clrDodgerBlue;   // Cor Tendência Alta
input color       InpLineColorDown = clrOrangeRed;  // Cor Tendência Baixa
input int         InpLineWidth = 4;                  // Espessura da Linha (2-5)
input bool        InpDynamicColors = true;           // Cores Dinâmicas por Força

//+------------------------------------------------------------------+
//| BUFFERS DO INDICADOR                                            |
//+------------------------------------------------------------------+
double MainRegressionBuffer[];        // Linha principal
double UpperBandBuffer[];             // Banda superior
double LowerBandBuffer[];             // Banda inferior
double BuySignalBuffer[];             // Sinais de compra
double SellSignalBuffer[];            // Sinais de venda

// Buffers de cálculo
double RSquaredBuffer[];              // Qualidade do ajuste
double SlopeBuffer[];                 // Inclinação
double VolatilityBuffer[];            // Volatilidade adaptativa
double VolumeWeightBuffer[];          // Peso por volume
double KalmanBuffer[];                // Filtro Kalman
double ADXBuffer[];                   // Força da tendência
double ConfidenceBuffer[];            // Nível de confiança
double InflectionBuffer[];            // Pontos de inflexão
double RegimeBuffer[];                // Regime de mercado

//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS                                               |
//+------------------------------------------------------------------+
// Kalman Filter State
double kalman_x = 0.0;                // Estado estimado
double kalman_p = 1.0;                // Covariância do erro
double kalman_k = 0.0;                // Ganho de Kalman

// Controle de sinais
datetime lastSignalTime = 0;
int lastSignalBar = 0;
bool trendUp = true;
double lastAngle = 0.0;
int consecutiveBars = 0;

// Estatísticas
int totalSignals = 0;
int correctSignals = 0;
double avgRSquared = 0.0;
double avgConfidence = 0.0;

// Handles de indicadores
int adxHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

// Prefix para objetos
string prefix = "InstReg_";

//+------------------------------------------------------------------+
//| INICIALIZAÇÃO                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configurar buffers de plot
   SetIndexBuffer(0, MainRegressionBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, UpperBandBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowerBandBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BuySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SellSignalBuffer, INDICATOR_DATA);
   
   // Buffers de cálculo
   SetIndexBuffer(5, RSquaredBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, SlopeBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, VolatilityBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, VolumeWeightBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, KalmanBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, ADXBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, ConfidenceBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, InflectionBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, RegimeBuffer, INDICATOR_CALCULATIONS);
   
   // Configurar propriedades dos plots
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpLineWidth);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(3, PLOT_ARROW, 233);  // Seta para cima
   PlotIndexSetInteger(4, PLOT_ARROW, 234);  // Seta para baixo
   
   // Configurar arrays como série
   ArraySetAsSeries(MainRegressionBuffer, true);
   ArraySetAsSeries(UpperBandBuffer, true);
   ArraySetAsSeries(LowerBandBuffer, true);
   ArraySetAsSeries(BuySignalBuffer, true);
   ArraySetAsSeries(SellSignalBuffer, true);
   ArraySetAsSeries(RSquaredBuffer, true);
   ArraySetAsSeries(SlopeBuffer, true);
   ArraySetAsSeries(VolatilityBuffer, true);
   ArraySetAsSeries(VolumeWeightBuffer, true);
   ArraySetAsSeries(KalmanBuffer, true);
   ArraySetAsSeries(ADXBuffer, true);
   ArraySetAsSeries(ConfidenceBuffer, true);
   ArraySetAsSeries(InflectionBuffer, true);
   ArraySetAsSeries(RegimeBuffer, true);
   
   // Criar indicadores auxiliares
   adxHandle = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   
   if(adxHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Erro ao criar indicadores auxiliares");
      return(INIT_FAILED);
   }
   
   // Limpar objetos antigos
   ObjectsDeleteAll(0, prefix);
   
   // Criar dashboard
   if(InpShowDashboard)
      CreateInstitutionalDashboard();
   
   // Nome do indicador
   IndicatorSetString(INDICATOR_SHORTNAME, "Institutional Regression v2.0");
   
   // Definir precisão
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   Print("═══════════════════════════════════════════════════");
   Print("  Institutional Adaptive Regression v2.0 ATIVADO");
   Print("  Configuração: Nível Institucional");
   Print("  Filtros: Kalman + MTF + Regime + Estatístico");
   Print("═══════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DESINICIALIZAÇÃO                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Liberar handles
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   
   // Limpar objetos
   ObjectsDeleteAll(0, prefix);
   ChartRedraw();
   
   Print("Institutional Regression v2.0 DESATIVADO");
}

//+------------------------------------------------------------------+
//| CÁLCULO PRINCIPAL                                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Verificar dados suficientes
   if(rates_total < InpBasePeriod + 50)
      return(0);
   
   // Configurar arrays como série
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   
   // Obter dados do ADX
   double adxValues[], plusDI[], minusDI[];
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(plusDI, true);
   ArraySetAsSeries(minusDI, true);
   
   if(CopyBuffer(adxHandle, 0, 0, rates_total, adxValues) <= 0)
      return(prev_calculated);
   if(CopyBuffer(adxHandle, 1, 0, rates_total, plusDI) <= 0)
      return(prev_calculated);
   if(CopyBuffer(adxHandle, 2, 0, rates_total, minusDI) <= 0)
      return(prev_calculated);
   
   // Obter ATR
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(atrHandle, 0, 0, rates_total, atrValues) <= 0)
      return(prev_calculated);
   
   // Calcular início
   int start = MathMax(prev_calculated - 1, InpBasePeriod);
   
   // Loop principal de cálculo
   for(int i = start; i >= 0 && !IsStopped(); i--)
   {
      // Inicializar buffers de sinal
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellSignalBuffer[i] = EMPTY_VALUE;
      
      // Verificar dados suficientes
      if(i + InpBasePeriod >= rates_total)
      {
         MainRegressionBuffer[i] = EMPTY_VALUE;
         UpperBandBuffer[i] = EMPTY_VALUE;
         LowerBandBuffer[i] = EMPTY_VALUE;
         continue;
      }
      
      // Determinar período adaptativo baseado na volatilidade
      int adaptivePeriod = InpBasePeriod;
      if(InpUseVolatilityAdaptive && i < rates_total - 20)
      {
         adaptivePeriod = CalculateAdaptivePeriod(close, i, InpBasePeriod, atrValues[i]);
      }
      
      // Calcular regressão linear ponderada
      double slope, intercept, rSquared, stdError;
      CalculateWeightedRegression(close, tick_volume, i, adaptivePeriod, 
                                  slope, intercept, rSquared, stdError);
      
      // Armazenar métricas
      SlopeBuffer[i] = slope;
      RSquaredBuffer[i] = rSquared;
      VolatilityBuffer[i] = atrValues[i];
      ADXBuffer[i] = adxValues[i];
      
      // Calcular valor da regressão
      double regressionValue = intercept + slope * (adaptivePeriod - 1);
      
      // Aplicar Filtro Kalman se habilitado
      if(InpUseKalman)
      {
         regressionValue = ApplyKalmanFilter(regressionValue, i);
         KalmanBuffer[i] = regressionValue;
      }
      
      // Aplicar análise Multi-Timeframe se habilitado
      if(InpUseMTF && i < rates_total - 100)
      {
         regressionValue = ApplyMultiTimeframeFilter(regressionValue, time[i], close[i]);
      }
      
      // Detectar regime de mercado
      double regimeScore = DetectMarketRegime(adxValues[i], rSquared, stdError, slope);
      RegimeBuffer[i] = regimeScore;
      
      // Calcular confiança estatística
      double confidence = CalculateConfidence(rSquared, stdError, regimeScore, adxValues[i]);
      ConfidenceBuffer[i] = confidence;
      
      // Aplicar regressão apenas se confiança for alta
      if(confidence >= InpMinConfidence && rSquared >= InpMinRSquared)
      {
         MainRegressionBuffer[i] = regressionValue;
         
         // Calcular bandas de confiança
         if(InpShowConfidence)
         {
            double bandWidth = stdError * (1.0 + (1.0 - confidence/100.0));
            UpperBandBuffer[i] = regressionValue + bandWidth;
            LowerBandBuffer[i] = regressionValue - bandWidth;
         }
      }
      else
      {
         // Baixa confiança - manter valor anterior
         if(i < rates_total - 1)
         {
            MainRegressionBuffer[i] = MainRegressionBuffer[i + 1];
            UpperBandBuffer[i] = UpperBandBuffer[i + 1];
            LowerBandBuffer[i] = LowerBandBuffer[i + 1];
         }
      }
      
      // Detectar pontos de inflexão (mudança de tendência)
      if(InpDetectInflection && i < rates_total - InpInflectionBars - 1)
      {
         DetectInflectionPoint(i, close, time, slope, adxValues, rSquared, confidence, high, low);
      }
      
      // Atualizar cor dinâmica da linha
      if(InpDynamicColors)
      {
         UpdateDynamicColors(i, slope, adxValues[i], confidence);
      }
   }
   
   // Atualizar dashboard
   if(InpShowDashboard && prev_calculated != rates_total)
   {
      UpdateInstitutionalDashboard(close[0], adxValues[0]);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calcular Regressão Linear Ponderada por Volume                  |
//+------------------------------------------------------------------+
void CalculateWeightedRegression(const double &price[], const long &volume[], 
                                 int bar, int period,
                                 double &slope, double &intercept, 
                                 double &rSquared, double &stdError)
{
   double sumW = 0, sumWX = 0, sumWY = 0, sumWXY = 0, sumWX2 = 0;
   double sumWYY = 0;
   
   // Calcular somas ponderadas
   for(int i = 0; i < period; i++)
   {
      int idx = bar + period - 1 - i;
      if(idx >= ArraySize(price)) continue;
      
      double x = i;
      double y = price[idx];
      
      // Peso: combinação de volume e recência
      double weight = 1.0;
      if(InpUseVolumeWeight && volume[idx] > 0)
      {
         weight = (double)volume[idx];
      }
      
      // Peso exponencial para dados mais recentes
      weight *= MathExp(-0.01 * i);
      
      sumW += weight;
      sumWX += weight * x;
      sumWY += weight * y;
      sumWXY += weight * x * y;
      sumWX2 += weight * x * x;
      sumWYY += weight * y * y;
   }
   
   // Calcular coeficientes da regressão
   double denominator = sumW * sumWX2 - sumWX * sumWX;
   
   if(MathAbs(denominator) > 0.0001)
   {
      slope = (sumW * sumWXY - sumWX * sumWY) / denominator;
      intercept = (sumWY - slope * sumWX) / sumW;
      
      // Calcular R-squared
      double ssTotal = sumWYY - (sumWY * sumWY) / sumW;
      double ssResidual = 0;
      
      for(int i = 0; i < period; i++)
      {
         int idx = bar + period - 1 - i;
         if(idx >= ArraySize(price)) continue;
         
         double x = i;
         double y = price[idx];
         double yPredicted = intercept + slope * x;
         
         double weight = 1.0;
         if(InpUseVolumeWeight && volume[idx] > 0)
            weight = (double)volume[idx];
         weight *= MathExp(-0.01 * i);
         
         ssResidual += weight * MathPow(y - yPredicted, 2);
      }
      
      rSquared = (ssTotal > 0) ? 1.0 - (ssResidual / ssTotal) : 0;
      rSquared = MathMax(0.0, MathMin(1.0, rSquared));
      
      // Calcular erro padrão
      stdError = (sumW > 0) ? MathSqrt(ssResidual / sumW) : 0;
   }
   else
   {
      slope = 0;
      intercept = (sumW > 0) ? sumWY / sumW : price[bar];
      rSquared = 0;
      stdError = 0;
   }
}

//+------------------------------------------------------------------+
//| Calcular Período Adaptativo baseado em Volatilidade             |
//+------------------------------------------------------------------+
int CalculateAdaptivePeriod(const double &price[], int bar, int basePeriod, double atr)
{
   // Calcular volatilidade relativa
   double avgPrice = 0;
   for(int i = 0; i < 20; i++)
   {
      if(bar + i >= ArraySize(price)) break;
      avgPrice += price[bar + i];
   }
   avgPrice /= 20;
   
   double volatilityRatio = (avgPrice > 0) ? (atr / avgPrice) * 100 : 1.0;
   
   // Ajustar período: menor período em alta volatilidade, maior em baixa
   int adaptivePeriod = basePeriod;
   
   if(volatilityRatio > 2.0)  // Alta volatilidade
      adaptivePeriod = (int)(basePeriod * 0.7);
   else if(volatilityRatio < 0.5)  // Baixa volatilidade
      adaptivePeriod = (int)(basePeriod * 1.3);
   
   return (int)MathMax(20, MathMin(adaptivePeriod, 500));
}

//+------------------------------------------------------------------+
//| Aplicar Filtro de Kalman (Remove ruído, mantém sinal)           |
//+------------------------------------------------------------------+
double ApplyKalmanFilter(double measurement, int bar)
{
   // Inicializar estado na primeira barra
   if(bar == ArraySize(MainRegressionBuffer) - 1)
   {
      kalman_x = measurement;
      kalman_p = 1.0;
      return measurement;
   }
   
   // Predict
   double x_predict = kalman_x;
   double p_predict = kalman_p + InpKalmanQ;
   
   // Update
   kalman_k = p_predict / (p_predict + InpKalmanR);
   kalman_x = x_predict + kalman_k * (measurement - x_predict);
   kalman_p = (1.0 - kalman_k) * p_predict;
   
   return kalman_x;
}

//+------------------------------------------------------------------+
//| Aplicar Filtro Multi-Timeframe                                  |
//+------------------------------------------------------------------+
double ApplyMultiTimeframeFilter(double currentValue, datetime currentTime, double currentPrice)
{
   // Obter valores de timeframes superiores
   double tf2Value = GetRegressionValueFromTF(InpTF2, currentTime);
   double tf3Value = GetRegressionValueFromTF(InpTF3, currentTime);
   
   // Se não conseguiu obter valores, retornar valor atual
   if(tf2Value == 0) tf2Value = currentValue;
   if(tf3Value == 0) tf3Value = currentValue;
   
   // Normalizar pesos
   double totalWeight = InpMTFWeight1 + InpMTFWeight2 + InpMTFWeight3;
   if(totalWeight == 0) totalWeight = 1.0;
   
   double w1 = InpMTFWeight1 / totalWeight;
   double w2 = InpMTFWeight2 / totalWeight;
   double w3 = InpMTFWeight3 / totalWeight;
   
   // Combinar valores com pesos
   double combinedValue = currentValue * w1 + tf2Value * w2 + tf3Value * w3;
   
   return combinedValue;
}

//+------------------------------------------------------------------+
//| Obter Valor de Regressão de Outro Timeframe                     |
//+------------------------------------------------------------------+
double GetRegressionValueFromTF(ENUM_TIMEFRAMES tf, datetime currentTime)
{
   if(tf == PERIOD_CURRENT) return 0;
   
   // Obter dados do timeframe
   double closeArray[];
   ArraySetAsSeries(closeArray, true);
   
   int copied = CopyClose(_Symbol, tf, currentTime, 100, closeArray);
   if(copied < 50) return 0;
   
   // Calcular regressão simples
   double slope, intercept, rSquared, stdError;
   long dummyVolume[];
   ArrayResize(dummyVolume, copied);
   ArrayInitialize(dummyVolume, 1);
   
   CalculateWeightedRegression(closeArray, dummyVolume, 0, 
                               MathMin(50, copied), 
                               slope, intercept, rSquared, stdError);
   
   return intercept + slope * 49;
}

//+------------------------------------------------------------------+
//| Detectar Regime de Mercado (Trending vs Ranging)                |
//+------------------------------------------------------------------+
double DetectMarketRegime(double adx, double rSquared, double stdError, double slope)
{
   double regimeScore = 0.0;
   
   // Componente 1: ADX (força da tendência)
   double adxScore = 0.0;
   if(adx >= InpADXStrong)
      adxScore = 1.0;
   else if(adx >= 20)
      adxScore = (adx - 20) / (InpADXStrong - 20);
   
   // Componente 2: R-squared (qualidade do ajuste linear)
   double fitScore = rSquared;
   
   // Componente 3: Inclinação consistente
   double slopeScore = MathMin(MathAbs(slope) * 10000, 1.0);
   
   // Componente 4: Baixo erro padrão
   double errorScore = 1.0 / (1.0 + stdError * 100);
   
   // Combinar scores
   regimeScore = (adxScore * 0.4) + (fitScore * 0.3) + 
                 (slopeScore * 0.2) + (errorScore * 0.1);
   
   return MathMax(0.0, MathMin(1.0, regimeScore));
}

//+------------------------------------------------------------------+
//| Calcular Nível de Confiança                                     |
//+------------------------------------------------------------------+
double CalculateConfidence(double rSquared, double stdError, double regime, double adx)
{
   // Confiança base do R-squared
   double baseConfidence = rSquared * 100;
   
   // Ajuste pelo regime de mercado
   double regimeBonus = regime * 15;
   
   // Ajuste pelo ADX
   double adxBonus = 0;
   if(adx >= InpADXStrong)
      adxBonus = 10;
   else if(adx >= 20)
      adxBonus = ((adx - 20) / (InpADXStrong - 20)) * 10;
   
   // Penalidade por erro alto
   double errorPenalty = MathMin(stdError * 1000, 20);
   
   // Calcular confiança final
   double confidence = baseConfidence + regimeBonus + adxBonus - errorPenalty;
   
   return MathMax(0.0, MathMin(100.0, confidence));
}

//+------------------------------------------------------------------+
//| Detectar Ponto de Inflexão (Mudança de Tendência Real)          |
//+------------------------------------------------------------------+
void DetectInflectionPoint(int bar, const double &close[], const datetime &time[],
                          double currentSlope, const double &adx[], 
                          double rSquared, double confidence,
                          const double &high[], const double &low[])
{
   // Não processar a barra atual
   if(bar == 0) return;
   
   // Verificar se há slope anterior
   if(bar >= ArraySize(SlopeBuffer) - InpInflectionBars) return;
   
   // Calcular média das slopes anteriores
   double avgPrevSlope = 0;
   int count = 0;
   for(int i = 1; i <= InpInflectionBars; i++)
   {
      if(bar + i >= ArraySize(SlopeBuffer)) break;
      avgPrevSlope += SlopeBuffer[bar + i];
      count++;
   }
   
   if(count == 0) return;
   avgPrevSlope /= count;
   
   // Detectar mudança significativa na direção
   bool slopeChanged = false;
   bool wasUp = (avgPrevSlope > 0);
   bool nowUp = (currentSlope > 0);
   
   // Mudança de direção
   if(wasUp != nowUp)
   {
      // Calcular força da mudança
      double changeStrength = MathAbs(currentSlope - avgPrevSlope);
      double angle = MathArctan(currentSlope) * 180.0 / M_PI;
      double prevAngle = MathArctan(avgPrevSlope) * 180.0 / M_PI;
      double angleChange = MathAbs(angle - prevAngle);
      
      // Verificar critérios de inflexão
      bool strongChange = changeStrength > 0.0001 * InpInflectionStrength;
      bool significantAngle = angleChange >= InpMinAngleChange;
      bool highConfidence = confidence >= InpMinConfidence;
      bool strongTrend = adx[bar] >= 20;
      bool goodFit = rSquared >= InpMinRSquared;
      
      // Confirmar com ação do preço se habilitado
      bool priceConfirm = true;
      if(InpConfirmWithPrice && bar < ArraySize(close) - 2)
      {
         if(nowUp)  // Mudança para alta
            priceConfirm = (close[bar] > close[bar + 1]) && 
                          (close[bar] > MainRegressionBuffer[bar + 1]);
         else  // Mudança para baixa
            priceConfirm = (close[bar] < close[bar + 1]) && 
                          (close[bar] < MainRegressionBuffer[bar + 1]);
      }
      
      // Filtrar whipsaws
      bool notWhipsaw = true;
      if(InpFilterWhipsaw)
      {
         int barsSinceLastSignal = bar - lastSignalBar;
         notWhipsaw = (barsSinceLastSignal >= InpMinBarsBetweenSignals) || 
                      (lastSignalBar == 0);
      }
      
      // Confirmar volume se necessário
      bool volumeConfirm = true;
      // (Implementação simplificada - pode ser expandida)
      
      // Se todos os critérios forem atendidos, marcar inflexão
      if(strongChange && significantAngle && highConfidence && 
         strongTrend && goodFit && priceConfirm && notWhipsaw && volumeConfirm)
      {
         slopeChanged = true;
         
         // Registrar sinal
         if(nowUp)
         {
            BuySignalBuffer[bar] = MainRegressionBuffer[bar];
            
            // Criar marcador visual
            if(bar > 0)  // Não na barra atual
            {
               CreateInflectionMarker(time[bar], low[bar], true, confidence, angleChange);
            }
            
            // Alerta
            if(InpShowAlerts && bar == 1)
            {
               string msg = StringFormat("REVERSÃO PARA ALTA CONFIRMADA!\nConfiança: %.1f%% | Ângulo: %.1f°", 
                                       confidence, angleChange);
               Alert(msg);
               
               if(InpSendNotifications)
                  SendNotification(msg);
            }
         }
         else
         {
            SellSignalBuffer[bar] = MainRegressionBuffer[bar];
            
            // Criar marcador visual
            if(bar > 0)  // Não na barra atual
            {
               CreateInflectionMarker(time[bar], high[bar], false, confidence, angleChange);
            }
            
            // Alerta
            if(InpShowAlerts && bar == 1)
            {
               string msg = StringFormat("REVERSÃO PARA BAIXA CONFIRMADA!\nConfiança: %.1f%% | Ângulo: %.1f°", 
                                       confidence, angleChange);
               Alert(msg);
               
               if(InpSendNotifications)
                  SendNotification(msg);
            }
         }
         
         // Atualizar controle
         lastSignalBar = bar;
         lastSignalTime = time[bar];
         lastAngle = angle;
         trendUp = nowUp;
         totalSignals++;
         
         InflectionBuffer[bar] = nowUp ? 1.0 : -1.0;
      }
   }
}

//+------------------------------------------------------------------+
//| Criar Marcador de Inflexão                                      |
//+------------------------------------------------------------------+
void CreateInflectionMarker(datetime time, double price, bool isUp, 
                           double confidence, double angleChange)
{
   string name = prefix + "INFLECTION_" + TimeToString(time);
   
   // Remover se já existe
   ObjectDelete(0, name);
   
   // Criar seta
   if(ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isUp ? 233 : 234);
      ObjectSetInteger(0, name, OBJPROP_COLOR, isUp ? clrLime : clrRed);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      // Adicionar texto descritivo
      string textName = name + "_TEXT";
      double textPrice = isUp ? price - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 200) :
                                price + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 200);
      
      if(ObjectCreate(0, textName, OBJ_TEXT, 0, time, textPrice))
      {
         string text = StringFormat("%.0f%% | %.0f°", confidence, angleChange);
         ObjectSetString(0, textName, OBJPROP_TEXT, text);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, isUp ? clrLime : clrRed);
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      }
   }
}

//+------------------------------------------------------------------+
//| Atualizar Cores Dinâmicas                                       |
//+------------------------------------------------------------------+
void UpdateDynamicColors(int bar, double slope, double adx, double confidence)
{
   // Determinar cor baseada em múltiplos fatores
   color lineColor;
   
   if(slope > 0)
   {
      // Tendência de alta - variação de verde
      if(confidence >= 90 && adx >= InpADXStrong)
         lineColor = clrLime;  // Verde forte
      else if(confidence >= 75)
         lineColor = clrGreen;  // Verde médio
      else
         lineColor = clrDarkGreen;  // Verde escuro
   }
   else
   {
      // Tendência de baixa - variação de vermelho
      if(confidence >= 90 && adx >= InpADXStrong)
         lineColor = clrRed;  // Vermelho forte
      else if(confidence >= 75)
         lineColor = clrOrangeRed;  // Laranja-vermelho
      else
         lineColor = clrDarkRed;  // Vermelho escuro
   }
   
   // Aplicar cor (simplificado - em implementação real usaria PLOT_COLOR_INDEXES)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, lineColor);
}

//+------------------------------------------------------------------+
//| Criar Dashboard Institucional                                   |
//+------------------------------------------------------------------+
void CreateInstitutionalDashboard()
{
   // Painel principal
   string objName = prefix + "Panel";
   
   if(ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 25);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, 280);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, 240);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   }
   
   // Título
   CreateDashText(prefix + "Title", 20, 35, 
                  "═══ INSTITUTIONAL REGRESSION ═══", 
                  clrGold, 10, true);
   CreateDashText(prefix + "Version", 20, 50, 
                  "v2.0 - Grade Institucional", 
                  clrSilver, 7, false);
}

//+------------------------------------------------------------------+
//| Atualizar Dashboard Institucional                               |
//+------------------------------------------------------------------+
void UpdateInstitutionalDashboard(double price, double adx)
{
   if(!InpShowDashboard) return;
   
   // Obter valores atuais
   double currentReg = MainRegressionBuffer[0];
   double currentSlope = SlopeBuffer[0];
   double currentRSquared = RSquaredBuffer[0];
   double currentConfidence = ConfidenceBuffer[0];
   double currentRegime = RegimeBuffer[0];
   
   // Determinar tendência
   string trendText = currentSlope > 0 ? "ALTA ▲" : 
                      currentSlope < 0 ? "BAIXA ▼" : "LATERAL ─";
   color trendColor = currentSlope > 0 ? clrLime : 
                      currentSlope < 0 ? clrRed : clrGray;
   
   // Qualidade do sinal
   string qualityText;
   color qualityColor;
   
   if(currentConfidence >= 90)
   {
      qualityText = "EXCELENTE ★★★★★";
      qualityColor = clrLime;
   }
   else if(currentConfidence >= 80)
   {
      qualityText = "ÓTIMO ★★★★";
      qualityColor = clrGreen;
   }
   else if(currentConfidence >= 70)
   {
      qualityText = "BOM ★★★";
      qualityColor = clrYellow;
   }
   else if(currentConfidence >= 60)
   {
      qualityText = "REGULAR ★★";
      qualityColor = clrOrange;
   }
   else
   {
      qualityText = "FRACO ★";
      qualityColor = clrRed;
   }
   
   // Regime de mercado
   string regimeText = currentRegime >= InpTrendThreshold ? "TRENDING" : "RANGING";
   color regimeColor = currentRegime >= InpTrendThreshold ? clrLime : clrOrange;
   
   // Força ADX
   string adxText;
   color adxColor;
   if(adx >= InpADXStrong)
   {
      adxText = "FORTE";
      adxColor = clrLime;
   }
   else if(adx >= 20)
   {
      adxText = "MODERADO";
      adxColor = clrYellow;
   }
   else
   {
      adxText = "FRACO";
      adxColor = clrRed;
   }
   
   // Distância do preço
   double distPercent = 0;
   if(currentReg > 0)
      distPercent = ((price - currentReg) / currentReg) * 100;
   
   string distText = StringFormat("%.2f%%", MathAbs(distPercent));
   color distColor = MathAbs(distPercent) <= 0.5 ? clrYellow : clrSilver;
   
   // Criar/atualizar textos
   int y = 70;
   int spacing = 20;
   
   CreateDashText(prefix + "TrendLabel", 20, y, "● Tendência:", clrWhite, 8, false);
   CreateDashText(prefix + "TrendValue", 140, y, trendText, trendColor, 8, true);
   y += spacing;
   
   CreateDashText(prefix + "QualityLabel", 20, y, "● Qualidade:", clrWhite, 8, false);
   CreateDashText(prefix + "QualityValue", 140, y, qualityText, qualityColor, 7, false);
   y += spacing;
   
   CreateDashText(prefix + "RegimeLabel", 20, y, "● Regime:", clrWhite, 8, false);
   CreateDashText(prefix + "RegimeValue", 140, y, regimeText, regimeColor, 8, true);
   y += spacing;
   
   CreateDashText(prefix + "ADXLabel", 20, y, "● Força ADX:", clrWhite, 8, false);
   CreateDashText(prefix + "ADXValue", 140, y, 
                  StringFormat("%.1f - %s", adx, adxText), adxColor, 8, false);
   y += spacing;
   
   CreateDashText(prefix + "LineLabel", 20, y, "● Linha Atual:", clrWhite, 8, false);
   CreateDashText(prefix + "LineValue", 140, y, 
                  DoubleToString(currentReg, _Digits), clrDodgerBlue, 8, true);
   y += spacing;
   
   CreateDashText(prefix + "DistLabel", 20, y, "● Distância:", clrWhite, 8, false);
   CreateDashText(prefix + "DistValue", 140, y, distText, distColor, 8, false);
   y += spacing;
   
   CreateDashText(prefix + "ConfLabel", 20, y, "● Confiança:", clrWhite, 8, false);
   CreateDashText(prefix + "ConfValue", 140, y, 
                  StringFormat("%.1f%%", currentConfidence), qualityColor, 8, true);
   y += spacing;
   
   CreateDashText(prefix + "R2Label", 20, y, "● R-Squared:", clrWhite, 8, false);
   CreateDashText(prefix + "R2Value", 140, y, 
                  StringFormat("%.3f", currentRSquared), 
                  currentRSquared >= 0.8 ? clrLime : clrYellow, 8, false);
   y += spacing;
   
   if(InpShowStats)
   {
      CreateDashText(prefix + "StatsLabel", 20, y, "● Sinais:", clrWhite, 8, false);
      CreateDashText(prefix + "StatsValue", 140, y, 
                     IntegerToString(totalSignals), clrSilver, 8, false);
   }
}

//+------------------------------------------------------------------+
//| Criar Texto do Dashboard                                        |
//+------------------------------------------------------------------+
void CreateDashText(string name, int x, int y, string text, 
                   color clr, int size, bool bold)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   }
   
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Timer Event                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Atualizar dashboard em tempo real se necessário
}

//+------------------------------------------------------------------+
//| Chart Event                                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, 
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+