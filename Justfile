set shell := ["bash", "-c"]

# Variáveis
my_config_files := "config-files/my-configs"
servers_host_file := env_var_or_default("SERVERS_HOST_FILE", "")

############################################################################
# FISRT USE
# Configurações iniciais, pra quando se clona o repositório a primeira vez
############################################################################
# Copia a pasta sample para my-configs se não existir
init-config-files:
    @test ! -d {{my_config_files}} && cp -rv config-files/sample {{my_config_files}} || echo "folder {{my_config_files}} already exists"

# Instala os arquivos de configuração de 'config-files/my-configs' para o local correto
install-config-files:
    cp -v "{{my_config_files}}/hosts.yaml" src/hosts.yaml



############################################################################
# INIT
# Aquivos de config estando ok, esse é o comando de Init
############################################################################
# Configuração inicial: instala dependências e configura SSH
init:
    cd scripts && ./check_dependencies.sh
    ansible-galaxy install -r src/requirements.yml
    cd src && ansible-playbook --ask-become-pass -i hosts.yaml configure-ssh.yaml

# Realiza backup dos servidores para o localhost
save-data:
    cd src && ansible-playbook save-data.yaml



############################################################################
# Deploy
# Comandos de criação e Deploy
############################################################################
# Deploy completo no Proxmox
homelab-build: init
    cd src && ansible-playbook -i hosts.yaml main.yaml --tags "proxmox-init,deploy-infra"

# Deploy apenas da infraestrutura
deploy-infra:
    cd src && ansible-playbook -i hosts.yaml main.yaml --tags "deploy-infra"

# Instalação apenas do K3s
k3s-install:
    cd src && ansible-playbook -i hosts.yaml main.yaml --tags "k3s-install"

# Atualiza todos os sistemas operacionais (VMs e Containers)
homelab-update:
    cd src && ansible-playbook -i hosts.yaml update-os.yaml



############################################################################
# DESTROY
# Comandos de Destroy
############################################################################
homelab-reset:
    cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "destroy-infra,reset-proxmox"

# Destruição apenas da infraestrutura
destroy-infra:
    cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "destroy-infra"

# Desinstalação apenas do K3s
k3s-uninstall:
    cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "k3s-uninstall"


############################################################################
# Power Management
# Comandos de Ligar/Desligar
############################################################################
# Inicia todas as VMs e Containers
homelab-start:
    cd src && ansible-playbook -i hosts.yaml power-management.yaml --tags "start"

# Desliga todas as VMs e Containers
homelab-stop:
    cd src && ansible-playbook -i hosts.yaml power-management.yaml --tags "stop"


############################################################################
# UTILS
############################################################################
# Liga/Desliga o plugin de saída estética (uso: just plugin on | just plugin off)
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
