provider "hcp" {
  project_id = var.hcp_project_id
}

resource "hcp_hvn" "example" {
  hvn_id         = "example"
  cloud_provider = "aws"
  region         = var.hcp_region
  cidr_block     = var.ip_cidr_hvn
}

resource "hcp_aws_network_peering" "example" {
  peering_id      = "example"
  hvn_id          = hcp_hvn.example.hvn_id
  peer_vpc_id     = aws_vpc.peer.id
  peer_account_id = aws_vpc.peer.owner_id
  peer_vpc_region = var.aws_region
}

data "hcp_aws_network_peering" "example" {
  hvn_id                = hcp_hvn.example.hvn_id
  peering_id            = hcp_aws_network_peering.example.peering_id
  wait_for_active_state = true
}

resource "hcp_hvn_route" "example" {
  hvn_link         = hcp_hvn.example.self_link
  hvn_route_id     = "example"
  destination_cidr = aws_vpc.peer.cidr_block
  target_link      = data.hcp_aws_network_peering.example.self_link
}

resource "hcp_vault_cluster" "this" {
  cluster_id      = "example"
  hvn_id          = hcp_hvn.example.hvn_id
  public_endpoint = var.hcp_vault_public
  tier            = var.hcp_vault_tier

  // lifecycle {
  //   prevent_destroy = true
  // }
}

resource "hcp_vault_cluster_admin_token" "admin" {
  cluster_id = hcp_vault_cluster.this.cluster_id
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "peer" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "example"
  }
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = hcp_aws_network_peering.example.provider_peering_id
  auto_accept               = true
}

resource "aws_subnet" "this" {
  cidr_block = var.subnet_prefix
  vpc_id     = aws_vpc.peer.id

  tags = {
    Name = "example"
  }
}

resource "aws_subnet" "rds-subnet" {
  vpc_id            = aws_vpc.peer.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}a"
  depends_on        = [aws_internet_gateway.hashidemos]
}

resource "aws_subnet" "rds-subnet-2" {
  vpc_id            = aws_vpc.peer.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.aws_region}b"
  depends_on        = [aws_internet_gateway.hashidemos]
}

resource "aws_db_subnet_group" "vault-db-subnet" {
  name       = "${var.prefix}-vault-db-subnet"
  subnet_ids = [aws_subnet.rds-subnet.id, aws_subnet.rds-subnet-2.id]
}

resource "aws_security_group" "hashidemos" {
  name   = "hashidemos-security-group"
  vpc_id = aws_vpc.peer.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.allowed-source-ip]
  }

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["10.0.0.0/16", var.ip_cidr_hvn]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example"
  }
}

resource "aws_security_group" "vault-mysql-sg" {
  name        = "${var.prefix}-vault-mysql-sg"
  description = "mysql security group"
  vpc_id      = aws_vpc.peer.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", var.ip_cidr_hvn]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "hashidemos" {
  vpc_id = aws_vpc.peer.id
}

resource "aws_route_table" "hashidemos" {
  vpc_id = aws_vpc.peer.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hashidemos.id
  }

  route {
    cidr_block                = var.ip_cidr_hvn
    vpc_peering_connection_id = hcp_aws_network_peering.example.provider_peering_id
  }

  tags = {
    Name = "example"
  }
}

resource "aws_route_table_association" "hashidemos" {
  route_table_id = aws_route_table.hashidemos.id
  subnet_id      = aws_subnet.this.id
}

resource "aws_route_table_association" "rds-subnet-1" {
  route_table_id = aws_route_table.hashidemos.id
  subnet_id      = aws_subnet.rds-subnet.id
}

resource "aws_route_table_association" "rds-subnet-2" {
  route_table_id = aws_route_table.hashidemos.id
  subnet_id      = aws_subnet.rds-subnet-2.id
}

resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "hashidemos" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.hashidemos.key_name
  subnet_id                   = aws_subnet.this.id
  vpc_security_group_ids      = [aws_security_group.hashidemos.id]

  user_data = templatefile("${path.module}/bastion.tpl", {
    mysql_address  = aws_db_instance.vault-mysql.endpoint
    mysql_user     = var.db_user
    mysql_password = random_password.password.result
    ssh_username   = var.ssh_username
    vault_addr     = hcp_vault_cluster.this.vault_private_endpoint_url
    vault_token    = hcp_vault_cluster_admin_token.admin.token
  })
}

resource "aws_db_instance" "vault-mysql" {
  allocated_storage      = 10
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.${var.db_instance_type}"
  identifier             = "${var.prefix}${var.mysql_dbname}"
  db_name                = "${var.prefix}${var.mysql_dbname}"
  vpc_security_group_ids = [aws_security_group.vault-mysql-sg.id]
  db_subnet_group_name   = aws_db_subnet_group.vault-db-subnet.id
  username               = var.db_user
  password               = random_password.password.result
  skip_final_snapshot    = true
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "*!-"
}
