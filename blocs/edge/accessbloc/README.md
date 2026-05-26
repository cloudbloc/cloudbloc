# AccessBloc (Edge) - Tailscale Access Gateway

AccessBloc deploys a Tailscale node into a homelab or Tiny Kubernetes cluster. It is intended to provide private tailnet access to a local network without exposing inbound ports.

It can run as:

- a tailnet node with a stable hostname
- a subnet router for LAN CIDRs
- an optional exit node
- an optional Tailscale SSH target

## What Terraform Manages

- Kubernetes namespace
- optional Kubernetes Secret for `TS_AUTHKEY`
- ServiceAccount
- PVC for Tailscale state
- Deployment running `tailscale/tailscale:stable`
- `/dev/net/tun` hostPath mount
- `NET_ADMIN` and `NET_RAW` container capabilities

## What You Must Provide

- A working Kubernetes cluster on the Tiny.
- A kubeconfig on the Terraform runner.
- `/dev/net/tun` available on the Tiny.
- IP forwarding enabled on the Tiny when advertising subnet routes or exit-node access.
- A Tailscale auth key stored in a Kubernetes Secret, or passed through `auth_key`.
- Tailnet admin approval for advertised subnet routes or exit-node use.

For a public repo, prefer creating the auth-key Secret manually. Passing `auth_key` to Terraform is supported, but stores the sensitive value in Terraform state.

## Manual Restore Checklist

1. Install the OS and Kubernetes on the Tiny.

2. Confirm the TUN device exists:

   ```bash
   test -c /dev/net/tun
   ```

3. Enable IP forwarding if advertising routes or exit-node access:

   ```bash
   sudo sysctl -w net.ipv4.ip_forward=1
   sudo sysctl -w net.ipv6.conf.all.forwarding=1
   ```

   Persist these settings through your OS network/sysctl configuration if this node must survive reboot.

4. Copy kubeconfig to the Terraform runner and verify access:

   ```bash
   kubectl --kubeconfig ~/.kube/edge get nodes
   ```

5. Create a reusable or ephemeral Tailscale auth key in the Tailscale admin console.

6. Create the namespace and Kubernetes Secret outside git:

   ```bash
   kubectl --kubeconfig ~/.kube/edge create namespace accessbloc
   kubectl --kubeconfig ~/.kube/edge -n accessbloc create secret generic tailscale-auth \
     --from-literal=TS_AUTHKEY='tskey-auth-REPLACE_ME'
   ```

7. Apply Terraform from your AccessBloc root:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

8. Approve subnet routes or exit-node use in the Tailscale admin console if configured.

9. Validate:

   ```bash
   kubectl --kubeconfig ~/.kube/edge -n accessbloc get pods
   kubectl --kubeconfig ~/.kube/edge -n accessbloc logs deploy/accessbloc
   ```

## Example

```hcl
module "accessbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/accessbloc"

  namespace          = "accessbloc"
  create_namespace   = false
  app_name           = "accessbloc"
  tailscale_hostname = "tiny-accessbloc"

  # Secret must exist before apply:
  # kubectl -n accessbloc create secret generic tailscale-auth \
  #   --from-literal=TS_AUTHKEY='tskey-auth-REPLACE_ME'
  auth_key_secret_name = "tailscale-auth"

  # Example LAN behind the Tiny.
  advertise_routes = ["10.0.0.0/24"]
}
```

## Inputs

| Variable | Description |
| --- | --- |
| `namespace` | Kubernetes namespace. |
| `create_namespace` | Whether Terraform should create the namespace. |
| `app_name` | Name used for resources. |
| `image` | Tailscale image. |
| `auth_key` | Optional auth key. Prefer an existing Secret for public repos. |
| `auth_key_secret_name` | Secret containing the auth key. |
| `auth_key_secret_key` | Secret key containing the auth key. |
| `tailscale_hostname` | Hostname registered in the tailnet. |
| `advertise_routes` | CIDR routes advertised by this node. |
| `accept_routes` | Whether to accept routes from the tailnet. |
| `advertise_exit_node` | Whether to advertise this node as an exit node. |
| `enable_ssh` | Whether to enable Tailscale SSH. |
| `extra_args` | Extra `tailscale up` arguments. |
| `host_network` | Whether to use the host network namespace. |
| `privileged` | Whether the Tailscale container runs privileged. |
| `state_storage_size` | PVC size for state. |
| `state_storage_class_name` | StorageClass for state PVC. |

## Security Notes

- Do not commit Tailscale auth keys.
- Do not commit kubeconfigs.
- Use ephemeral auth keys when possible.
- Approve only the subnet routes that should be reachable from the tailnet.
- ACLs and device/user permissions are managed in Tailscale, not this module.
