# Modelo ALM Bancário - Otimização Integrada dos 3 Pilares de Risco

## Descrição

Este projeto implementa um modelo **completo e avançado** de **Asset-Liability Management (ALM)** para instituições bancárias, integrando os **3 pilares de risco de Basileia** (crédito, operacional e mercado) em uma otimização unificada que maximiza o **Valor Econômico Adicionado (EVA)** considerando o custo de capital de todos os riscos.

O modelo incorpora **padrões regulatórios brasileiros** para risco de taxa de juros, incluindo **Risco de Base** (hedges imperfeitos) e limites de Duration Gap calibrados para o mercado nacional, oferecendo uma solução realista e aplicável para instituições financeiras brasileiras.

## Características do Modelo

O modelo considera os seguintes aspectos bancários:

### Ativos Disponíveis (com Duration)
- **Caixa**: Liquidez imediata, duration 0 anos
- **Títulos Governamentais de Curto Prazo**: Alta liquidez, duration 0,8 anos, retorno 10,5%
- **Títulos Governamentais de Longo Prazo**: Liquidez moderada, duration 4,5 anos, retorno 11%
- **Crédito Privado**: Alto retorno (18%), duration 2,8 anos, RWA 100%

### Fontes de Funding (com Duration Otimizada)
- **Depósitos à Vista**: Custo 2%, duration 0,4 anos, ASF 95%
- **CDB Varejo Estável**: Custo 11%, duration 2,5 anos, ASF 90%
- **CDB Varejo Instável**: Custo 11,5%, duration 0,9 anos, ASF 90%
- **Interbancário**: Custo 13%, duration 0,1 anos, ASF 0%

### Integração Completa dos 3 Pilares de Risco

#### 🎯 **1. Risco de Crédito**
- **RWA (Risk-Weighted Assets)**: 100% para crédito privado
- **Capital mínimo**: 11,5% dos RWA (Basileia III)
- **Provisões**: 2,5% do crédito para perdas esperadas
- **Limite de concentração**: R$ 400M máximo em crédito

#### 🏭 **2. Risco Operacional**
- **Reserva de capital**: 1,5% do total de ativos
- **Custos operacionais**: 1,5% sobre crédito + custos fixos R$ 8M
- **Metodologia**: Abordagem do Indicador Básico (BIA)

#### 📈 **3. Risco de Mercado (Taxa de Juros)**
- **Duration Gap**: Controlado entre -1,0 e +1,0 anos (padrão brasileiro)
- **Capital de risco**: 1,5% dos ativos × |Duration Gap| (calibrado para Brasil)
- **Risco de Base**: 8% de capital sobre exposição a hedges imperfeitos
- **Análise de choque**: Impacto de +2% nas taxas sobre EVE
- **Sensibilidade**: Medição precisa da exposição à taxa de juros

### Restrições Regulatórias Avançadas

1. **LCR Refinado (Liquidity Coverage Ratio)**
   - (HQLA + Inflows) ≥ 100% dos Outflows líquidos
   - Inclui inflows de crédito (15% em cenário estresse)
   
2. **NSFR (Net Stable Funding Ratio)**
   - Available Stable Funding ≥ 100% Required Stable Funding
   - Considera fatores ASF e RSF por instrumento

3. **Adequação de Capital Integrada**
   - Capital ≥ Req. Crédito + Req. Operacional + Req. Mercado
   - Decomposição clara por tipo de risco

4. **Duration Gap Management**
   - Limites dinâmicos baseados no perfil de risco
   - Otimização do balanço considerando sensibilidade a juros

## Tecnologias Utilizadas

- **Julia**: Linguagem de programação
- **JuMP.jl**: Framework de otimização matemática
- **HiGHS**: Solver de programação linear
- **DataFrames.jl**: Manipulação de dados estruturados

## Como Executar

### Pré-requisitos
- Julia 1.6 ou superior
- Pacotes Julia: JuMP, HiGHS, DataFrames, Printf

