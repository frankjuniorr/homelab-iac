set shell := ["bash", "-c"]

# Variáveis
export VAULT_PASS_FILE := home_dir() + "/.config/homelab-iac/.vault_pass"

# Helper para rodar ansible com inventário criptografado (Ansible-Vault descriptografa em runtime)
ansible_cmd := "ansible-playbook -i " + quote(invocation_directory() + "/src/hosts.yaml") + " --vault-password-file " + VAULT_PASS_FILE

############################################################################
# FIRST USE
############################################################################
# Inicializa o arquivo de hosts a partir do sample (apenas se não existir)
init-hosts:
    @test ! -f src/hosts.yaml && cp -v config-files/sample/hosts.yaml src/hosts.yaml || echo "src/hosts.yaml already exists"

############################################################################
# INIT
############################################################################
# Instala git hooks para garantir segurança (pre-commit verifica criptografia SOPS)
install-hooks:
    @echo "Installing git pre-commit hook..."
    @cp -f scripts/pre-commit.sh .git/hooks/pre-commit
    @chmod +x .git/hooks/pre-commit
    @echo "Hook installed successfully."

# Configuração inicial do ambiente:
# 1. Instala dependências do host
# 2. Instala coleções Ansible do Galaxy
# 3. Configura o SSH local (~/.ssh/config) para acesso fácil aos nós
init: install-hooks
    cd scripts && ./check_dependencies.sh
    ansible-galaxy install -r src/requirements.yml
    cd src && {{ansible_cmd}} configure-ssh.yaml


############################################################################
# DEPLOY
############################################################################
# Deploy completo da Homelab:
# - proxmox-init: Prepara imagem Cloud-Init e Templates no Proxmox
# - deploy-infra: Cria VMs (netuno/Docker, terra/HAOS), job de vzdump e configura SO Guest e Docker
# Depois: `just deploy-stacks` em homelab-deploys sobe AdGuard, Tailscale e Duplicati na netuno
deploy-homelab: secrets-encrypt init
    cd src && {{ansible_cmd}} main.yaml --tags "proxmox-init,deploy-infra"
    cd src && {{ansible_cmd}} main.yaml --tags "post-deploy"

# Provisiona apenas a infraestrutura básica (VMs)
deploy-infra:
    cd src && {{ansible_cmd}} main.yaml --tags "deploy-infra"

# Cria e configura apenas as VMs (netuno/Docker e terra/Home Assistant OS)
deploy-vms:
    cd src && {{ansible_cmd}} main.yaml --tags "vms"

############################################################################
# DESTROY
############################################################################
# Destruição total da Homelab:
# - destroy-infra: Remove todas as VMs do Proxmox
# - clean-local: Limpa configurações de SSH e fingerprints locais
destroy-homelab:
    cd src && {{ansible_cmd}} destroy.yaml --tags "destroy-all"

# Remove apenas as VMs do Proxmox, mantendo arquivos locais
destroy-infra:
    cd src && {{ansible_cmd}} destroy.yaml --tags "destroy-infra"

# Remove apenas as VMs (netuno e terra) do Proxmox
destroy-vms:
    cd src && {{ansible_cmd}} destroy.yaml --tags "destroy-vms"

############################################################################
# MAINTENANCE & UPDATES
############################################################################
# Atualiza todos os SOs (Proxmox host + VMs)
homelab-update:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-all"

# Atualiza apenas os sistemas operacionais convidados (Ubuntu Noble; o HAOS se atualiza sozinho)
homelab-update-guests:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-guests"

# Atualiza apenas os nós Proxmox (Debian)
homelab-update-proxmox:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-proxmox"

############################################################################
# SECRETS (Ansible-Vault)
############################################################################
# Cria um novo arquivo de senha para o vault se não existir em ~/.config/homelab-iac/.vault_pass
secrets-keygen:
    @test ! -d ~/.config/homelab-iac && mkdir -p ~/.config/homelab-iac
    @test ! -f {{VAULT_PASS_FILE}} && openssl rand -base64 32 > {{VAULT_PASS_FILE}} && chmod 600 {{VAULT_PASS_FILE}} || echo "Vault password file already exists"

# Criptografa o arquivo de hosts inicial (Garante segurança no Git)
secrets-encrypt:
    @if ! grep -q "\$ANSIBLE_VAULT" src/hosts.yaml; then \
        ansible-vault encrypt src/hosts.yaml --vault-password-file {{VAULT_PASS_FILE}} && echo "src/hosts.yaml encrypted"; \
    else \
        echo "src/hosts.yaml already encrypted"; \
    fi

# Abre o arquivo de hosts criptografado diretamente no editor padrão
secrets-edit:
    ansible-vault edit src/hosts.yaml --vault-password-file {{VAULT_PASS_FILE}}

# Descriptografa o arquivo de hosts permanentemente (use com cautela)
secrets-decrypt:
    @if grep -q "\$ANSIBLE_VAULT" src/hosts.yaml; then \
        ansible-vault decrypt src/hosts.yaml --vault-password-file {{VAULT_PASS_FILE}} && echo "src/hosts.yaml decrypted"; \
    else \
        echo "src/hosts.yaml is already decrypted"; \
    fi

# Apenas visualiza os segredos descriptografados no terminal
secrets-view:
    ansible-vault view src/hosts.yaml --vault-password-file {{VAULT_PASS_FILE}}

############################################################################
# POWER MANAGEMENT
############################################################################
# Liga todas as instâncias (VMs) no Proxmox
homelab-start:
    cd src && {{ansible_cmd}} power-management.yaml --tags "start"

# Desliga todas as instâncias (VMs) no Proxmox
homelab-stop:
    cd src && {{ansible_cmd}} power-management.yaml --tags "stop"

############################################################################
# UTILS
############################################################################
# Liga/Desliga o plugin de saída estética (beautiful_output) para melhor visualização ou debug
plugin state:
    @if [ "{{state}}" == "on" ]; then \
        sed -i '/^# *stdout_callback = beautiful_output/s/^# *//' src/ansible.cfg; \
        echo "Plugin 'beautiful_output' ATIVADO."; \
    elif [ "{{state}}" == "off" ]; then \
        sed -i '/^stdout_callback = beautiful_output/s/^/# /' src/ansible.cfg; \
        echo "Plugin 'beautiful_output' DESATIVADO."; \
    else \
        echo "Use: just plugin on ou just plugin off"; \
    fi

# Executa um diagnóstico completo da infraestrutura Homelab (Healthcheck)
doctor:
    ./scripts/doctor.sh
