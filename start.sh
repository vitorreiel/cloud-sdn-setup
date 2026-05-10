#!/bin/bash

aws_access_key=$(awk -F= '/aws_access_key_id/ && !/^#/ {print $2}' aws_access)
aws_secret_key=$(awk -F= '/aws_secret_access_key/ && !/^#/ {print $2}' aws_access)
aws_session_token=$(awk -F= '/aws_session_token/ && !/^#/ {print $2}' aws_access)

destination_file="automated-networks/ansible-playbook/vars/main.yaml"
destination_file_terraform="automated-networks/terraform/variables.tf"
destination_script="automated-networks/utils/network-components/start.sh"
destination_key="utils/credentials/keypair.pem"

echo -e "\n\033[1;33m- [ Attention: Your AWS Academy account must be started! ] \033[0m"
sleep 1
echo -e '\n\033[1;33m- [ Attention: You must have placed your AWS CLI in the "aws_access" file. ] \033[0m\n'
sleep 0.5
echo -e "\n\033[1;36m- [ Option: 1 - To start the automated emulated network creation process. ] \033[0m"
sleep 0.5
echo -e "\n\033[1;31m- [ Option: 2 - To delete an existing emulated network scenario. ] \033[0m\n"
echo -e '\n\033[1;35m- [ Please, option the corresponding value: ] \033[0m'
read confirmation

