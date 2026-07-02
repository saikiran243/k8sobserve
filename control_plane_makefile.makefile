# include the hidden environment variables securely
include .env
export

REGION = us-east-1
CLUSTER_NAME = enterprise-gitops-demo

.PHONY: up down

up: 
	@echo "🏗️ Provisioning EKS via Terraform..."
	cd terraform && terraform init && terraform apply -auto-approve
	
	@echo "🔐 Linking Kubernetes config..."
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	
	@echo "🐶 Installing Datadog Agent..."
	helm repo add datadog https://helm.datadoghq.com
	helm upgrade --install datadog-agent datadog/datadog \
	  --set datadog.apiKey=$(DATADOG_API_KEY) \
	  --set clusterAgent.enabled=true \
	  --set datadog.logs.enabled=true \
	  --set datadog.logs.containerCollectAll=true
	
	@echo "🚢 Installing ArgoCD..."
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

down:
	@echo "🧨 Destroying EKS Cluster to save AWS credits..."
	cd terraform && terraform destroy -auto-approve