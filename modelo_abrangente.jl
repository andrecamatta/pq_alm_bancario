using JuMP
using HiGHS
using DataFrames
using Printf

# Abrir arquivo para salvar a saída
output_file = open("resultado_alm_bancario.txt", "w")

println(output_file, "=== MODELO ALM BANCÁRIO: OTIMIZAÇÃO INTEGRADA DE ATIVOS E PASSIVOS ===\n")

# 1. Modelando os ATIVOS
ativos_df = DataFrame(
    ativo = ["Caixa", "Titulos_Gov_BR_Curto", "Titulos_Gov_BR_Longo", "Credito_Privado"],
    retorno_esperado = [0.00, 0.105, 0.11, 0.21],
    fator_hqla = [1.0, 1.0, 0.85, 0.0], # Fatores HQLA para cada ativo
    fator_saida_credito = [0.0, 0.0, 0.0, 0.10], # Fator de saída de crédito em estresse
    risco_ponderado = [0.0, 0.0, 0.0, 1.0] # Risk-weighted assets para Basel
)

println(output_file, "Ativos disponíveis:")
println(output_file, ativos_df)
println(output_file)

# 2. Modelando os PASSIVOS (A Escada de Custo)
passivos_df = DataFrame(
    fonte = ["Depositos_Vista", "CDB_Varejo_Estavel", "CDB_Varejo_Instavel", "Interbank"],
    custo = [0.02, 0.11, 0.115, 0.13],
    limite_maximo = [100_000_000, 150_000_000, 50_000_000, 50_000_000],
    fator_saida_estresse = [0.05, 0.10, 0.20, 1.00], # Runoff padronizado do regulador
    fator_asf = [0.95, 0.90, 0.90, 0.00], # Available Stable Funding para NSFR
    duration = [0.5, 2.0, 1.0, 0.1] # Duration dos passivos (sensibilidade a taxa de juros)
)

println(output_file, "Fontes de funding disponíveis:")
println(output_file, passivos_df)
println(output_file)

# 3. Parâmetros do Modelo
# Capital próprio para adequação de capital
Capital_Proprio = 50_000_000 # R$ 50 milhões
fator_asf_capital = 1.0 # Capital tem 100% de estabilidade

# Custo de oportunidade do capital próprio (ex: 20% a.a.)
custo_capital_proprio = 0.20

# Adicionar fator RSF aos ativos para NSFR
ativos_df.fator_rsf = [0.0, 0.05, 0.05, 0.85] # Required Stable Funding

# Adicionar duration aos ativos (sensibilidade a taxa de juros em anos)
ativos_df.duration = [0.0, 1.0, 5.0, 3.0] # Caixa (0), Títulos Curto (1), Títulos Longo (5), Crédito (3)

# Adicionar inflows para LCR (entradas de caixa em cenário de estresse)
ativos_df.fator_inflow = [0.0, 0.0, 0.0, 0.15] # 15% do crédito privado gera inflows

# Adicionar limites máximos para concentração de ativos
ativos_df.limite_maximo = [Inf, Inf, Inf, 400_000_000] # Limite de R$ 400M para crédito privado

# Adicionar custos operacionais por tipo de ativo (% sobre valor alocado)
ativos_df.custos_operacionais = [0.0, 0.002, 0.002, 0.015] # 1.5% sobre crédito

# Custo administrativo fixo (independente do tamanho do balanço)
custo_administrativo_fixo = 8_000_000 # R$ 8 milhões por ano

# Adicionar provisões para perdas esperadas (% sobre valor alocado)
ativos_df.provisoes_perdas = [0.0, 0.0, 0.0, 0.025] # 2.5% sobre crédito

# Parâmetro mínimo de adequação de capital (Basel)
minimo_capital_adequacao = 0.115 # 11.5%

# Reserva de capital para risco operacional (% do total de ativos)
reserva_risco_operacional = 0.015 # 1.5% dos ativos totais

# Limites para Duration Gap (controle de risco de taxa de juros)
limite_duration_gap_min = -1.5 # Mínimo -1.5 anos
limite_duration_gap_max = 1.5  # Máximo +1.5 anos
duration_capital_proprio = 0.0 # Capital próprio tem duration zero

# Capital para risco de mercado baseado no Duration Gap
fator_capital_risco_mercado = 0.02 # 2% dos ativos para cada ano de Duration Gap absoluto

