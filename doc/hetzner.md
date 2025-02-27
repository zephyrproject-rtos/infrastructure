# Hetzner Deployment Plan

## Network

### Notes

* Every node has a unique public IPv4 address for internet uplink. The purpose of this, as opposed
  to outbound NAT-ing on a secure private network, is to distribute the outgoing internet traffic
  across multiple nodes and take advantage of the Hetzner's unlimited traffic policy on the nodes
  with 1GbE ports.
* The node firewall, by default, shall be configured to block all incoming traffic on the public
  IPv4 address for security. All management and sensitive inter-node traffic shall be routed over
  secure private networks.
* IPv6 is disabled at node level in order to simplify network configuration and reduce potential
  attack surfaces.
* Each internal network is placed on a unique vSwitch/VLAN configured on Hetzner Robot. The vSwitch
  for each VLAN is connected to the main Ethernet port of the associated nodes and its traffic is
  802.1q tagged.

### Secure Private Networks

* mgmt (Management Network)

    ```
    IPv4	172.24.0.0/16
    IPv6	Disabled
    VLAN	4000
    ```

* cluster-a (Kubernetes Cluster A)

    ```
    IPv4	10.128.0.0/16
    IPv6	Disabled
    VLAN	4001
    ```

* cluster-b (Kubernetes Cluster B)

    ```
    IPv4	10.129.0.0/16
    IPv6	Disabled
    VLAN	4002
    ```

### Remote Access

A WireGuard VPN server is set up on the `rt1` router node for remotely accessing the secure private
networks, including the `mgmt` network used for SSH connections.

The WireGuard VPN operates on the private IPv4 network `172.16.88.0/24` and the client traffic to
the secure private networks is masqueraded to the corresponding secure private network IPv4 address
of the `rt1` host.

Note that masquerading is necessary because our servers use the Hetzner public internet gateway as
the default gateway and the secure private network traffic is not routable on it.

## Server

* rt1 (Management Network Router)

    * IP Router and Firewall for internal networks
    * DNS Server for cluster internal addresses
    * WireGuard VPN Server for remote internal network access
    * Rocky Linux 9 (RHEL 9)

    ```
    mgmt	172.24.0.10/16
    cluster-a	10.128.0.10/16
    cluster-b	10.129.0.10/16
    wireguard	172.16.88.1/24
    ```

* deploy1

    * Main Deployment Host
    * "Under-cloud" K3s Server for Rancher Server deployment
    * Rancher Server/Provisioner
    * Rocky Linux 9 (RHEL 9)

    ```
    mgmt	172.24.10.1/16
    cluster-a	10.128.10.1/16
    cluster-b	10.129.10.1/16
    ```

* cluams1, cluams2, cluams3

    * Kubernetes Dedicated Master Node
    * Rocky Linux 9 (RHEL 9)

    ```
    mgmt	172.24.20.N/16
    cluster-a	10.128.20.N/16
    ```

* cax162rN

    * Compute Hosts
    * Kubernetes Master Node (`cax162r1` and `cax162r2`)
    * Kubernetes Worker Node
    * Rocky Linux 9 (RHEL 9)

    ```
    mgmt	172.24.40.N/16
    cluster-a	10.128.40.N/16
    ```

## Deployment Procedure

### Router Node

1. Configure IP networks in the NetworkManager. 

    * Add `mgmt`, `cluster-a` and `cluster-b` VLAN interfaces.
    * Ensure that the Hetzner DNS server, `185.12.64.1`, is configured as the default DNS server.

    ```
    IFACE=enp0s31f6
    IP_MGMT=172.24.0.10
    IP_CLUSTER_A=10.128.0.10
    IP_CLUSTER_B=10.129.0.10

    nmcli connection add type vlan \
      con-name mgmt \
      dev $IFACE \
      mtu 1400 \
      id 4000 \
      ipv4.method manual \
      ipv4.addresses $IP_MGMT/16 \
      ipv6.method disabled

    nmcli connection add type vlan \
      con-name cluster-a \
      dev $IFACE \
      mtu 1400 \
      id 4001 \
      ipv4.method manual \
      ipv4.addresses $IP_CLUSTER_A/16 \
      ipv6.method disabled

    nmcli connection add type vlan \
      con-name cluster-b \
      dev $IFACE \
      mtu 1400 \
      id 4002 \
      ipv4.method manual \
      ipv4.addresses $IP_CLUSTER_B/16 \
      ipv6.method disabled
    ```

