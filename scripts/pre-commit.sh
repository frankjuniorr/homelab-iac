#!/usr/bin/env bash

# Função: check_encrypt_host_file
# Objetivo: Verificar se o arquivo de hosts contém os metadados do Ansible-Vault antes de permitir o commit.
check_encrypt_host_file() {
  HOSTS_FILE="src/hosts.yaml"

  if [ -f "$HOSTS_FILE" ]; then
    # IMPORTANTE: Usamos 'git show :path' para olhar o conteúdo que está no STAGE
    if git show :"$HOSTS_FILE" | grep -q "\$ANSIBLE_VAULT"; then
      return 0 # Sucesso: o arquivo está encriptado, continua para a próxima função
    else
      echo "------------------------------------------------------------------------"
      echo "❌ ERROR: $HOSTS_FILE is NOT encrypted in the git stage!"
      echo "------------------------------------------------------------------------"
      echo "Steps to fix:"
      echo "1. Run: just secrets-encrypt"
      echo "2. Run: git add $HOSTS_FILE"
      echo "3. Try to commit again."
      echo "------------------------------------------------------------------------"
      exit 1 # Falha: interrompe o commit
    fi
  fi
}

# Função: ensure_plugin_on
# Objetivo: Garante que o plugin estético do Ansible esteja ativado ao commitar.
ensure_plugin_on() {
  if command -v just >/dev/null 2>&1; then
    just plugin on
  else
    # Fallback caso o just não esteja no PATH (ex: ambientes de CI ou hooks restritos)
    # O comando abaixo faz o mesmo que o 'just plugin on' faz no Justfile
    sed -i '/^# *stdout_callback = beautiful_output/s/^# *//' src/ansible.cfg
    echo "Plugin 'beautiful_output' ATIVADO via fallback (sed)."
  fi
}

# Função: add_git_files
# Objetivo: Garante que os arquivos modificados e adicionados ao stage sejam processadas corretamente.
add_git_files() {
  FILES=$(git diff --cached --name-only --diff-filter=ACMR)
  if [ -n "$FILES" ]; then
      git add $FILES
  fi
}

# Função: ensure_scripts_executable
# Objetivo: Garante que todos os scripts na pasta scripts/ tenham permissão de execução.
ensure_scripts_executable() {
  chmod +x scripts/*.sh
  # Garante que o próprio hook tenha permissão (caso seja atualizado)
  chmod +x .git/hooks/pre-commit
}

# Execução das verificações de forma sequencial
ensure_scripts_executable
check_encrypt_host_file
ensure_plugin_on
add_git_files

exit 0
