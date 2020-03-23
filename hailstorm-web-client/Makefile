clean:
	npm run clean

install:
	npm ci --no-progress

test:
	npm test -- --watchAll=false

coverage:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	npm test -- --watchAll=false --coverage

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t lcov; fi

integration:
	cd e2e && \
	NODE_ENV=production npx wdio run wdio.smoke.conf.js

build:
	CI=false npm run build

package:
	find build -type f -exec cat {} + | sha1sum | cut -f1 -d' ' > BUILD_ID
	npm run package