# Parâmetro mínimo NSFR
minimo_nsfr = 1.0 # 100%

# Alíquota de impostos (IR + CSLL)
aliquota_impostos = 0.40 # 40%

println(output_file, "Parâmetros regulatórios:")
@printf(output_file, "Capital Próprio: R\$ %.2f\n", Capital_Proprio)
@printf(output_file, "Custo de Capital Próprio: %.1f%%\n", custo_capital_proprio * 100)
@printf(output_file, "Mínimo Capital Adequação: %.1f%%\n", minimo_capital_adequacao * 100)
@printf(output_file, "Reserva Risco Operacional: %.1f%% dos ativos\n", reserva_risco_operacional * 100)
@printf(output_file, "Mínimo NSFR: %.0f%%\n", minimo_nsfr * 100)
@printf(output_file, "Duration Gap Permitido: %.1f a %.1f anos\n", limite_duration_gap_min, limite_duration_gap_max)
@printf(output_file, "Capital Risco Mercado: %.1f%% dos ativos por ano de Duration Gap\n\n", fator_capital_risco_mercado * 100)

# 4. Construção do Modelo
model = Model(HiGHS.Optimizer)
set_silent(model)  # Para reduzir output do solver

n_ativos = nrow(ativos_df)
n_passivos = nrow(passivos_df)

# 5. Variáveis de Decisão
@variable(model, alocacao[i=1:n_ativos], lower_bound=0, upper_bound=ativos_df.limite_maximo[i])
@variable(model, funding[i=1:n_passivos], lower_bound=0, upper_bound=passivos_df.limite_maximo[i])

# 6. Função Objetivo: Maximizar o EVA (Valor Econômico Adicionado)
retorno_total_ativos = ativos_df.retorno_esperado' * alocacao
custo_total_passivos = passivos_df.custo' * funding
# Custos operacionais e provisões
custos_operacionais_total = ativos_df.custos_operacionais' * alocacao
provisoes_total = ativos_df.provisoes_perdas' * alocacao
# Custo de capital aplicado sobre capital alocado para RWA + reserva operacional + risco mercado
rwa_total_variavel = ativos_df.risco_ponderado' * alocacao
capital_alocado_rwa = rwa_total_variavel * minimo_capital_adequacao
capital_alocado_operacional = reserva_risco_operacional * sum(alocacao)

# Capital para risco de mercado baseado na diferença absoluta de duration ponderada
# Usamos variáveis auxiliares para linearizar o valor absoluto do duration gap
@variable(model, duration_gap_pos >= 0)
@variable(model, duration_gap_neg >= 0)
duration_ponderada_ativos_obj = ativos_df.duration' * alocacao
duration_ponderada_passivos_obj = passivos_df.duration' * funding + duration_capital_proprio * Capital_Proprio
@constraint(model, c_duration_gap_decomp, duration_ponderada_ativos_obj - duration_ponderada_passivos_obj == duration_gap_pos - duration_gap_neg)
capital_alocado_mercado = fator_capital_risco_mercado * (duration_gap_pos + duration_gap_neg)

capital_alocado_total = capital_alocado_rwa + capital_alocado_operacional + capital_alocado_mercado
custo_capital = capital_alocado_total * custo_capital_proprio
# EVA antes de impostos
eva_antes_impostos = retorno_total_ativos - custo_total_passivos - custos_operacionais_total - provisoes_total - custo_capital - custo_administrativo_fixo
# EVA após impostos
eva_apos_impostos = eva_antes_impostos * (1 - aliquota_impostos)
@objective(model, Max, eva_apos_impostos)

# 7. Restrições (Constraints)

# 7a. Equilíbrio do Balanço (incluindo capital próprio)
@constraint(model, c_balanco, sum(alocacao) == sum(funding) + Capital_Proprio)

# 7b. LCR Refinado: (HQLA + Inflows) deve cobrir Outflows líquidos
hqla_total = ativos_df.fator_hqla' * alocacao
saidas_funding_tesouraria = passivos_df.fator_saida_estresse' * funding
saidas_credito_dinamico = ativos_df.fator_saida_credito' * alocacao
inflows_total = ativos_df.fator_inflow' * alocacao

# LCR = (HQLA + Inflows) / Outflows >= 100%
outflows_total = saidas_funding_tesouraria + saidas_credito_dinamico
recursos_liquidos = hqla_total + inflows_total

@constraint(model, c_lcr_refinado, recursos_liquidos >= outflows_total)

