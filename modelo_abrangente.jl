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
    fator_asf = [0.95, 0.90, 0.90, 0.00] # Available Stable Funding para NSFR
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

# Parâmetro mínimo NSFR
minimo_nsfr = 1.0 # 100%

# Alíquota de impostos (IR + CSLL)
aliquota_impostos = 0.40 # 40%

println(output_file, "Parâmetros regulatórios:")
@printf(output_file, "Capital Próprio: R\$ %.2f\n", Capital_Proprio)
@printf(output_file, "Custo de Capital Próprio: %.1f%%\n", custo_capital_proprio * 100)
@printf(output_file, "Mínimo Capital Adequação: %.1f%%\n", minimo_capital_adequacao * 100)
@printf(output_file, "Mínimo NSFR: %.0f%%\n\n", minimo_nsfr * 100)

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
# Custo de capital aplicado apenas sobre capital alocado para ativos de risco
rwa_total_variavel = ativos_df.risco_ponderado' * alocacao
capital_alocado = rwa_total_variavel * minimo_capital_adequacao
custo_capital = capital_alocado * custo_capital_proprio
# EVA antes de impostos
eva_antes_impostos = retorno_total_ativos - custo_total_passivos - custos_operacionais_total - provisoes_total - custo_capital - custo_administrativo_fixo
# EVA após impostos
eva_apos_impostos = eva_antes_impostos * (1 - aliquota_impostos)
@objective(model, Max, eva_apos_impostos)

# 7. Restrições (Constraints)

# 7a. Equilíbrio do Balanço (incluindo capital próprio)
@constraint(model, c_balanco, sum(alocacao) == sum(funding) + Capital_Proprio)

# 7b. LCR Abrangente: HQLA deve cobrir as saídas da tesouraria + as saídas do crédito (agora dinâmico)
hqla_total = ativos_df.fator_hqla' * alocacao
saidas_funding_tesouraria = passivos_df.fator_saida_estresse' * funding
saidas_credito_dinamico = ativos_df.fator_saida_credito' * alocacao

@constraint(model, c_lcr_abrangente, hqla_total >= saidas_funding_tesouraria + saidas_credito_dinamico)

# 7c. Adequação de Capital (Basel) - Capital deve cobrir risco dos ativos
rwa_total = ativos_df.risco_ponderado' * alocacao
@constraint(model, c_basileia, Capital_Proprio >= minimo_capital_adequacao * rwa_total)

# 7d. NSFR - Funding estável deve cobrir necessidades de funding estável
asf_total = passivos_df.fator_asf' * funding + fator_asf_capital * Capital_Proprio
rsf_total = ativos_df.fator_rsf' * alocacao
@constraint(model, c_nsfr, asf_total >= minimo_nsfr * rsf_total)

# 8. Resolver e Analisar
optimize!(model)

if termination_status(model) == OPTIMAL
    println(output_file, "Status da Otimização: Solução ótima encontrada!")
    
    # Cálculo detalhado do EVA
    rwa_calculado = ativos_df.risco_ponderado' * value.(alocacao)
    capital_alocado_calculado = rwa_calculado * minimo_capital_adequacao
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
    
    # Análise da Cobertura de Liquidez
    hqla_gerado = ativos_df.fator_hqla' * value.(alocacao)
    saida_tesouraria = passivos_df.fator_saida_estresse' * value.(funding)
    saida_credito_calculada = ativos_df.fator_saida_credito' * value.(alocacao)
    saida_total_necessaria = saida_tesouraria + saida_credito_calculada
    
    println(output_file, "\n--- Análise de Liquidez (LCR) ---")
    @printf(output_file, "HQLA Gerado: R\$ %.2f\n", hqla_gerado)
    @printf(output_file, "Saída de Caixa (Tesouraria): R\$ %.2f\n", saida_tesouraria)
    @printf(output_file, "Saída de Caixa (Crédito - Dinâmico): R\$ %.2f\n", saida_credito_calculada)
    @printf(output_file, "Total de Saídas a Cobrir: R\$ %.2f\n", saida_total_necessaria)
    @printf(output_file, "LCR Efetivo: %.2f%%\n", (hqla_gerado / saida_total_necessaria) * 100)

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
    
    # Retornar valores para comparação
    return Dict(
        "eva" => objective_value(model),
        "margem_financeira" => margem_financeira,
        "custo_capital" => custo_capital_calculado,
        "capital_alocado" => capital_alocado_calculado,
        "capital_livre" => capital_livre,
        "tamanho_balanco" => tamanho_otimo_balanco,
        "hqla_total" => hqla_gerado,
        "saidas_tesouraria" => saida_tesouraria,
        "saidas_credito" => saida_credito_calculada,
        "saidas_total" => saida_total_necessaria,
        "lcr" => (hqla_gerado / saida_total_necessaria) * 100,
        "rwa_total" => rwa_calculado,
        "ratio_capital" => ratio_capital * 100,
        "asf_total" => asf_calculado,
        "rsf_total" => rsf_calculado,
        "ratio_nsfr" => ratio_nsfr * 100,
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