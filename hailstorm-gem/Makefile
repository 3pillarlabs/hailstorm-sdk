ifndef TAG_FLAGS
TAG_FLAGS = @smoke
endif

install:
	bundle install

test: create_mysql_user
	JRUBY_OPTS="--debug" rspec -f HailstormCiFormatter

coverage: create_mysql_user
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	HAILSTORM_COVERAGE="true" JRUBY_OPTS="--debug" rspec -f HailstormCiFormatter

setup_db:
	rake db:setup

create_mysql_user: setup_db
	if [ -n "${CI}" ]; \
	then \
		mysql -e 'grant all privileges on *.* to "hailstorm_dev"@"localhost" identified by "hailstorm_dev";'; \
	fi

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t simplecov; fi

integration:
	cucumber --tags ${TAG_FLAGS}

build:
	rake build

local_publish:
	rake install
