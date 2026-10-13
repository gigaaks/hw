.DEFAULT_GOAL := help

# Main targets that candidates should implement
.PHONY: deploy_podinfo
deploy_podinfo: #_check_kubectl _check_helm # Deploy podinfo application
	echo "deploy_podinfo"
	helm repo add podinfo https://stefanprodan.github.io/podinfo --force-update
	helm repo update
	helm upgrade --install podinfo podinfo/podinfo --namespace podinfo --create-namespace -f apps/podinfo/values.yaml --wait

.PHONY: update_podinfo
update_podinfo: _check_kubectl _check_helm ## Update pod replicas
	echo "update_pods"
	helm repo add podinfo https://stefanprodan.github.io/podinfo --force-update
	helm repo update
	helm upgrade --install podinfo podinfo/podinfo --namespace podinfo -f apps/podinfo/values-update.yaml --wait

.PHONY: deploy_backend
deploy_backend: _check_kubectl _check_helm _validate_config ## Deploy backend services
	echo "deploy_backend"
	kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f apps/nginx/
	kubectl rollout status deployment/nginx -n nginx --timeout=120s
	helm repo add podinfo https://stefanprodan.github.io/podinfo --force-update
	helm repo update
	helm upgrade --install podinfo podinfo/podinfo --namespace podinfo --create-namespace -f apps/podinfo/values-backend.yaml --wait
	kubectl run podinfo-backend-test --namespace podinfo --image=curlimages/curl:8.12.1 --restart=Never --rm -i --command -- curl -fsS http://podinfo:5050/echo

# Internal helper targets (prefixed with _)
.PHONY: _check_kubectl
_check_kubectl: ## Verify kubectl is installed
	which kubectl > /dev/null || (echo "kubectl not found" && exit 1)

.PHONY: _check_helm
_check_helm: ## Verify helm is installed
	@which helm > /dev/null || (echo "helm not found" && exit 1)

.PHONY: _validate_config
_validate_config: ## Validate configuration files
	echo "config validation"
	kubectl apply --dry-run=client -f apps/nginx/
	echo 
	kubectl apply --dry-run=server -f apps/nginx/
	echo 
	helm repo add podinfo https://stefanprodan.github.io/podinfo --force-update
	helm repo update
	echo 
	helm pull podinfo/podinfo --untar --untardir /tmp
	echo
	helm lint /tmp/podinfo -f apps/podinfo/values.yaml
	helm lint /tmp/podinfo -f apps/podinfo/values-update.yaml	
	helm lint /tmp/podinfo -f apps/podinfo/values-backend.yaml
	rm -fr /tmp/podinfo

# Help targets
.PHONY: help
help: ## Show available main targets
	echo "Available targets:"
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -v '^_' | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	echo ""
	echo "Run 'make internal-help' to see internal helper targets"

.PHONY: internal-help
internal-help: ## Show internal helper targets
	echo "Internal helper targets:"
	grep -E '^_[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[33m%-20s\033[0m %s\n", $$1, $$2}'

