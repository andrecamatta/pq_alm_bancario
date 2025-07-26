# Modelo ALM Bancário - Otimização Integrada de Ativos e Passivos

## Descrição

Este projeto implementa um modelo abrangente de **Asset-Liability Management (ALM)** para instituições bancárias, utilizando programação linear para otimizar a composição de ativos e passivos considerando múltiplas restrições regulatórias e de risco.

## Características do Modelo

O modelo considera os seguintes aspectos bancários:

### Ativos Disponíveis
- **Caixa**: Liquidez imediata
- **Títulos Governamentais de Curto Prazo**: Alta liquidez, baixo retorno
- **Títulos Governamentais de Longo Prazo**: Liquidez moderada, retorno médio
- **Crédito Privado**: Baixa liquidez, alto retorno

### Fontes de Funding
- **Depósitos à Vista**: Custo baixo, alta estabilidade
- **CDB Varejo Estável**: Custo moderado, boa estabilidade
- **CDB Varejo Instável**: Custo moderado, menor estabilidade
- **Interbancário**: Custo alto, baixa estabilidade

### Restrições Regulatórias Implementadas

1. **Índice de Cobertura de Liquidez (LCR)**
   - Ativos líquidos de alta qualidade (HQLA) ≥ 100% das saídas líquidas em 30 dias

2. **Índice de Financiamento Estável Líquido (NSFR)**
   - Financiamento estável disponível ≥ 100% do financiamento estável requerido

3. **Adequação de Capital (Basel III)**
   - Índice de capital ≥ 10.5% dos ativos ponderados por risco

4. **Limite de Concentração**
   - Exposição máxima a crédito privado limitada

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
- Configuração dos ativos e passivos
- Parâmetros do modelo
- Solução ótima encontrada
- Verificação das restrições regulatórias
- Análise detalhada dos resultados

## Estrutura do Projeto

```
pq_alm_bancario/
├── README.md                    # Este arquivo
├── Project.toml                 # Dependências do Julia
├── Manifest.toml               # Versões específicas dos pacotes
├── modelo_abrangente.jl        # Código principal do modelo ALM
└── resultado_alm_bancario.txt  # Arquivo de saída com resultados
```

## Funcionalidades do Modelo

- **Otimização de Portfólio**: Maximiza o spread líquido (receitas - custos)
- **Gestão de Liquidez**: Atende aos requisitos LCR e NSFR
- **Adequação de Capital**: Mantém índices de capital adequados
- **Análise de Sensibilidade**: Permite ajustar parâmetros e cenários
- **Relatórios Detalhados**: Gera análise completa da solução

## Parâmetros Configuráveis

O modelo permite ajustar:
- Retornos esperados dos ativos
- Custos das fontes de funding
- Limites máximos de exposição
- Fatores de risco regulatórios
- Cenários de estresse de liquidez

## Uso Prático

Este modelo pode ser utilizado por:
- **Tesourarias Bancárias**: Para otimização diária de ALM
- **Áreas de Risco**: Para análise de adequação regulatória
- **Planejamento Estratégico**: Para simulação de cenários
- **Pesquisa Acadêmica**: Como base para estudos de ALM bancário

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