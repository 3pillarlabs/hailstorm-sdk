clean:
	npm clean

install:
	npm ci

test:
	npm test -- --watchAll=false

coverage:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	npm test -- --watchAll=false --coverage

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t lcov; fi
