PYTHON ?= python3

.PHONY: test check-k kompile k-tests

test:
	$(PYTHON) -m unittest discover -s tests -v

check-k:
	@command -v kompile >/dev/null 2>&1 && echo "K toolchain found" || (echo "K toolchain not installed in this environment"; exit 2)

kompile: check-k
	kompile k/srw3.k --backend haskell

k-tests: kompile
	krun k/tests/cm01-local-vs-global.srw3 --definition .
