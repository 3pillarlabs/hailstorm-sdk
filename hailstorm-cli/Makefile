install:
	bundle install

test: create_mysql_user
	JRUBY_OPTS="--debug" rspec -f HailstormCiFormatter

coverage: create_mysql_user
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	HAILSTORM_COVERAGE="true" JRUBY_OPTS="--debug" rspec -f HailstormCiFormatter

create_mysql_user:
	if [ -n "${CI}" ]; \
	then \
		mysql -e 'grant all privileges on *.* to "hailstorm_dev"@"localhost" identified by "hailstorm_dev";'; \
	fi

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t simplecov; fi

build:
	rake build

package:
	docker build \
	--build-arg HAILSTORM_VERSION=$(shell ruby -I ./lib -r 'hailstorm/version' -e 'puts Hailstorm::VERSION') \
	--rm \
	-t hailstorm/hailstorm-cli:$(shell ruby -I ./lib -r 'hailstorm/cli/version' -e 'puts Hailstorm::Cli::VERSION') .

integration:
	docker run \
	-it \
	--rm \
	--network hailstorm-sdk_hailstorm_integration \
	-e DATABASE_HOST=hailstorm-db \
	hailstorm/hailstorm-cli:1.0.0 bash -c \
	'cd /usr/local/lib/hailstorm-cli && cucumber --tags @smoke'

open_console:
	docker run \
	-it \
	--rm \
	--network hailstorm-sdk_hailstorm \
	-e DATABASE_HOST=hailstorm-db \
	hailstorm/hailstorm-cli:1.0.0 bash

open_test_console:
	docker run \
	-it \
	--rm \
	--network hailstorm-sdk_hailstorm_integration \
	-e DATABASE_HOST=hailstorm-db \
	hailstorm/hailstorm-cli:1.0.0 bash
