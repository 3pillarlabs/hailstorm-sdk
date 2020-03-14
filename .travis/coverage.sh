#!/bin/sh
# Module for fetching CodeClimate test reporter and uploading coverage reports in a monorepository

# Common paths
CC_TEST_REPORTER=$TRAVIS_BUILD_DIR/cc-test-reporter

install_reporter() {
  if [ ! -e $CC_TEST_REPORTER ]
  then
    curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > $CC_TEST_REPORTER
    chmod +x $CC_TEST_REPORTER
  fi

  $CC_TEST_REPORTER before-build
}

# Pipes the coverage data to Code Climate
upload_coverage() {
  if [ "$TRAVIS_TEST_RESULT" != 0 ]
  then
    return $TRAVIS_TEST_RESULT
  fi

  local project=$1
  local coverage_type=$2
  local overall_cov_path=$TRAVIS_BUILD_DIR/coverage-overall

  if [ -z $coverage_type ]; then
    coverage_type="simplecov"
  fi

  if [ $coverage_type = "simplecov" ]; then
    coverage_file=coverage/spec/.resultset.json
  fi

  if [ $coverage_type = "jacoco" ]; then
    JACOCO_SOURCE_PATH=$TRAVIS_BUILD_DIR/$project/src/main/java
    coverage_file=build/reports/jacoco/test/jacocoTestReport.xml
  fi

  if [ $coverage_type = "lcov" ]; then
    coverage_file=coverage/lcov.info
  fi

  mkdir -p $overall_cov_path

  $CC_TEST_REPORTER format-coverage \
    --add-prefix "$project" \
    -t $coverage_type \
    -o $TRAVIS_BUILD_DIR/$project/coverage/codeclimate.$CI_NODE_INDEX.json \
    $TRAVIS_BUILD_DIR/$project/$coverage_file

  cp $TRAVIS_BUILD_DIR/$project/coverage/codeclimate.$CI_NODE_INDEX.json $overall_cov_path

  aws s3 sync $overall_cov_path/ s3://$S3_BUCKET_NAME/coverage/$TRAVIS_BUILD_NUMBER
  aws s3 sync s3://$S3_BUCKET_NAME/coverage/$TRAVIS_BUILD_NUMBER $overall_cov_path/

  $CC_TEST_REPORTER sum-coverage \
    --output - --parts $CI_NODE_TOTAL \
    $overall_cov_path/codeclimate.*.json | $CC_TEST_REPORTER upload-coverage --input -
}

while getopts 'it:u:' c
do
  case $c in
    i) install_reporter ;;
    t) COVERAGE_TYPE=$OPTARG ;;
    u) UPLOAD_COVERAGE=$OPTARG ;;
  esac
done

if [ -n $UPLOAD_COVERAGE ]; then
  upload_coverage $UPLOAD_COVERAGE $COVERAGE_TYPE
fi