if [[ "$confirmation" =~ ^(1|01)$ ]]; then

    echo -e "\n\n\033[1;32m- [ Which tool do you want to use for scenario creation? Option only the number! ] \033[0m\n"
    sleep 0.5
    echo -e "\n\033[1;34m- [ 1 ] : Ansible \033[0m"
    sleep 0.5
    echo -e "\n\033[1;34m- [ 2 ] : Terraform \033[0m\n"
    sleep 0.5
    echo -e '\n\033[1;35m- [ Please, option the corresponding value: ] \033[0m'
    read iac

    echo -e "\n\n\033[1;32m- [ Option only the number corresponding to the desired topology! ] \033[0m\n"
    sleep 0.5
    echo -e "\n\033[1;34m- [ 1 ] : Single Network Topology \033[0m"
    sleep 0.5
    echo -e "\n\033[1;34m- [ 2 ] : Linear Network Topology \033[0m"
    sleep 0.5
    echo -e "\n\033[1;34m- [ 3 ] : Tree Network Topology \033[0m\n"
    sleep 0.5
    echo -e '\n\033[1;35m- [ Please, option the corresponding value: ] \033[0m'
    read topology

    generate_python_code() {
        local topology=$1
        local num_switches_lvl1=$2
        local num_switches_lvl2=$3
        local num_hosts_per_switch_lvl2=$4
        local num_switches=$2
        local num_hosts=$3
        local python_file="./utils/network-components/topology/topology.py"

    # Creates a temporary file for Python code
    temp_file=$(mktemp)

    cat <<EOF > $temp_file
#!/usr/bin/python

from mininet.net import Containernet
from mininet.node import Controller, RemoteController
from mininet.cli import CLI
from mininet.log import info, setLogLevel
import sys

def topology(args):
    "Create a network."
    net = Containernet(controller=Controller)

    info("*** Creating nodes\\n")
    C1 = net.addController(name='C1', controller=RemoteController, ip='localhost', protocol='tcp', port=6633)
EOF

    if [ "$topology" == "1" ] || [ "$topology" == "01" ]; then
        echo "    S1 = net.addSwitch('S1', dpid='0000000000000001')" >> $temp_file
        for ((i=1; i<=$num_hosts; i++)); do
            echo "    H$i = net.addDocker('H$i', mac='00:00:00:00:00:$(printf '%02x' $i)', ip='10.0.10.1$i/24', dimage=\"alpine-user:latest\")" >> $temp_file
            echo "    net.addLink(S1, H$i)" >> $temp_file
        done

    elif [ "$topology" == "2" ] || [ "$topology" == "02" ]; then
        # Adding switches
        for ((i=1; i<=$num_switches; i++)); do
            dpid=$(printf '%016x' $i)
            echo "    S$i = net.addSwitch('S$i', dpid='$dpid')" >> $temp_file
        done

        # Adding hosts and connecting each one to its corresponding switch
        for ((i=1; i<=$num_hosts; i++)); do
            echo "    H$i = net.addDocker('H$i', mac='00:00:00:00:00:$(printf '%02x' $i)', ip='10.0.10.1$i/24', dimage=\"alpine-user:latest\")" >> $temp_file
            echo "    net.addLink(S$i, H$i)" >> $temp_file
        done

        # Connecting switches in series
        for ((i=1; i<$num_switches; i++)); do
            echo "    net.addLink(S$i, S$((i + 1)))" >> $temp_file
        done

    elif [ "$topology" == "3" ] || [ "$topology" == "03" ]; then
        # Adding level 1 switches
        echo "    # Level 1: Switches connecting to level 2 switches" >> $temp_file
        for ((i=1; i<=$num_switches_lvl1; i++)); do
            dpid=$(printf '%016x' $i)
            echo "    S1$i = net.addSwitch('S1$i', dpid='$dpid')" >> $temp_file
        done

        # Adding level 2 switches and connecting them to level 1 switches
        echo "    # Level 2: Switches connected to level 1 switches" >> $temp_file
        for ((i=1; i<=$num_switches_lvl1; i++)); do
            for ((j=1; j<=$num_switches_lvl2; j++)); do
                dpid=$(printf '%016x' $((i * 1000 + j)))
                echo "    S2${i}_$j = net.addSwitch('S2${i}_$j', dpid='$dpid')" >> $temp_file
                echo "    net.addLink(S1$i, S2${i}_$j)" >> $temp_file

                # Connecting hosts to level 2 switches
                for ((k=1; k<=$num_hosts_per_switch_lvl2; k++)); do
                    echo "    H${i}_$j$k = net.addDocker('H${i}_$j$k', mac='00:00:00:00:0$i:$((j * 10 + k))', ip='10.0.$i.$((j * 10 + k))/24', dimage=\"alpine-user:latest\")" >> $temp_file
                    echo "    net.addLink(S2${i}_$j, H${i}_$j$k)" >> $temp_file
                done
            done
        done
    fi

    cat <<EOF >> $temp_file
    info("*** Starting network\\n")
    net.start()

    import time
    info("*** Waiting for controller to install flows...\\n")
    time.sleep(10)

    net.pingAll()

    info("*** Running CLI\\n")
    CLI(net)

    info("*** Stopping network\\n")
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    topology(sys.argv)
EOF

    # Moves temporary file to final file
    mv $temp_file $python_file
}

    case $topology in
        1|01)
            echo -e '\n\033[1;35m- [ How many hosts will be connected to the central switch? ] \033[0m'
            read num_hosts
            num_switches=1
    esac

    case $topology in
    2|02)
        while true; do
            echo -e "\n\033[1;35m- [ How many switches should be created? ] \033[0m"
            read num_switches
            echo -e "\n\033[1;35m- [ How many hosts should be created? ] \033[0m"
            read num_hosts

            # Verifies if the quantity of switches and hosts is the same
            if [ "$num_switches" -eq "$num_hosts" ]; then
                break
            else
                echo -e "\n\033[1;33m- [ The quantity of switches and hosts must be the same in Linear topology. Please try again. ] \033[0m"
            fi
        done
    esac

    case $topology in
        3|03)
        echo -e "\n\033[1;35m- [ How many switches do you want at level 1? ] \033[0m"
        read num_switches_lvl1
        echo -e "\n\033[1;35m- [ How many switches do you want at level 2? ] \033[0m"
        read num_switches_lvl2
        echo -e "\n\033[1;35m- [ How many hosts will be connected to each level 2 switch? ] \033[0m"
        read num_hosts_per_switch_lvl2
    esac

    if [ "$topology" == "3" ] || [ "$topology" == "03" ]; then
        generate_python_code "$topology" "$num_switches_lvl1" "$num_switches_lvl2" "$num_hosts_per_switch_lvl2"
    else
        generate_python_code "$topology" "$num_switches" "$num_hosts"
    fi

    if command -v aws &> /dev/null; then
        export AWS_PAGER=""
        export AWS_ACCESS_KEY_ID="$(echo "$aws_access_key" | tr -d ' ')"
        export AWS_SECRET_ACCESS_KEY="$(echo "$aws_secret_key" | tr -d ' ')"
        _token="$(echo "$aws_session_token" | tr -d ' ')"
        [ -n "$_token" ] && export AWS_SESSION_TOKEN="$_token"
        export AWS_DEFAULT_REGION="us-east-1"

        EXISTING=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=Containernet" "Name=instance-state-name,Values=running,stopped,pending" \
            --query 'Reservations[0].Instances[0].InstanceId' \
            --output text 2>/dev/null)

        if [ "$EXISTING" != "None" ] && [ -n "$EXISTING" ]; then
            echo -e "\n\033[1;33m- [ Existing Containernet infrastructure detected. Running cleanup before proceeding... ] \033[0m\n"
            bash cleanup.sh
        fi
    fi

    # Determine topology kind and IaC tool name for CSV path
    case $topology in
        1|01) kind="single" ;;
        2|02) kind="linear" ;;
        3|03) kind="tree" ;;
    esac

    case $iac in
        1|01) iac_name="ansible" ;;
        2|02) iac_name="terraform" ;;
    esac

    # Create results directory and CSV file with header if it doesn't exist
    mkdir -p "results/create/${iac_name}"
    csv_file="results/create/${iac_name}/${kind}.csv"
    if [ ! -f "$csv_file" ]; then
        echo "id,runtime,kind" > "$csv_file"
    fi
    last_id=$(tail -n +2 "$csv_file" | wc -l)
    id=$((last_id + 1))

    # Install dependencies once before the repetition loop
    case $iac in
    1|01)
        echo -e "\n\033[1;33m- [ Starting Infrastructure configurations. Please wait! ] \033[0m\n"
        sudo apt update -y > /dev/null 2>&1
        sudo apt install git python3 python3-pip ansible -y > /dev/null 2>&1
        pip install boto3 ansible-core==2.16.0 Jinja2==3.1.3 urllib3==1.26.5 --break-system-packages > /dev/null 2>&1
        ansible-galaxy collection install community.aws --force > /dev/null 2>&1
        awk -v new_value_1="$aws_access_key" 'NR == 2 {print "aws_access_key: " new_value_1} NR != 2' "$destination_file" > tmpfile && mv tmpfile "$destination_file"
        awk -v new_value_2="$aws_secret_key" 'NR == 3 {print "aws_secret_key: " new_value_2} NR != 3' "$destination_file" > tmpfile && mv tmpfile "$destination_file"
        awk -v new_value_3="$aws_session_token" 'NR == 4 {print "aws_session_token: " new_value_3} NR != 4' "$destination_file" > tmpfile && mv tmpfile "$destination_file"
        echo -e "\033[1;32m- [ Dependencies installed Successfully! ] \033[0m\n"
    esac

    case $iac in
    2|02)
        if [ ! -f "$destination_key" ]; then
            touch "$destination_key"
        fi
        sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl > /dev/null 2>&1
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null 2>&1
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null 2>&1
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install terraform -y > /dev/null 2>&1
        sed -i -e "4s|.*|  default = \"$aws_access_key\"|" -e "10s|.*|  default = \"$aws_secret_key\"|" -e "16s|.*|  default = \"$aws_session_token\"|" "$destination_file_terraform"
        terraform -chdir=automated-networks/terraform init
    esac

    # --- CREATION ---
    start_time=$(date +%s)

    case $iac in
    1|01)
        ansible-playbook -i automated-networks/ansible-playbook/hosts automated-networks/ansible-playbook/playbook.yaml
    esac

    case $iac in
    2|02)
        terraform -chdir=automated-networks/terraform apply -auto-approve
    esac

    end_time=$(date +%s)
    runtime=$((end_time - start_time))

    # Save last run state for destroy reference
    echo "${kind},${iac_name}" > results/.last_run

    # Append result to CSV
    echo "$id,$runtime,$kind" >> "$csv_file"
    echo -e "\033[1;32m- [ Done | Runtime: ${runtime}s | Saved to $csv_file ] \033[0m"

