set shell := ["bash", "-c"]

# Variáveis
export SOPS_AGE_KEY_FILE := home_dir() + "/.config/sops/age/keys.txt"

# Helper para rodar ansible com inventário descriptografado em memória (via process substitution)
ansible_cmd := "ansible-playbook -i <(sops -d " + quote(invocation_directory() + "/src/hosts.yaml") + ")"

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
    @chmod +x scripts/*.sh
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
    cd src && {{ansible_cmd}} --ask-become-pass configure-ssh.yaml


############################################################################
# DEPLOY
############################################################################
# Deploy completo da Homelab:
# - proxmox-init: Prepara imagem Cloud-Init e Templates no Proxmox
# - deploy-infra: Cria Containers LXC, VMs e configura SO Guest, DNS, S3 e Firewall
deploy-homelab: secrets-encrypt init
    cd src && {{ansible_cmd}} --ask-become-pass main.yaml --tags "proxmox-init,deploy-infra"

# Provisiona apenas a infraestrutura básica (LXC + VMs) sem instalar o Kubernetes
deploy-infra:
    cd src && {{ansible_cmd}} --ask-become-pass main.yaml --tags "deploy-infra"

# Cria e configura apenas os Containers LXC (DNS/AdGuard e Garage S3)
deploy-lxc:
    cd src && {{ansible_cmd}} --ask-become-pass main.yaml --tags "lxc"

# Cria e configura apenas as VMs (Nós do cluster K8s)
deploy-vms:
    cd src && {{ansible_cmd}} main.yaml --tags "vms"

# Executa apenas a instalação do cluster K3s (Masters e Workers)
k3s-install:
    cd src && {{ansible_cmd}} main.yaml --tags "k3s-install"

############################################################################
# DESTROY
############################################################################
# Destruição total da Homelab:
# - backup: Executa scripts de backup remotos antes da destruição
# - k3s-uninstall: Desinstala o K3s de todos os nós
# - destroy-infra: Remove todas as VMs e Containers do Proxmox
# - clean-local: Limpa configurações de SSH e fingerprints locais
destroy-homelab:
    cd src && {{ansible_cmd}} destroy.yaml --tags "destroy-all"

# Remove apenas as VMs e Containers do Proxmox, mantendo arquivos locais
destroy-infra:
    cd src && {{ansible_cmd}} destroy.yaml --tags "destroy-infra"

# Remove apenas os Containers LXC (DNS e S3) do Proxmox
destroy-lxc:
    cd src && {{ansible_cmd}} destroy.yaml --tags "destroy-lxc"

# Remove apenas as VMs (Nós do cluster K8s) do Proxmox
destroy-vms:
    cd src && {{ansible_cmd}} destroy.yaml --tags "destroy-vms"

# Remove apenas o Kubernetes do cluster, mantendo as VMs ligadas
k3s-uninstall:
    cd src && {{ansible_cmd}} destroy.yaml --tags "k3s-uninstall"

############################################################################
# MAINTENANCE & UPDATES
############################################################################
# Atualiza todos os SOs (Proxmox host + VMs + Containers)
homelab-update:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-all"

# Atualiza apenas os sistemas operacionais convidados (Ubuntu Noble)
homelab-update-guests:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-guests"

# Atualiza apenas os nós Proxmox (Debian)
homelab-update-proxmox:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-proxmox"

############################################################################
# BACKUP & RECOVERY (REMOTE)
############################################################################
# Dispara a sequência de backup remoto (AdGuard -> S3 -> GDrive) via Ansible
backup:
    cd src && {{ansible_cmd}} backup-recovery.yaml --tags "backup"

# Dispara a sequência de recovery remoto (GDrive -> S3 -> AdGuard) via Ansible
recovery:
    cd src && {{ansible_cmd}} backup-recovery.yaml --tags "recovery"

############################################################################
# SECRETS (SOPS + age)
############################################################################
# Cria uma nova chave age se não existir em ~/.config/sops/age/keys.txt
secrets-keygen:
    @test ! -d ~/.config/sops && mkdir -p ~/.config/sops/age
    @test ! -f ~/.config/sops/age/keys.txt && age-keygen -o ~/.config/sops/age/keys.txt || echo "Key file already exists"

# Criptografa o arquivo de hosts inicial (Garante segurança no Git)
secrets-encrypt:
    @if ! grep -q "sops:" src/hosts.yaml; then \
        sops --encrypt --in-place src/hosts.yaml && echo "src/hosts.yaml encrypted"; \
    else \
        echo "src/hosts.yaml is already encrypted"; \
    fi

# Abre o arquivo de hosts criptografado diretamente no editor padrão
secrets-edit:
    sops src/hosts.yaml

# Descriptografa o arquivo de hosts permanentemente (use com cautela)
secrets-decrypt:
    @if grep -q "sops:" src/hosts.yaml; then \
        sops --decrypt --in-place src/hosts.yaml && echo "src/hosts.yaml decrypted"; \
    else \
        echo "src/hosts.yaml is already decrypted"; \
    fi

# Apenas visualiza os segredos descriptografados no terminal
secrets-view:
    sops -d src/hosts.yaml

############################################################################
# POWER MANAGEMENT
############################################################################
# Liga todas as instâncias (Containers e VMs) no Proxmox
homelab-start:
    cd src && {{ansible_cmd}} power-management.yaml --tags "start"

# Desliga todas as instâncias (Containers e VMs) no Proxmox
homelab-stop:
    cd src && {{ansible_cmd}} power-management.yaml --tags "stop"

############################################################################
# UTILS
############################################################################
# Alterna o plugin de saída estética (beautiful_output) para melhor visualização ou debug
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
