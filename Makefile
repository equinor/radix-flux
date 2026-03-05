
.PHONY: test
test:
	@for f in $$(find . -iname "kustomization.yaml"); do \
		echo "Running kustomize build $$(dirname $$f)..."; \
		kubectl kustomize $$(dirname $$f) >/dev/null || exit; \
	done