# 7c. Adequação de Capital (Basel) - Capital deve cobrir todos os riscos separadamente
rwa_total = ativos_df.risco_ponderado' * alocacao
total_ativos = sum(alocacao)

# Requerimentos de capital por tipo de risco
req_capital_credito = minimo_capital_adequacao * rwa_total
req_capital_operacional = reserva_risco_operacional * total_ativos  
req_capital_mercado = fator_capital_risco_mercado * (duration_gap_pos + duration_gap_neg)
req_capital_total = req_capital_credito + req_capital_operacional + req_capital_mercado

@constraint(model, c_basileia, Capital_Proprio >= req_capital_total)

# 7d. NSFR - Funding estável deve cobrir necessidades de funding estável
asf_total = passivos_df.fator_asf' * funding + fator_asf_capital * Capital_Proprio
rsf_total = ativos_df.fator_rsf' * alocacao
@constraint(model, c_nsfr, asf_total >= minimo_nsfr * rsf_total)

# 7e. Duration Gap Refinado - Controle preciso de risco de taxa de juros
# Duration Gap = (Σ Duration_i × Ativo_i - Σ Duration_j × Passivo_j) / Total_Balanço
# Formulação linear: Duration_Ativos_Ponderada - Duration_Passivos_Ponderada em limites absolutos

duration_ponderada_ativos = ativos_df.duration' * alocacao
duration_ponderada_passivos = passivos_df.duration' * funding + duration_capital_proprio * Capital_Proprio
total_balanco = sum(alocacao)

# Restrições de Duration Gap como diferença absoluta normalizada pelo balanço
@constraint(model, c_duration_gap_min, duration_ponderada_ativos - duration_ponderada_passivos >= limite_duration_gap_min * total_balanco)
@constraint(model, c_duration_gap_max, duration_ponderada_ativos - duration_ponderada_passivos <= limite_duration_gap_max * total_balanco)

# 8. Resolver e Analisar
optimize!(model)

