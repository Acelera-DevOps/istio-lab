.PHONY: help apply chaos-enable chaos-disable verify status clean

NAMESPACE := payments-mesh

help: ## Show available Istio Service Mesh lab commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

apply: ## Deploy baseline namespace, workloads (v1/v2), Gateway, Canary VirtualService, DestinationRule & STRICT mTLS
	kubectl apply -f manifests/00-namespace.yaml
	kubectl apply -f manifests/01-workloads-v1-v2.yaml
	kubectl apply -f manifests/02-gateway.yaml
	kubectl apply -f manifests/03-virtualservice-canary.yaml
	kubectl apply -f manifests/04-destinationrule-resilience.yaml
	kubectl apply -f manifests/05-security-mtls-rbac.yaml

chaos-enable: ## Enable HTTP 503 abort (5%) & fixed latency delay (2s on 10%) fault injection
	kubectl apply -f manifests/06-chaos-fault-injection.yaml

chaos-disable: ## Restore normal 90/10 Canary routing without fault injection
	kubectl apply -f manifests/03-virtualservice-canary.yaml

verify: ## Run automated verification script against the payments-mesh namespace
	bash scripts/verify-mesh.sh

status: ## Inspect Pods, Envoy sidecars, VirtualServices, DestinationRules and mTLS policies
	kubectl get pods,svc,virtualservices,destinationrules,peerauthentications,authorizationpolicies -n $(NAMESPACE)

clean: ## Delete the payments-mesh namespace and all lab resources
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
