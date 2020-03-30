clean:
	./gradlew clean

install:
	./gradlew clean assemble

test:
	./gradlew test

coverage:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	./gradlew test jacocoTestReport

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t jacoco; fi

package:
	./gradlew build docker
