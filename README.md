# Institutional Adaptive Regression — MT5

> Indicador de regressão linear adaptativa para MetaTrader 5, com filtros estatísticos de nível institucional para identificar tendências reais e eliminar sinais falsos.

[![Language: MQL5](https://img.shields.io/badge/Language-MQL5-blue)]()
[![Platform: MT5](https://img.shields.io/badge/Platform-MetaTrader%205-green)]()
[![Version](https://img.shields.io/badge/Version-2.0-orange)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## Sobre

**Institutional Adaptive Regression** é um indicador para a plataforma MetaTrader 5 que combina regressão linear ponderada por volume, filtro de Kalman, análise multi-timeframe e validação estatística para gerar uma linha de tendência mais robusta e confiável que médias móveis tradicionais.

A ideia é simples: ao invés de seguir o preço com lag (como uma EMA faz), o indicador modela a tendência local com regressão linear, pondera por volume e recência, suaviza com Kalman e só plota a linha quando o ajuste estatístico (R²) e a confiança calculada estão acima de limites configuráveis. Sinais de reversão só são gerados quando múltiplos critérios convergem ao mesmo tempo.

---

## Capturas de tela

![Indicador plotado no USDJPY Daily — linha de regressão, bandas de confiança e dashboard institucional](docs/images/chart-overview.png)

_Indicador rodando em USDJPY Daily. À esquerda, dashboard com tendência atual (ALTA), regime (RANGING), força ADX e R². No gráfico, a linha azul de regressão acompanha o preço com bandas pontilhadas de confiança ao redor._

---

## Recursos

### Estatística e modelagem
- **Regressão linear ponderada** por volume e por recência (peso exponencial decrescente)
- **Filtro de Kalman** para reduzir ruído de mercado mantendo o sinal
- **Período adaptativo por volatilidade** — encurta em alta volatilidade (ATR), alonga em baixa
- **Validação por R²** — só plota a linha se o ajuste estatístico for bom o suficiente
- **Erro padrão** usado para dimensionar bandas de confiança dinâmicas

### Análise multi-timeframe
- Combina regressão do timeframe atual com até **dois timeframes superiores** (ex.: M5 + H1 + H4)
- Pesos configuráveis para cada timeframe (default: 50% / 30% / 20%)

### Detecção de regime
- Score combinando **ADX**, **R²**, **inclinação** e **erro padrão**
- Diferencia mercados em **tendência (trending)** e **lateralizados (ranging)**
- Limite configurável para o que conta como "tendência forte"

### Sinais de reversão (pontos de inflexão)
Setas de compra e venda só aparecem quando **todos os critérios** abaixo convergem:

1. Mudança de direção da inclinação (slope) entre janelas
2. Mudança angular mínima (em graus) configurável
3. Confiança estatística acima do mínimo
4. ADX indicando tendência (força mínima)
5. R² acima do limite mínimo
6. Confirmação pela ação do preço (close fecha do lado correto da linha)
7. Filtro anti-whipsaw (mínimo de barras entre sinais)

### Dashboard em tempo real
Painel institucional plotado no canto do gráfico mostrando: tendência atual, qualidade do sinal (★1–5), regime, força ADX, valor da linha, distância do preço, confiança e R².

### Alertas
- Alerta interno do MT5 em reversões confirmadas
- Notificações push opcionais para o app MetaTrader no celular

---

## Instalação

1. Faça download do arquivo [`src/InstitutionalAdaptiveRegression.mq5`](src/InstitutionalAdaptiveRegression.mq5).
2. No MetaTrader 5, abra **Arquivo → Abrir Pasta de Dados**.
3. Copie o arquivo `.mq5` para a pasta `MQL5/Indicators/`.
4. No terminal MT5, na janela **Navegador**, clique direito em **Indicadores → Atualizar**.
5. Arraste **Institutional Adaptive Regression** para o gráfico desejado.

> **Compilação:** se o indicador não aparecer compilado, abra-o no MetaEditor (F4 no MT5) e pressione **F7** para compilar.

---

## Parâmetros de configuração

### Configurações principais
| Parâmetro | Default | Descrição |
|---|---|---|
| `InpBasePeriod` | 100 | Período base da regressão (50–500) |
| `InpAppliedPrice` | PRICE_CLOSE | Preço aplicado ao cálculo |
| `InpUseVolumeWeight` | true | Ponderar regressão pelo volume |
| `InpUseVolatilityAdaptive` | true | Ajustar período pela volatilidade (ATR) |

### Multi-timeframe
| Parâmetro | Default | Descrição |
|---|---|---|
| `InpUseMTF` | true | Ativar análise multi-timeframe |
| `InpTF1` / `InpTF2` / `InpTF3` | Atual / H1 / H4 | Timeframes combinados |
| `InpMTFWeight1/2/3` | 0.5 / 0.3 / 0.2 | Pesos de cada timeframe |

### Filtro de Kalman
| Parâmetro | Default | Descrição |
|---|---|---|
| `InpUseKalman` | true | Ativar suavização Kalman |
| `InpKalmanQ` | 0.001 | Process noise (responsividade) |
| `InpKalmanR` | 0.1 | Measurement noise (suavidade) |

### Validação estatística
| Parâmetro | Default | Descrição |
|---|---|---|
| `InpMinRSquared` | 0.65 | R² mínimo para plotar a linha |
| `InpMinConfidence` | 80.0 | Confiança mínima (%) |
| `InpShowConfidence` | true | Plotar bandas de confiança |

### Detecção de inflexão
| Parâmetro | Default | Descrição |
|---|---|---|
| `InpDetectInflection` | true | Detectar pontos de reversão |
| `InpInflectionBars` | 3 | Barras para confirmar mudança |
| `InpInflectionStrength` | 1.5 | Força mínima da inflexão |
| `InpConfirmWithPrice` | true | Exigir confirmação do preço |

### Filtro de sinais falsos
| Parâmetro | Default | Descrição |
|---|---|---|
| `InpFilterWhipsaw` | true | Filtrar whipsaws |
| `InpMinBarsBetweenSignals` | 10 | Mínimo de barras entre sinais |
| `InpMinAngleChange` | 15.0 | Mudança angular mínima (graus) |

---

## Como funciona

```
Preços + Volume
      │
      ▼
┌────────────────────────────────┐
│ 1. Período Adaptativo (ATR)    │  ◄── volatilidade ajusta janela
└────────────────────────────────┘
      │
      ▼
┌────────────────────────────────┐
│ 2. Regressão Linear Ponderada  │  ◄── peso por volume + recência
└────────────────────────────────┘
      │  slope, intercept, R², stdError
      ▼
┌────────────────────────────────┐
│ 3. Filtro de Kalman            │  ◄── reduz ruído
└────────────────────────────────┘
      │
      ▼
┌────────────────────────────────┐
│ 4. Combinação Multi-Timeframe  │  ◄── TF1 + TF2 + TF3 ponderados
└────────────────────────────────┘
      │
      ▼
┌────────────────────────────────┐
│ 5. Score de Regime (ADX + R²)  │  ◄── trending vs ranging
└────────────────────────────────┘
      │
      ▼
┌────────────────────────────────┐
│ 6. Confiança Estatística       │
└────────────────────────────────┘
      │
      ├── confiança ≥ mínimo? ──► PLOTA linha + bandas
      │
      └── inflexão confirmada? ──► EMITE sinal de reversão
```

### Cálculo da regressão ponderada

Em cada barra, o indicador calcula:

$$\text{slope} = \frac{\sum w \cdot \sum w x y - \sum w x \cdot \sum w y}{\sum w \cdot \sum w x^2 - (\sum w x)^2}$$

onde $w$ é o peso combinado (volume × decaimento exponencial recente). O R² é então calculado como:

$$R^2 = 1 - \frac{\sum w \cdot (y - \hat{y})^2}{\sum w \cdot y^2 - (\sum w y)^2 / \sum w}$$

### Filtro de Kalman (1D)

Para cada nova medida:
- **Predict:** `p = p + Q`
- **Update:** `K = p / (p + R)`, `x = x + K * (z - x)`, `p = (1 - K) * p`

Onde `Q` controla a responsividade e `R` controla a suavidade.

---

## Aviso

Este indicador foi desenvolvido para fins **educacionais e de estudo**. Não constitui recomendação de investimento e não garante resultados financeiros. Operações no mercado financeiro envolvem risco de perda. Use em conta demo antes de qualquer aplicação em conta real, e nunca arrisque mais do que pode perder.

---

## Licença

Distribuído sob a [Licença MIT](LICENSE).

---

## Autor

**Hugo Pereira de Sousa**

Estudante de Ciência de Dados e Inteligência Artificial — IESB (Brasília-DF). Foco em análise de dados, IA aplicada e indicadores quantitativos para mercado financeiro.

- LinkedIn: [hugo-sousa-901b2b342](https://www.linkedin.com/in/hugo-sousa-901b2b342)
- GitHub: [@hugopsousa-dev](https://github.com/hugopsousa-dev)
