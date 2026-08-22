PYTHON ?= python3

.PHONY: validate site-install site-dev site-build deploy-pages pdf epub clean

validate:
	$(PYTHON) scripts/validate_content.py

site-install:
	npm --prefix site install

site-dev:
	npm --prefix site run dev

site-build: validate
	npm --prefix site run build

deploy-pages:
	bash scripts/deploy_pages.sh

pdf: validate
	$(PYTHON) scripts/build_book.py --format pdf

epub: validate
	$(PYTHON) scripts/build_book.py --format epub

clean:
	rm -rf dist site/dist site/.astro site/public/assets
