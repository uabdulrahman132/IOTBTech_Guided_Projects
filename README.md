# AWS VPC + Ansible bootstrap: 1 master, 1 control

Terraform provisions a VPC, a **master** node and a **control** node. The
master's `user_data` script installs Ansible and writes `~/.ansible.cfg`, the
inventory and the playbook onto it. After `terraform apply` you can SSH into the
master and run the playbook - nothing else to install or configure. The playbook
installs Docker on the control node and runs an Nginx container on port 80.

> **Region note:** `eu-east-1` is not an AWS region. Set `aws_region` in
> `terraform.tfvars` to a real region (for example `us-east-1` or `eu-west-1`).

## Layout

```
.
└── terraform/
    ├── main.tf                   # provider, VPC, security group, both instances
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    ├── backend.tf.example        # S3 remote state (copy to backend.tf)
    ├── terraform.tfvars.example
    ├── ansible/                  # shipped to the master node by user_data
    │   ├── ansible.cfg
    │   └── playbook.yml          # Docker + Nginx on the control nodes
    └── templates/
        ├── setup-master.sh.tftpl # cloud-init script for the master
        └── hosts.ini.tftpl       # inventory template
```

## Prerequisites

- Terraform >= 1.6
- AWS credentials in your environment (`AWS_PROFILE`, SSO, or env vars). Never
  put credentials in `.tf` or `.tfvars` files.
- An SSH key pair. To create one:
  `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519`

You do **not** need Ansible locally - it runs on the master node.

## Usage

### 1. Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: every variable must be set (there are no defaults).
# Set admin_cidrs to your IP: curl -s https://checkip.amazonaws.com  ->  ["x.x.x.x/32"]
```

### 2. (Recommended) Remote state

Create a private, versioned, encrypted S3 bucket, then:

```bash
cp backend.tf.example backend.tf   # edit bucket/key/region
```

This matters here: the private key is injected into the master's user data, so
it ends up in the state file. Keep the state in encrypted remote storage.

### 3. Provision

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

### 4. Wait for the master's setup (2-4 minutes)

```bash
terraform output -raw ssh_master   # copy this command, then:
ssh -i ~/.ssh/id_ed25519 ubuntu@<master-ip> "while [ ! -f ~/.ansible-ready ]; do sleep 5; done"
```

The script installs Ansible and writes `/home/ubuntu/.ansible.cfg`,
`/home/ubuntu/ansible/hosts.ini` and `/home/ubuntu/ansible/playbook.yml`.
The inventory uses the control node's private IP, so no further editing is
needed.

### 5. Run the playbook

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<master-ip>
ansible-playbook ~/ansible/playbook.yml
```

Re-running the playbook should report `changed=0`.

### 6. Verify

```bash
curl http://$(terraform output -raw control_public_ip)
curl http://$(terraform output -raw control_public_ip)/healthz
```

### 7. Tear down

```bash
terraform destroy
```

## Variables

All variables are **required** and are set in `terraform/terraform.tfvars`
(gitignored - copy `terraform.tfvars.example`).

| Name | Description |
|------|-------------|
| `aws_region` | AWS region, e.g. `us-east-1`. |
| `project_name` | Resource name prefix, e.g. `iac-demo`. |
| `environment` | Environment tag/name part, e.g. `dev`. |
| `vpc_cidr` | VPC CIDR, e.g. `10.0.0.0/16`. |
| `public_subnet_cidr` | Public subnet CIDR, e.g. `10.0.1.0/24`. |
| `instance_type` | x86_64 instance type for both nodes, e.g. `t3.micro`. |
| `root_volume_size_gb` | Root volume size in GiB, e.g. `20`. |
| `ssh_public_key_path` | Public key uploaded as the key pair. |
| `ssh_private_key_path` | Read by Terraform and handed to the master so Ansible can reach the control node. |
| `admin_cidrs` | CIDRs allowed to SSH. `0.0.0.0/0` is rejected. |
| `http_ingress_cidrs` | CIDRs allowed to reach port 80, e.g. `["0.0.0.0/0"]`. |

Ansible variables (image tag, port, paths) are at the top of
`terraform/ansible/playbook.yml`.

## Design notes

- **One security group for both nodes:** admin -> 22, `http_ingress_cidrs` -> 80,
  plus a self-referencing rule so the master can SSH to the control node.
  Egress is limited to 80/443 (apt, pip, Docker Hub) and SSH to the group itself.
- **Keys:** both nodes use your own key pair, so `ssh -i ~/.ssh/id_ed25519 ...`
  works for both your machine and the master -> control hop. The private key is
  read by Terraform and written to `/home/ubuntu/.ssh/id_ed25519` on the master;
  it therefore lives in the state file - use encrypted remote state, or point
  `ssh_private_key_path` at a dedicated throwaway key.
- **`user_data` only runs at boot**, so `user_data_replace_on_change = true` is
  set: changing `ansible.cfg` or the playbook replaces the master and re-runs the
  setup. You can also edit the files on the master directly.
- **Idempotency:** Ansible uses declarative modules only; Terraform ignores AMI
  drift (`ignore_changes = [ami]`) so a new Ubuntu image doesn't replace running
  nodes.
- **Nginx and "a container on port 80":** both ports can't be bound by separate
  processes, so the container *is* Nginx. The playbook writes the Nginx config
  and landing page onto the host and bind-mounts them read-only into the
  container.
- **Not included (add for real production):** private subnets + NAT or SSM-only
  access, VPC flow logs, CloudWatch agent/alarms, TLS (ACM + ALB or certbot),
  and a CI pipeline.

## Troubleshooting

- `Invalid region` during plan: check `aws_region`.
- SSH timeouts: your IP changed; update `admin_cidrs` and re-apply.
- `~/.ansible-ready` never appears: check the setup log on the master with
  `ssh ... 'sudo tail -f /var/log/cloud-init-output.log'`.
- The master was replaced: your public IP changed (`admin_cidrs`) or you edited
  the Ansible files - re-run step 4 and 5.