elif [[ "$confirmation" =~ ^(2|02)$ ]]; then

    # Read last run state to determine topology and IaC tool
    if [ ! -f "results/.last_run" ]; then
        echo -e "\n\033[1;31m- [ Error: No previous scenario found. Please create a scenario first (option 1). ] \033[0m"
        exit 1
    fi

    kind=$(cut -d',' -f1 "results/.last_run")
    iac_name=$(cut -d',' -f2 "results/.last_run")

    echo -e "\n\033[1;36m- [ Destroying ${kind} topology created with ${iac_name}... ] \033[0m\n"

    # Create results directory and CSV file with header if it doesn't exist
    mkdir -p "results/destroy/${iac_name}"
    csv_file="results/destroy/${iac_name}/${kind}.csv"
    if [ ! -f "$csv_file" ]; then
        echo "id,runtime,kind" > "$csv_file"
    fi
    last_id=$(tail -n +2 "$csv_file" | wc -l)
    id=$((last_id + 1))

    # --- DESTRUCTION ---
    start_time=$(date +%s)

    case $iac_name in
    ansible)
        ansible-playbook -i automated-networks/ansible-playbook/hosts automated-networks/ansible-playbook/playbook-destroy.yaml
    ;;
    terraform)
        terraform -chdir=automated-networks/terraform destroy -auto-approve
    ;;
    esac

    end_time=$(date +%s)
    runtime=$((end_time - start_time))

    # Remove last run state
    rm -f "results/.last_run"

    # Append result to CSV
    echo "$id,$runtime,$kind" >> "$csv_file"
    echo -e "\033[1;32m- [ Done | Runtime: ${runtime}s | Saved to $csv_file ] \033[0m"
else
    echo -e "\n\033[1;33m- [ Sorry, value not found, closing terminal... ] \033[0m"
fi