### Instalação das Dependências
```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

### Execução do Modelo
```bash
julia modelo_abrangente.jl
```

### Saída
O modelo gera um arquivo `resultado_alm_bancario.txt` contendo:
- **Análise de EVA**: Receitas, custos, margem financeira e ROE
- **Decomposição de Capital**: Alocação por tipo de risco (crédito, operacional, mercado)
- **Estrutura Ótima**: Composição de ativos e passivos
- **Indicadores Regulatórios**: LCR refinado, NSFR, adequação de capital
- **Duration Gap Analysis**: Sensibilidade a taxa de juros e impacto no EVE
- **Análise de Risco de Base**: Exposição a hedges imperfeitos e capital requerido
- **Análise de Liquidez**: HQLA, inflows, outflows e recursos líquidos

## Estrutura do Projeto

```
pq_alm_bancario/
├── README.md                    # Este arquivo
├── Project.toml                 # Dependências do Julia
├── Manifest.toml               # Versões específicas dos pacotes
├── modelo_abrangente.jl        # Código principal do modelo ALM
└── resultado_alm_bancario.txt  # Arquivo de saída com resultados
```

## Funcionalidades Avançadas do Modelo

### 🎯 **Otimização Integrada de Valor**
- **Maximização do EVA**: Considera custo de capital de todos os riscos
- **ROE otimizado**: Equilibra retorno e consumo de capital
- **Trade-off risk-return**: Análise sofisticada de valor vs risco

### 📊 **Gestão Avançada de Riscos**
- **3 Pilares Integrados**: Crédito, operacional e mercado em modelo único
- **Duration Matching**: Otimização da sensibilidade a taxa de juros
- **Risco de Base**: Modelagem de hedges imperfeitos com fatores por instrumento
- **Capital Allocation**: Alocação eficiente entre tipos de risco
- **Padrões Brasileiros**: Limites e fatores calibrados para o mercado nacional

### 💧 **Liquidez Sofisticada**
- **LCR Refinado**: Inclui inflows realistas de caixa
- **NSFR Dinâmico**: Considera estabilidade de cada fonte
- **Stress Testing**: Cenários de liquidez adversos

### 📈 **Análises Estratégicas**
- **Sensitivity Analysis**: Impacto de choques nas taxas de juros
- **Risco de Base**: Modelagem de hedges imperfeitos
- **Duration Gap Management**: Otimização de risco de taxa de juros
- **Capital Stress**: Simulação de cenários de capital
- **Scenario Planning**: Múltiplos cenários econômicos

## Parâmetros Configuráveis

### 📊 **Parâmetros de Mercado**
- Retornos esperados dos ativos (10,5% - 18%)
- Custos das fontes de funding (2% - 13%)
- Durations otimizadas dos ativos e passivos
- Fatores de inflow de liquidez
- Fatores de risco de base por instrumento

### ⚖️ **Parâmetros Regulatórios**
- Índices mínimos de capital (11,5%)
- Reserva para risco operacional (1,5%)
- Fator de capital para risco de mercado (1,5% - padrão brasileiro)
- Limites de Duration Gap (-1,0 a +1,0 anos - padrão brasileiro)
- Capital para risco de base (8% sobre hedges imperfeitos)
- Fatores LCR e NSFR por instrumento

### 🎯 **Parâmetros de Gestão**
- Custo de capital próprio (15%)
- Alíquota de impostos (40%)
- Limites de concentração por ativo
- Cenários de estresse customizáveis

## Resultados Típicos

### 💰 **Métricas de Performance**
- **ROE**: ~16,3% (otimizado com restrições de risco)
- **EVA**: R$ 3,7M+ (valor econômico após custo de capital)
- **Margem Financeira**: R$ 32M+ (spread otimizado)

### 📊 **Distribuição de Capital**
- **Risco de Crédito**: ~67% do capital (R$ 30,5M)
- **Risco de Mercado**: ~21% do capital (R$ 9,5M)  
  - Risco de Prazo (Duration Gap): R$ 5,25M
  - Risco de Base (Hedges Imperfeitos): R$ 4,27M
- **Risco Operacional**: ~12% do capital (R$ 5,25M)

### 🎯 **Indicadores Regulatórios**
- **LCR Refinado**: 220%+ (bem acima do mínimo 100%)
- **NSFR**: 142%+ (funding estável adequado)
- **Índice de Capital**: 18,9%+ (robusto vs mínimo 11,5%)

## Uso Prático

### 🏦 **Para Instituições Financeiras**
- **Tesourarias**: Otimização estratégica de ALM integrada com padrões brasileiros
- **Áreas de Risco**: Análise de adequação aos 3 pilares incluindo risco de base
- **ALCO**: Suporte a decisões de comitê com métricas de EVA
- **Planejamento**: Simulação de cenários e stress tests realistas

### 🎓 **Para Pesquisa e Ensino**
- **Universidades**: Modelo educacional completo de ALM
- **Pesquisa**: Base para estudos de otimização bancária
- **Treinamento**: Ferramenta prática para capacitação
- **Benchmarking**: Comparação com modelos proprietários

## Contribuição

Para contribuir com o projeto:
1. Faça um fork do repositório
2. Crie uma branch para sua feature
3. Faça commit das mudanças
4. Abra um Pull Request

## Licença

Este projeto está disponível sob licença MIT. Veja o arquivo LICENSE para mais detalhes.

---

**Desenvolvido por**: André Camatta  
**Linguagem**: Julia  
**Área**: Asset-Liability Management Bancário