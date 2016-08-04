# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

.PHONY: help init clean test system-test

ROOT_REPO:=jupyter/all-spark-notebook:258e25c03cba
CONTAINER_NAME:=declarativewidgets-explorer
REPO:=jupyter/declarativewidgets-explorer:258e25c03cba

define INSTALL_DECLWID_CMD
pip install --no-binary ::all: $$(ls -1 /srv/*.tar.gz | tail -n 1) && \
jupyter declarativewidgets install --user && \
jupyter declarativewidgets activate
endef

define INSTALL_DASHBOARD_CMD
pip install --no-binary ::all: jupyter_dashboards && \
jupyter dashboards install --user && \
jupyter dashboards activate
endef

define INSTALL_LIBS
pip install numexpr
endef

init: node_modules
	@-docker $(DOCKER_OPTS) rm -f $(CONTAINER_NAME)
	@docker $(DOCKER_OPTS) run -it --user root --name $(CONTAINER_NAME) \
			-v `pwd`:/srv \
		$(ROOT_REPO) bash -c 'apt-get -qq update && \
		apt-get -qq install --yes curl && \
		curl --silent --location https://deb.nodesource.com/setup_0.12 | sudo bash - && \
		apt-get -qq install --yes nodejs npm && \
		ln -s /usr/bin/nodejs /usr/bin/node && \
		npm install -g bower && \
		$(INSTALL_DECLWID_CMD) && \
		$(INSTALL_DASHBOARD_CMD) && \
		$(INSTALL_LIBS)'
	@docker $(DOCKER_OPTS) commit $(CONTAINER_NAME) $(REPO)
	@-docker $(DOCKER_OPTS) rm -f $(CONTAINER_NAME)

node_modules: package.json
	@npm install --quiet

bower_components: node_modules bower.json
	@npm run bower -- install $(BOWER_OPTS)

run: SERVER_NAME?=urth_explorer_server
run: PORT_MAP?=-p 8888:8888
run: CMD?=jupyter notebook --no-browser --port 8888 --ip="*"
run:
	@docker $(DOCKER_OPTS) run --user root $(OPTIONS) --name $(SERVER_NAME) \
		$(PORT_MAP) \
		-e USE_HTTP=1 \
		-v `pwd`:/srv \
		-v `pwd`:/root/.local/share/jupyter/nbextensions/declarativewidgets/urth_components/declarativewidgets-explorer \
		--workdir '/srv/notebooks' \
		--user root \
		$(REPO) bash -c '$(CMD)'

test: bower_components
	@bower install ../widgets/elements/urth-core-behaviors/
	@bower install ../widgets/elements/urth-viz-behaviors/
	@npm test

clean:
	@-rm -rf bower_components node_modules

### System integration tests
BASEURL?=http://192.168.99.100:8888
BROWSER_LIST?=chrome
TEST_TYPE?=local
SPECS?=system-test/urth-viz-explorer-specs.js

remove-server:
	-@docker $(DOCKER_OPTS) rm -f $(SERVER_NAME)

sdist:

run-test: SERVER_NAME?=urth_widgets_integration_test_server
run-test: sdist remove-server
	@echo $(TEST_MSG)
	@OPTIONS=-d SERVER_NAME=$(SERVER_NAME) $(MAKE) run
	@echo 'Waiting for server to start...'
	@LIMIT=60; while [ $$LIMIT -gt 0 ] && ! docker logs $(SERVER_NAME) 2>&1 | grep 'Notebook is running'; do echo waiting $$LIMIT...; sleep 1; LIMIT=$$(expr $$LIMIT - 1); done
	@$(foreach browser, $(BROWSER_LIST), echo 'Running system integration tests on $(browser)...'; npm run system-test -- $(SPECS) --baseurl $(BASEURL) --test-type $(TEST_TYPE) --browser $(browser) || exit)
	@SERVER_NAME=$(SERVER_NAME) $(MAKE) remove-server

system-test-python3: TEST_MSG="Starting system tests for Python 3"
system-test-python3:
	TEST_MSG=$(TEST_MSG) TEST_TYPE=$(TEST_TYPE) BROWSER_LIST="$(BROWSER_LIST)" JUPYTER=$(JUPYTER) SPECS="$(SPECS)" BASEURL=$(BASEURL) $(MAKE) run-test

system-test-all: system-test-python3

start-selenium: node_modules stop-selenium
	@echo "Installing and starting Selenium Server..."
	@node_modules/selenium-standalone/bin/selenium-standalone install >/dev/null
	@node_modules/selenium-standalone/bin/selenium-standalone start 2>/dev/null & echo $$! > SELENIUM_PID

stop-selenium:
	-@kill `cat SELENIUM_PID`
	-@rm SELENIUM_PID

system-test-all-local: TEST_TYPE:="local"
system-test-all-local: start-selenium system-test-all stop-selenium

system-test-all-remote: TEST_TYPE:="remote"
system-test-all-remote: system-test-all

system-test:
ifdef SAUCE_USER_NAME
	@echo 'Running system tests on Sauce Labs...'
	@BROWSER_LIST="$(BROWSER_LIST)" JUPYTER=$(JUPYTER) SPECS="$(SPECS)" BASEURL=$(BASEURL) $(MAKE) system-test-all-remote
else ifdef TRAVIS
	@echo 'Starting system integration tests locally on Travis...'
	@BROWSER_LIST="firefox" ALT_BROWSER_LIST="firefox" JUPYTER=$(JUPYTER) SPECS="$(SPECS)" BASEURL=$(BASEURL) $(MAKE) system-test-all-local
else
	@echo 'Starting system integration tests locally...'
	@BROWSER_LIST="$(BROWSER_LIST)" JUPYTER=$(JUPYTER) SPECS="$(SPECS)" BASEURL=$(BASEURL) $(MAKE) system-test-all-local
endif
	@echo 'System integration tests complete.'