1. Configure BIND DNS server.

    * Install and enable BIND `named`.

    ```
    dnf install bind bind-utils
    systemctl enable --now named
    ```

    * Set `named` configurations in `/etc/named.conf`.

    * Add internal DNS records in `/var/named/hzr.zephyrproject.io.db`.

1. Configure WireGuard server.

    * Install WireGuard.

    ```
    dnf install wireguard-tools
    ```

    * Configure `wg0` WireGuard interface configurations in `/etc/wireguard/wg0.conf`.

    ```
    [Interface]
    Address = 172.16.88.1/24
    SaveConfig = true
    PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o enp0s31f6.4000 -j MASQUERADE; iptables -t nat -A POSTROUTING -o enp0s31f6.4001 -j MASQUERADE; iptables -t nat -A POSTROUTING -o enp0s31f6.4002 -j MASQUERADE
    PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o enp0s31f6.4000 -j MASQUERADE; iptables -t nat -D POSTROUTING -o enp0s31f6.4001 -j MASQUERADE; iptables -t nat -D POSTROUTING -o enp0s31f6.4002 -j MASQUERADE
    ListenPort = 51820
    PrivateKey = <REDACTED>

    [Peer]
    PublicKey = <REDACTED>
    AllowedIPs = 172.16.88.10/32
    ```

    * Set up `wg0` as a service.

    ```
    systemctl enable --now wg-quick@wg0
    ```

### Rancher Deployment Node

1. Configure IP networks in the NetworkManager.

    * Add `mgmt`, `cluster-a` and `cluster-b` VLAN interfaces.
    * Remove the Hetzner DNS server address on the untagged internet interface and set the DNS
      server address to `172.24.0.10` (`rt1`) on the `mgmt` VLAN interface.
    * Ensure that `/etc/resolv.conf` has `nameserver 172.24.0.10`. Note that this will be
      configured by the NetworkManager; if not properly set, check the NetworkManager
      configurations.

    ```
    IFACE=enp0s31f6
    IP_MGMT=172.24.10.1
    IP_CLUSTER_A=10.128.10.1
    IP_CLUSTER_B=10.129.10.1

    nmcli connection add type vlan \
      con-name mgmt \
      dev $IFACE \
      mtu 1400 \
      id 4000 \
      ipv4.method manual \
      ipv4.addresses $IP_MGMT/16 \
      ipv6.method disabled

    nmcli connection add type vlan \
      con-name cluster-a \
      dev $IFACE \
      mtu 1400 \
      id 4001 \
      ipv4.method manual \
      ipv4.addresses $IP_CLUSTER_A/16 \
      ipv6.method disabled

    nmcli connection add type vlan \
      con-name cluster-b \
      dev $IFACE \
      mtu 1400
      id 4002 \
      ipv4.method manual \
      ipv4.addresses $IP_CLUSTER_B/16 \
      ipv6.method disabled
    ```