if termination_status(model) == OPTIMAL
    println(output_file, "Status da Otimização: Solução ótima encontrada!")
    
    # Cálculo detalhado do EVA
    rwa_calculado = ativos_df.risco_ponderado' * value.(alocacao)
    total_ativos_calculado = sum(value.(alocacao))
    capital_alocado_rwa_calculado = rwa_calculado * minimo_capital_adequacao
    capital_alocado_operacional_calculado = reserva_risco_operacional * total_ativos_calculado
    capital_alocado_mercado_calculado = fator_capital_risco_mercado * (value(duration_gap_pos) + value(duration_gap_neg))
    capital_alocado_calculado = capital_alocado_rwa_calculado + capital_alocado_operacional_calculado + capital_alocado_mercado_calculado
    capital_livre = Capital_Proprio - capital_alocado_calculado
    custo_capital_calculado = capital_alocado_calculado * custo_capital_proprio
    
    # Calcular componentes do resultado
    retorno_calculado = ativos_df.retorno_esperado' * value.(alocacao)
    custo_funding_calculado = passivos_df.custo' * value.(funding)
    custos_operacionais_calculado = ativos_df.custos_operacionais' * value.(alocacao)
    provisoes_calculado = ativos_df.provisoes_perdas' * value.(alocacao)
    
    margem_financeira = retorno_calculado - custo_funding_calculado
    eva_antes_impostos_calculado = margem_financeira - custos_operacionais_calculado - provisoes_calculado - custo_capital_calculado - custo_administrativo_fixo
    impostos_calculado = eva_antes_impostos_calculado * aliquota_impostos
    eva_apos_impostos_calculado = objective_value(model)
    
    @printf(output_file, "--- Análise de Valor Econômico Adicionado (EVA) ---\n")
    @printf(output_file, "Receita de Ativos: R\$ %.2f\n", retorno_calculado)
    @printf(output_file, "Custo de Funding: R\$ %.2f\n", custo_funding_calculado)
    @printf(output_file, "Margem Financeira: R\$ %.2f\n", margem_financeira)
    @printf(output_file, "Custos Operacionais Variáveis: R\$ %.2f\n", custos_operacionais_calculado)
    @printf(output_file, "Custos Administrativos Fixos: R\$ %.2f\n", custo_administrativo_fixo)
    @printf(output_file, "Provisões para Perdas: R\$ %.2f\n", provisoes_calculado)
    @printf(output_file, "Capital Alocado (RWA): R\$ %.2f\n", capital_alocado_rwa_calculado)
    @printf(output_file, "Capital Alocado (Risco Operacional): R\$ %.2f\n", capital_alocado_operacional_calculado)
    @printf(output_file, "Capital Alocado (Risco Mercado): R\$ %.2f\n", capital_alocado_mercado_calculado)
    @printf(output_file, "Capital Alocado Total: R\$ %.2f\n", capital_alocado_calculado)
    @printf(output_file, "Capital Livre: R\$ %.2f\n", capital_livre)
    @printf(output_file, "Custo de Capital Alocado (%.1f%%): R\$ %.2f\n", custo_capital_proprio * 100, custo_capital_calculado)
    @printf(output_file, "EVA Antes de Impostos: R\$ %.2f\n", eva_antes_impostos_calculado)
    @printf(output_file, "Impostos (%.1f%%): R\$ %.2f\n", aliquota_impostos * 100, impostos_calculado)
    @printf(output_file, "EVA Após Impostos: R\$ %.2f\n", eva_apos_impostos_calculado)
    @printf(output_file, "ROE: %.2f%%\n\n", (eva_apos_impostos_calculado / Capital_Proprio) * 100)

    tamanho_otimo_balanco = sum(value.(funding)) + Capital_Proprio
    @printf(output_file, "--- Balanço Ótimo ---\nTamanho Total: R\$ %.2f\n", tamanho_otimo_balanco)
    @printf(output_file, "Capital Próprio: R\$ %.2f\n", Capital_Proprio)

    println(output_file, "\n--- Estrutura de Passivos (Funding) ---")
    funding_otimo_df = DataFrame(
        Fonte = passivos_df.fonte,
        Valor_Captado = round.(value.(funding), digits=2),
        Percentual_Total = round.(value.(funding) / tamanho_otimo_balanco * 100, digits=2)
    )
    println(output_file, funding_otimo_df)

    println(output_file, "\n--- Estrutura de Ativos (Alocação) ---")
    alocacao_otima_df = DataFrame(
        Ativo = ativos_df.ativo,
        Valor_Alocado = round.(value.(alocacao), digits=2),
        Percentual_Total = round.(value.(alocacao) / tamanho_otimo_balanco * 100, digits=2)
    )
    println(output_file, alocacao_otima_df)
    
    # Análise da Cobertura de Liquidez Refinada
    hqla_gerado = ativos_df.fator_hqla' * value.(alocacao)
    saida_tesouraria = passivos_df.fator_saida_estresse' * value.(funding)
    saida_credito_calculada = ativos_df.fator_saida_credito' * value.(alocacao)
    inflows_calculado = ativos_df.fator_inflow' * value.(alocacao)
    saida_total_necessaria = saida_tesouraria + saida_credito_calculada
    recursos_liquidos_calculado = hqla_gerado + inflows_calculado
    
    println(output_file, "\n--- Análise de Liquidez (LCR Refinado) ---")
    @printf(output_file, "HQLA Gerado: R\$ %.2f\n", hqla_gerado)
    @printf(output_file, "Inflows de Caixa: R\$ %.2f\n", inflows_calculado)
    @printf(output_file, "Recursos Líquidos Total: R\$ %.2f\n", recursos_liquidos_calculado)
    @printf(output_file, "Saída de Caixa (Tesouraria): R\$ %.2f\n", saida_tesouraria)
    @printf(output_file, "Saída de Caixa (Crédito): R\$ %.2f\n", saida_credito_calculada)
    @printf(output_file, "Total de Saídas (Outflows): R\$ %.2f\n", saida_total_necessaria)
    @printf(output_file, "LCR Refinado: %.2f%%\n", (recursos_liquidos_calculado / saida_total_necessaria) * 100)

    # Análise de Adequação de Capital (Basel) - usar variável já calculada
    ratio_capital = Capital_Proprio / rwa_calculado
    
    println(output_file, "\n--- Análise de Adequação de Capital (Basel) ---")
    @printf(output_file, "Risk-Weighted Assets (RWA): R\$ %.2f\n", rwa_calculado)
    @printf(output_file, "Capital Próprio: R\$ %.2f\n", Capital_Proprio)
    @printf(output_file, "Ratio de Capital: %.2f%%\n", ratio_capital * 100)
    @printf(output_file, "Mínimo Requerido: %.1f%%\n", minimo_capital_adequacao * 100)

    # Análise NSFR
    asf_calculado = passivos_df.fator_asf' * value.(funding) + fator_asf_capital * Capital_Proprio
    rsf_calculado = ativos_df.fator_rsf' * value.(alocacao)
    ratio_nsfr = asf_calculado / rsf_calculado
    
    println(output_file, "\n--- Análise NSFR (Net Stable Funding Ratio) ---")
    @printf(output_file, "Available Stable Funding (ASF): R\$ %.2f\n", asf_calculado)
    @printf(output_file, "Required Stable Funding (RSF): R\$ %.2f\n", rsf_calculado)
    @printf(output_file, "Ratio NSFR: %.2f%%\n", ratio_nsfr * 100)
    @printf(output_file, "Mínimo Requerido: %.0f%%\n", minimo_nsfr * 100)
    
    # Análise Duration Gap (Risco de Taxa de Juros)
    # total_ativos_calculado já foi definido acima
    total_passivos_calculado = sum(value.(funding)) + Capital_Proprio
    duration_media_ativos_calculado = (ativos_df.duration' * value.(alocacao)) / total_ativos_calculado
    duration_media_passivos_calculado = (passivos_df.duration' * value.(funding) + duration_capital_proprio * Capital_Proprio) / total_passivos_calculado
    duration_gap_calculado = duration_media_ativos_calculado - duration_media_passivos_calculado
    
    println(output_file, "\n--- Análise Duration Gap (Risco de Taxa de Juros) ---")
    @printf(output_file, "Duration Média dos Ativos: %.2f anos\n", duration_media_ativos_calculado)
    @printf(output_file, "Duration Média dos Passivos: %.2f anos\n", duration_media_passivos_calculado)
    @printf(output_file, "Duration Gap: %.2f anos\n", duration_gap_calculado)
    @printf(output_file, "Limite Mínimo: %.1f anos\n", limite_duration_gap_min)
    @printf(output_file, "Limite Máximo: %.1f anos\n", limite_duration_gap_max)
    
    # Análise de sensibilidade a taxa de juros (impacto no EVE com choque de 2%)
    choque_taxa = 0.02 # 2%
    impacto_eve_percent = -duration_gap_calculado * choque_taxa * 100
    impacto_eve_valor = (total_ativos_calculado * impacto_eve_percent / 100)
    
    @printf(output_file, "\n--- Impacto de Choque de Taxa (+2%%) no EVE ---\n")
    @printf(output_file, "Impacto no EVE: %.2f%% do total de ativos\n", impacto_eve_percent)
    @printf(output_file, "Impacto no EVE: R\$ %.2f\n", impacto_eve_valor)
    
    # Retornar valores para comparação
    return Dict(
        "eva" => objective_value(model),
        "margem_financeira" => margem_financeira,
        "custo_capital" => custo_capital_calculado,
        "capital_alocado" => capital_alocado_calculado,
        "capital_livre" => capital_livre,
        "tamanho_balanco" => tamanho_otimo_balanco,
        "hqla_total" => hqla_gerado,
        "inflows_total" => inflows_calculado,
        "recursos_liquidos" => recursos_liquidos_calculado,
        "saidas_tesouraria" => saida_tesouraria,
        "saidas_credito" => saida_credito_calculada,
        "saidas_total" => saida_total_necessaria,
        "lcr_refinado" => (recursos_liquidos_calculado / saida_total_necessaria) * 100,
        "rwa_total" => rwa_calculado,
        "ratio_capital" => ratio_capital * 100,
        "asf_total" => asf_calculado,
        "rsf_total" => rsf_calculado,
        "ratio_nsfr" => ratio_nsfr * 100,
        "duration_media_ativos" => duration_media_ativos_calculado,
        "duration_media_passivos" => duration_media_passivos_calculado,
        "duration_gap" => duration_gap_calculado,
        "impacto_eve_percent" => impacto_eve_percent,
        "impacto_eve_valor" => impacto_eve_valor,
        "reserva_operacional" => reserva_risco_operacional * total_ativos_calculado,
        "capital_alocado_mercado" => capital_alocado_mercado_calculado,
        "funding_otimo" => value.(funding),
        "alocacao_otima" => value.(alocacao)
    )

else
    println(output_file, "Status da Otimização: ", termination_status(model))
    return nothing
end

# Fechar o arquivo
close(output_file)
println("Resultados salvos em: resultado_alm_bancario.txt")