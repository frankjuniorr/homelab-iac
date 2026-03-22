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
proxmox-build:
    cd src && ansible-playbook -i hosts.yaml main.yaml --tags "proxmox-init,deploy-infra"

# Deploy apenas da infraestrutura
deploy-infra:
    cd src && ansible-playbook -i hosts.yaml main.yaml --tags "deploy-infra"

# Instalação apenas do K3s
k3s-install:
    cd src && ansible-playbook -i hosts.yaml main.yaml --tags "k3s-install"



############################################################################
# DESTROY
# Comandos de Destroy
############################################################################
proxmox-reset:
    cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "destroy-infra,reset-proxmox"

# Destruição apenas da infraestrutura
destroy-infra:
    cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "destroy-infra"

# Desinstalação apenas do K3s
k3s-uninstall:
    cd src && ansible-playbook -i hosts.yaml reset.yaml --tags "k3s-uninstall"