1. Install [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) and
   [`helm`](https://helm.sh/docs/intro/install/#from-script).

    ```
    # Download and validate pre-compiled kubectl binary.
    curl -LO https://dl.k8s.io/release/v1.31.5/bin/linux/amd64/kubectl
    curl -LO https://dl.k8s.io/release/v1.31.5/bin/linux/amd64/kubectl.sha256
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

    # Install kubectl binary.
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Download and run helm install script.
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    ```

    Note that these commands are to be executed as the root user on the deployment host; hence, the
    default Kubernetes tooling and client context is assumed to be for the K3s installation of the
    K3s instance of the deployment host.

1. [Install K3s Kubernetes cluster.](https://documentation.suse.com/cloudnative/rancher-manager/latest/en/installation-and-upgrade/quick-start/deploy-rancher/helm-cli.html#_install_suse_rancher_prime_k3s_on_linux)

    ```
    # Run K3s installation script.
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.5+k3s1 sh -s - server --cluster-init

    # Make K3s client config the user default.
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    ```

1. [Deploy Rancher Prime Server on the K3s Kubernetes cluster.](https://documentation.suse.com/cloudnative/rancher-manager/latest/en/installation-and-upgrade/quick-start/deploy-rancher/helm-cli.html#_install_rancher_with_helm)

    ```
    # Add Helm repositories.
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm repo add jetstack https://charts.jetstack.io
    helm repo update

    # Install cert-manager for issuing Rancher web UI TLS certificates in the K3s "under-cloud".
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.1/cert-manager.crds.yaml
    helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace

    # Install Rancher in the K3s "under-cloud".
    kubectl create namespace cattle-system
    helm install rancher rancher-latest/rancher \
        --namespace cattle-system \
        --set hostname=deploy1.cluster-a.hzr.zephyrproject.io \
        --set replicas=1 \
        --set bootstrapPassword=<PASSWORD_FOR_RANCHER_ADMIN>
    ```

    Note that:

    * Rancher Server endpoint hostname must resolve to an internal IP (e.g. on `cluster-a` network)
      in order to ensure that the master and worker nodes communicate over the internal network.
      This also implies that the Rancher web UI and API endpoints will not be accessible on the
      public IPv4 network (i.e. internet), which would be a sensible security choice.
    * The K3s "under-cloud" deployment is not highly available and is solely hosted by the `deploy1`
      host. While it would be nice to make the K3s "under-cloud" highly available, this is not
      strictly necessary because, once the CI service Kubernetes cluster is up and running, the
      Rancher Server and its underlying K3s cluster only function as a "convenience tool" for
      managing the cluster. The CI service Kubernetes cluster itself shall be deployed in a highly
      available configuration.

### Rancher Kubernetes Cluster Nodes

1. Configure IP networks in the NetworkManager.

   * Add `cluster-a` VLAN interfaces.
   * Remove the Hetzner DNS server address on the untagged internet interface and set the DNS server
     address to `10.128.0.10` (`rt1`) on the `cluster-a` VLAN interface.
   * Ensure that `/etc/resolv.conf` has `nameserver 10.128.0.10`. Note that this will be configured
     by the NetworkManager; if not properly set, check the NetworkManager configurations.

    ```
    IFACE=enp193s0f0
    IP_CLUSTER_A=10.128.40.1

    nmcli connection add type vlan \
      con-name cluster-a \
      dev $IFACE \
      mtu 1400 \
      id 4001 \
      ipv4.method manual \
      ipv4.addresses $IP_CLUSTER_A/16 \
      ipv4.dns 10.128.0.10 \
      ipv6.method disabled
    ```

1. Install required system packages.

    ```
    # dnsutils for nslookup
    dnf install -y dnsutils

    # tar required by Rancher deployment script
    dnf install -y tar
    ```

1. Run cluster node bootstrap script from Rancher web UI.

## Operations and Management

### Client Configuration

#### WireGuard VPN Client

```
[Interface]
Address = 172.16.88.10/24
SaveConfig = true
ListenPort = 35711
PrivateKey = <REDACTED>

[Peer]
PublicKey = <REDACTED>
AllowedIPs = 172.16.88.0/24, 172.24.0.0/16, 10.128.0.0/16, 10.129.0.0/16
Endpoint = 138.201.49.175:51820
```

#### /etc/hosts

Minimal `/etc/hosts` file entries on the client node for managing the Rancher deployment.

```
138.201.49.175 rt1.hzr.zephyrproject.io
195.201.196.60 deploy1.hzr.zephyrproject.io
176.9.9.8 cluams1.hzr.zephyrproject.io
95.217.36.118 cluams2.hzr.zephyrproject.io
88.198.52.47 cluams3.hzr.zephyrproject.io
37.27.230.14 cax162r1.hzr.zephyrproject.io
157.90.13.131 cax162r2.hzr.zephyrproject.io

172.24.0.10 rt1.mgmt.hzr.zephyrproject.io

10.128.0.10 rt1.cluster-a.hzr.zephyrproject.io
10.128.10.1 deploy1.cluster-a.hzr.zephyrproject.io
10.128.20.1 cluams1.cluster-a.hzr.zephyrproject.io
10.128.20.2 cluams2.cluster-a.hzr.zephyrproject.io
10.128.20.3 cluams3.cluster-a.hzr.zephyrproject.io
10.128.40.1 cax162r1.cluster-a.hzr.zephyrproject.io
10.128.40.2 cax162r2.cluster-a.hzr.zephyrproject.io
```
