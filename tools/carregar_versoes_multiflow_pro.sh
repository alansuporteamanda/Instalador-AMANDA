#!/bin/bash
# Carrega versão|commit de tools/versoes_multiflow_pro.conf para um array associativo global.
# Uso: source este arquivo; mf_carregar_versoes_no_array VERSOES_INSTALACAO
#      ou mf_carregar_versoes_no_array VERSOES

# Aviso exibido na opção [0] Mais Recente (instalação, FAST, atualização completa).
MF_AVISO_OPCAO_MAIS_RECENTE="( Versão DEMO para Homologação )"

# True se a instância deve mostrar o menu de versões (versoes_multiflow_pro.conf).
# Apenas multiflow-pro (repo_url ou remote origin).
mf_repo_usa_menu_versoes() {
  local repo="${1:-${repo_url:-}}"
  local emp="${2:-${empresa:-}}"
  local origin=""
  if echo "$repo" | grep -Eq "scriptswhitelabel/multiflow-pro"; then
    return 0
  fi
  if [ -n "$emp" ] && [ -d "/home/deploy/${emp}/.git" ]; then
    origin=$(git -c "safe.directory=/home/deploy/${emp}" -C "/home/deploy/${emp}" remote get-url origin 2>/dev/null || true)
    echo "$origin" | grep -Eq "scriptswhitelabel/multiflow-pro" && return 0
  fi
  return 1
}

mf_arquivo_versoes_multiflow_pro() {
  if [ -n "${INSTALADOR_DIR:-}" ] && [ -f "${INSTALADOR_DIR}/tools/versoes_multiflow_pro.conf" ]; then
    printf '%s\n' "${INSTALADOR_DIR}/tools/versoes_multiflow_pro.conf"
    return 0
  fi
  printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/versoes_multiflow_pro.conf"
}

# $1 = nome do array associativo (ex.: VERSOES_INSTALACAO ou VERSOES). Retorna 0 se leu pelo menos uma entrada.
mf_carregar_versoes_no_array() {
  local arr="$1"
  local arr_rotulo="${arr}_ROTULO"
  local conf n=0
  conf="$(mf_arquivo_versoes_multiflow_pro)"
  [ ! -f "$conf" ] && return 1
  eval "unset ${arr} 2>/dev/null; declare -gA ${arr}"
  eval "unset ${arr_rotulo} 2>/dev/null; declare -gA ${arr_rotulo}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    [[ "$line" != *'|'* ]] && continue
    local ver commit rotulo rest
    ver="${line%%|*}"
    rest="${line#*|}"
    if [[ "$rest" == *'|'* ]]; then
      commit="${rest%%|*}"
      rotulo="${rest#*|}"
    else
      commit="$rest"
      rotulo=""
    fi
    ver="${ver%"${ver##*[![:space:]]}"}"; ver="${ver#"${ver%%[![:space:]]*}"}"
    commit="${commit%"${commit##*[![:space:]]}"}"; commit="${commit#"${commit%%[![:space:]]*}"}"
    rotulo="${rotulo%"${rotulo##*[![:space:]]}"}"; rotulo="${rotulo#"${rotulo%%[![:space:]]*}"}"
    [[ -z "$ver" || -z "$commit" ]] && continue
    eval "${arr}[\"\${ver}\"]=\"\${commit}\""
    eval "${arr_rotulo}[\"\${ver}\"]=\"\${rotulo}\""
    n=$((n + 1))
  done < "$conf"
  [ "$n" -gt 0 ]
}

# Exibe rótulo opcional antes do número da versão no menu (ex.: ( Estável )).
mf_exibir_rotulo_versao_menu() {
  local ver="$1"
  local arr_base="${2:-VERSOES_INSTALACAO}"
  local rotulo=""
  eval "rotulo=\${${arr_base}_ROTULO[$ver]:-}"
  [ -n "$rotulo" ] && printf "${YELLOW}( %s ) ${WHITE}" "$rotulo"
}

# ================================================================
# SELEÇÃO DE CANAL / BRANCH AMANDA (Estável vs Desenvolvimento)
# ================================================================
selecionar_canal_branch_amanda() {
  local motivo="${1:-a atualização}"
  banner 2>/dev/null || true
  printf "   \033[1;35m╔══════════════════════════════════════════════════════════════╗\033[0m\n"
  printf "   \033[1;35m║\033[0m           SELEÇÃO DE CANAL DE VERSÃO / BRANCH AMANDA         \033[1;35m║\033[0m\n"
  printf "   \033[1;35m╚══════════════════════════════════════════════════════════════╝\033[0m\n\n"
  printf "   Escolha qual versão/branch você deseja utilizar para %s:\n\n" "${motivo}"
  printf "   [\033[1;34m1\033[0m] \033[1;32mVersão Estável (main)\033[0m - Recomendada para Produção / Clientes\n"
  printf "   [\033[1;34m2\033[0m] \033[1;33mVersão de Desenvolvimento (davi-alteracoes)\033[0m - Recursos recentes (GLPI, correções)\n"
  printf "   [\033[1;34m3\033[0m] \033[1;35mVersão de Desenvolvimento (alan-alteracoes)\033[0m - Recursos em homologação\n"
  printf "   [\033[1;34m4\033[0m] \033[1;36mPersonalizada\033[0m - Digitar o nome de outra branch específica\n\n"
  printf "   Digite a opção desejada [1-4] (Padrão: 1): "
  read -r opt_branch
  opt_branch="${opt_branch:-1}"

  case "${opt_branch}" in
    2)
      BRANCH_AMANDA_ESCOLHIDA="davi-alteracoes"
      ;;
    3)
      BRANCH_AMANDA_ESCOLHIDA="alan-alteracoes"
      ;;
    4)
      printf "\n   Digite o nome exato da branch remota: "
      read -r BRANCH_AMANDA_ESCOLHIDA
      [ -z "${BRANCH_AMANDA_ESCOLHIDA}" ] && BRANCH_AMANDA_ESCOLHIDA="main"
      ;;
    *)
      BRANCH_AMANDA_ESCOLHIDA="main"
      ;;
  esac

  export BRANCH_AMANDA_ESCOLHIDA
  if [ -n "${ARQUIVO_VARIAVEIS_USADO:-}" ] && [ -f "${ARQUIVO_VARIAVEIS_USADO}" ]; then
    sed -i '/^BRANCH_AMANDA_ESCOLHIDA=/d' "${ARQUIVO_VARIAVEIS_USADO}"
    echo "BRANCH_AMANDA_ESCOLHIDA=\"${BRANCH_AMANDA_ESCOLHIDA}\"" >> "${ARQUIVO_VARIAVEIS_USADO}"
  elif [ -n "${empresa:-}" ] && [ -f "/root/VARIAVEIS_INSTALACAO_INSTANCIA_${empresa}" ]; then
    sed -i '/^BRANCH_AMANDA_ESCOLHIDA=/d' "/root/VARIAVEIS_INSTALACAO_INSTANCIA_${empresa}"
    echo "BRANCH_AMANDA_ESCOLHIDA=\"${BRANCH_AMANDA_ESCOLHIDA}\"" >> "/root/VARIAVEIS_INSTALACAO_INSTANCIA_${empresa}"
  fi

  printf "\n   \033[1;32m>> Canal selecionado: \033[1;34m%s\033[0m\n\n" "${BRANCH_AMANDA_ESCOLHIDA}"
  sleep 1
}

