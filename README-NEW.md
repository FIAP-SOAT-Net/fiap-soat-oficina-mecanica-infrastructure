# 🏗️ Oficina Mecânica Inteligente - Infraestrutura Kubernetes

Infraestrutura como Código (IaC) para deploy da aplicação Smart Mechanical Workshop na AWS usando EKS (Kubernetes) + Fargate, Terraform e GitHub Actions para CI/CD.

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-844FBA?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS_Fargate-FF9900?logo=amazonaws)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)

## 📋 Índice

- [Visão Geral](#-visão-geral)
  - [Por que essas tecnologias?](#por-que-essas-tecnologias)
- [Pré-requisitos](#-pré-requisitos)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Arquitetura](#-arquitetura)
- [Deploy da Infraestrutura](#-deploy-da-infraestrutura)
  - [Ambiente Local (Docker)](#ambiente-local-docker)
  - [Ambiente AWS (EKS + Fargate)](#ambiente-aws-eks--fargate)
- [Acesso à Aplicação](#-acesso-à-aplicação)
- [Pipeline CI/CD](#-pipeline-cicd)
- [Monitoramento](#-monitoramento)
- [Relatório de Custos](#-relatório-de-custos)
- [Segurança](#-segurança)
- [Troubleshooting](#-troubleshooting)
- [Destruição da Infraestrutura](#-destruição-da-infraestrutura)

## 🎯 Visão Geral

Este repositório gerencia toda a infraestrutura necessária para executar o sistema de gestão de oficina mecânica em dois ambientes:

- **AWS EKS com Fargate** - Cluster Kubernetes serverless gerenciado na nuvem
- **Terraform** - Provisionamento declarativo da infraestrutura
- **AWS Load Balancer Controller** - Gerenciamento automático de Network Load Balancers
- **Docker Compose** - Ambiente de desenvolvimento local
- **GitHub Actions** - Automação de deploy e CI/CD com OIDC
- **RDS MySQL** - Banco de dados gerenciado (provisionado pelo [repositório database](https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure-database))

### Por que essas tecnologias?

**AWS EKS (Elastic Kubernetes Service)**
- ✅ Kubernetes gerenciado pela AWS (sem manutenção do control plane)
- ✅ Integração nativa com serviços AWS (ALB, NLB, IAM, CloudWatch)
- ✅ Alta disponibilidade e auto-scaling automático
- ✅ Suporte para Fargate (serverless) e EC2 nodes

**AWS Fargate**
- ✅ Serverless - sem necessidade de gerenciar instâncias EC2
- ✅ Pague apenas pelo que usar (CPU/memória por segundo)
- ✅ Fargate Spot economiza até 70% vs Fargate regular
- ✅ Segurança aprimorada (isolamento por pod)
- ✅ Auto-scaling nativo sem configuração adicional

**Terraform**
- ✅ Infraestrutura como código versionada no Git
- ✅ Previsibilidade com `plan` antes de aplicar mudanças
- ✅ Estado compartilhado entre equipe via S3
- ✅ Reutilizável em múltiplos ambientes (dev/staging/prod)

**AWS Load Balancer Controller**
- ✅ Cria automaticamente NLB/ALB para serviços Kubernetes
- ✅ Integração nativa com target groups (IP mode para Fargate)
- ✅ Suporte a annotations para configuração avançada
- ✅ Health checks automáticos

**GitHub Actions**
- ✅ CI/CD nativo do GitHub
- ✅ Autenticação OIDC segura (sem access keys)
- ✅ Deploy automático ao fazer push na main
- ✅ Workflow para gerenciar acesso de usuários ao cluster

## ✅ Pré-requisitos

### Para Desenvolvimento Local

- [Docker](https://docs.docker.com/get-docker/) 20.10+ e [Docker Compose](https://docs.docker.com/compose/install/) 2.0+
- [Git](https://git-scm.com/downloads) para clonar o repositório

### Para Deploy na AWS

- [AWS CLI](https://aws.amazon.com/cli/) 2.x configurado
- [Terraform](https://www.terraform.io/downloads) 1.5+
- [kubectl](https://kubernetes.io/docs/tasks/tools/) 1.28+
- [Helm](https://helm.sh/docs/intro/install/) 3.x
- Conta AWS com permissões adequadas
- Acesso ao repositório GitHub

### Recursos AWS Necessários

- **VPC** com subnets públicas e privadas
- **RDS MySQL** provisionado ([ver repositório database](https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure-database))
- **IAM Role** com OIDC Provider para GitHub Actions
- **S3 Bucket** para estado do Terraform

