ifndef TAG_FLAGS
TAG_FLAGS = @smoke
endif

install:
	bundle install

test: create_mysql_user setup_db
	JRUBY_OPTS="--debug" bundle exec rspec -f HailstormCiFormatter

coverage: create_mysql_user setup_db
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	HAILSTORM_COVERAGE="true" JRUBY_OPTS="--debug" bundle exec rspec -f HailstormCiFormatter

setup_db:
	bundle exec rake db:setup

create_mysql_user:
	if [ -n "${CI}" ]; \
	then \
		mysql -e 'grant all privileges on *.* to "hailstorm_dev"@"localhost" identified by "hailstorm_dev";'; \
	fi

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t simplecov; fi

integration: create_mysql_user setup_db
	${TRAVIS_BUILD_DIR}/.travis/write_gem_aws_keys.sh
	bundle exec cucumber --tags ${TAG_FLAGS}

.PHONY: build
build:
	bundle exec rake clean build

local_publish:
	bundle exec rake install

validate:
	if ${TRAVIS_BUILD_DIR}/.travis/build-condition.sh ${TRAVIS_COMMIT_RANGE} hailstorm-gem/lib; then \
		${TRAVIS_BUILD_DIR}/.travis/build-condition.sh ${TRAVIS_COMMIT_RANGE} hailstorm-gem/lib/hailstorm/version.rb; \
		[ $$? -eq 0 ]; \
	fi
