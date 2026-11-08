.PHONY: test package verify
PYTHON ?= python3

test:
	$(PYTHON) scripts/test.py

package:
	$(PYTHON) scripts/build.py

verify:
	$(PYTHON) scripts/verify_package.py dist/UiharuXPro4MilkyWay-0.1.0.tipa
