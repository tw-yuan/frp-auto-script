#!/bin/bash
set -e
echo "Welcome to use frp auto setting script."
echo "This script will help you to install frp and configure it."
echo "Github: https://github.com/tw-yuan/frp-auto-script"
echo "Author: tw-yuan"

# Check root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install frp."
    exit 1
fi

# Check OS
if [ ! -z "`cat /etc/issue | grep bian`" ]; then
    OS="Debian"
    PM="apt"
elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ]; then
    OS="Ubuntu"
    PM="apt"
else
    echo "Not support OS, Please change to Debian/Ubuntu and try again."
    exit 1
fi

# option
echo "1) Install frp"
echo "2) Set frp server"
echo "3) Set frp client"
echo "4) Add serice port"
echo "5) Exit"

read -p "Please choose the action you want to do: " option

case $option in
    1)
        echo "Install frp"
        if [ $OS == "Debian" ] || [ $OS == "Ubuntu" ]; then
            apt update
            apt install -y wget
            mkdir /var/frp
            wget "https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_amd64.tar.gz"
            tar -zxvf frp_0.61.0_linux_amd64.tar.gz
            mv frp_0.61.0_linux_amd64/frps /var/frp
            mv frp_0.61.0_linux_amd64/frpc /var/frp
            rm -rf frp_0.61.0_linux_amd64
            rm -rf frp_0.61.0_linux_amd64.tar.gz
            echo "Install frp at /var/frp successfully."
            mkdir /var/frp/conf
        fi
        ;;
    2)
        echo "Setup frp server"
        read -p "Please enter a name for client (this input will be used on file name): " frp_server_name
        read -p "Please input frp server port: " frp_server_port
        read -p "Plase input frp server token or press enter to random: " frp_server_token
        read -p "Enable dashboard? (y/n): " frp_server_dashboard
        echo "Setting up..."
        if [ -z $frp_server_token ]; then
            frp_server_token=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)
        fi
        if [ $frp_server_dashboard == "y" ]; then
            read -p "Please input frp server dashboard port: " frp_server_dashboard_port
            read -p "Please input frp server dashboard user: " frp_server_dashboard_user
            read -p "Please input frp server dashboard password: " frp_server_dashboard_password
        fi
        cd /var/frp/conf
        echo "[common]" > $frp_server_name.toml
        echo "bindPort = $frp_server_port" > $frp_server_name.toml
        echo "auth.token = $frp_server_token" >> $frp_server_name.toml
        if [ $frp_server_dashboard == "y" ]; then
            echo "webServer.addr = 0.0.0.0" >> $frp_server_name.toml
            echo "webServer.port = $frp_server_dashboard_port" >> $frp_server_name.toml
            echo "webServer.user = $frp_server_dashboard_user" >> $frp_server_name.toml
            echo "webServer.password = $frp_server_dashboard_password" >> $frp_server_name.toml
        fi
        echo "Configuration file created at /var/frp/conf/$frp_server_name.toml"
        echo "Create a service for frp server..."
        echo "[Unit]" > /etc/systemd/system/frps-$frp_server_name.service
        echo "Description = frp server for $frp_server_name" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "After = network.target syslog.target" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "Wants = network.target" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "[Service]" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "Type = simple" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "ExecStart = /var/frp/frps -c /var/frp/conf/$frp_server_name.toml" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "Restart = on-failure" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "RestartSec = 3" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "[Install]" >> /etc/systemd/system/frps-$frp_server_name.service
        echo "WantedBy = multi-user.target" >> /etc/systemd/system/frps-$frp_server_name.service
        systemctl enable frps-$frp_server_name
        systemctl start frps-$frp_server_name
        echo "Service created and started."
        echo "=============================="
        echo "Server Information"
        echo "Server Port: $frp_server_port"
        echo "Server Token: $frp_server_token"
        if [ $frp_server_dashboard == "y" ]; then
            echo "Dashboard Port: $frp_server_dashboard_port"
            echo "Dashboard User: $frp_server_dashboard_user"
            echo "Dashboard Password: $frp_server_dashboard_password"
        fi
        echo "=============================="
        ;;
    3)
        echo "Set frp client"
        read -p "Please input frp server address: " frp_server_addr
        read -p "Please input frp server port: " frp_server_port
        read -p "Plase input frp server token: " frp_server_token
        echo "Setting up..."
        cd /var/frp/conf
        echo "[common]" > frpc.toml
        echo "webServer.addr = $frp_server_addr" > frpc.toml
        echo "webServer.port = $frp_server_port" >> frpc.toml
        echo "auth.token = $frp_server_token" >> frpc.toml
        echo "Configuration file created at /var/frp/conf/frpc.toml"
        echo "Create a service for frp client..."
        echo "[Unit]" > /etc/systemd/system/frpc.service
        echo "Description = frp client" >> /etc/systemd/system/frpc.service
        echo "After = network.target syslog.target" >> /etc/systemd/system/frpc.service
        echo "Wants = network.target" >> /etc/systemd/system/frpc.service
        echo "[Service]" >> /etc/systemd/system/frpc.service
        echo "Type = simple" >> /etc/systemd/system/frpc.service
        echo "ExecStart = /var/frp/frpc -c /var/frp/conf/frpc.toml" >> /etc/systemd/system/frpc.service
        echo "Restart = on-failure" >> /etc/systemd/system/frpc.service
        echo "RestartSec = 3" >> /etc/systemd/system/frpc.service
        echo "[Install]" >> /etc/systemd/system/frpc.service
        echo "WantedBy = multi-user.target" >> /etc/systemd/system/frpc.service
        systemctl enable frpc
        systemctl start frpc
        echo "Service created and started."
        echo "=============================="
        systemctl status frpc
        echo "=============================="


        ;;
    4)
        echo "Add serice port"
        read -p "Please input service name: " service_name
        read -p "Please input service local port: " service_local_port
        read -p "Please input service remote port: " service_remote_port
        read -p "Please input service type (tcp/udp): " service_type
        echo "Setting up..."
        cd /var/frp/conf
        echo "[[proxies]]" >> frpc.toml
        echo "name = \"$service_name\"" >> frpc.toml
        echo "type = \"$service_type\"" >> frpc.toml
        echo "localIP = \"127.0.0.1\"" >> frpc.toml
        echo "localPort = $service_local_port" >> frpc.toml
        echo "remotePort = $service_remote_port" >> frpc.toml
        echo "Configuration file updated at /var/frp/conf/frpc.toml"
        echo "Restart frp client service..."
        systemctl restart frpc
        echo "Service restarted."
        ;;
    5)
        echo "Exit"
        ;;
    *)
        echo "Please choose the correct option."
        ;;
esac

