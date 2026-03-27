set shell := ["bash", "-c"]

# Variáveis
export SOPS_AGE_KEY_FILE := home_dir() + "/.config/sops/age/keys.txt"

# Helper para rodar ansible com inventário descriptografado em memória (via process substitution)
# Usamos o caminho absoluto para o arquivo de hosts para evitar problemas de navegação de diretório
ansible_cmd := "ansible-playbook -i <(sops -d " + quote(invocation_directory() + "/src/hosts.sops.yaml") + ")"

############################################################################
# FIRST USE
############################################################################
# Inicializa o arquivo de hosts a partir do sample (apenas se não existir)
init-hosts:
    @test ! -f src/hosts.sops.yaml && cp -v config-files/sample/hosts.yaml src/hosts.sops.yaml || echo "src/hosts.sops.yaml already exists"

############################################################################
# INIT
############################################################################
# Instala git hooks para garantir segurança
install-hooks:
    @chmod +x scripts/*.sh
    @echo "Installing git pre-commit hook..."
    @cp -f scripts/pre-commit.sh .git/hooks/pre-commit
    @chmod +x .git/hooks/pre-commit
    @echo "Hook installed successfully."

# Configuração inicial: instala dependências e configura SSH
init: install-hooks
    cd scripts && ./check_dependencies.sh
    ansible-galaxy install -r src/requirements.yml
    cd src && {{ansible_cmd}} --ask-become-pass configure-ssh.yaml

# Realiza backup dos servidores para o localhost
save-data:
    cd src && {{ansible_cmd}} save-data.yaml

############################################################################
# Deploy
############################################################################
# Deploy completo no Proxmox
homelab-build: init
    cd src && {{ansible_cmd}} main.yaml --tags "proxmox-init,deploy-infra"

# Deploy apenas da infraestrutura
deploy-infra:
    cd src && {{ansible_cmd}} main.yaml --tags "deploy-infra"

# Instalação apenas do K3s
k3s-install:
    cd src && {{ansible_cmd}} main.yaml --tags "k3s-install"

############################################################################
# Updates
############################################################################
# Atualiza todos os sistemas operacionais (VMs e Containers)
homelab-update:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-all"

# Atualiza apenas as VMs e Containers (guests)
homelab-update-guests:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-guests"

# Atualiza apenas os nós do Proxmox
homelab-update-proxmox:
    cd src && {{ansible_cmd}} update-os.yaml --tags "update-proxmox"

############################################################################
# SECRETS (SOPS + age)
############################################################################
# Cria uma nova chave age se não existir
secrets-keygen:
    @test ! -d ~/.config/sops && mkdir -p ~/.config/sops/age
    @test ! -f ~/.config/sops/age/keys.txt && age-keygen -o ~/.config/sops/age/keys.txt || echo "Key file already exists"

# Criptografa o arquivo de hosts inicial
secrets-encrypt:
    @sops --encrypt --in-place src/hosts.sops.yaml
    @echo "src/hosts.sops.yaml encrypt"

# Edita o arquivo de hosts descriptografado no editor
secrets-edit:
    sops src/hosts.sops.yaml

# Descriptografa o arquivo de hosts (in-place)
secrets-decrypt:
    @sops --decrypt --in-place src/hosts.sops.yaml
    @echo "src/hosts.sops.yaml encrypt"

# Descriptografa o arquivo de hosts para visualização
secrets-view:
    sops -d src/hosts.sops.yaml

############################################################################
# DESTROY
############################################################################
homelab-reset:
    cd src && {{ansible_cmd}} reset.yaml --tags "destroy-infra,reset-proxmox"

# Destruição apenas da infraestrutura
destroy-infra:
    cd src && {{ansible_cmd}} reset.yaml --tags "destroy-infra"

# Desinstalação apenas do K3s
k3s-uninstall:
    cd src && {{ansible_cmd}} reset.yaml --tags "k3s-uninstall"

############################################################################
# Power Management
############################################################################
# Inicia todas as VMs e Containers
homelab-start:
    cd src && {{ansible_cmd}} power-management.yaml --tags "start"

# Desliga todas as VMs e Containers
homelab-stop:
    cd src && {{ansible_cmd}} power-management.yaml --tags "stop"

############################################################################
# UTILS
############################################################################
# Liga/Desliga o plugin de saída estética
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
