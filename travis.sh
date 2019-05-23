#!/bin/sh

usage()
{
  echo "Usage: $0 [-s|-b|-a|-d|-h]"
  return 2
}

script()
{
  local wdir=$(basename $(dirname $BUNDLE_GEMFILE))
  local spec_db=$(echo $wdir | perl -pe 's/\-/_/')
  cd $wdir
  HAILSTORM_COVERAGE="true" JRUBY_OPTS="--debug" HAILSTORM_SPEC_DB="$spec_db" rspec -f HailstormCiFormatter
  local test_result=$?
  cd ../
  return $test_result
}

before_script()
{
  mysql -e 'grant all privileges on *.* to "hailstorm_dev"@"localhost" identified by "hailstorm_dev";'
  if [ ! -e ./cc-test-reporter ]
  then
    curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > ./cc-test-reporter
    chmod +x ./cc-test-reporter
  fi
  ./cc-test-reporter before-build
}

after_script()
{
  if [ "$TRAVIS_TEST_RESULT" != 0 ]
  then
    return $TRAVIS_TEST_RESULT
  fi

  # Pipe the coverage data to Code Climate
  local overall_cov_dir="coverage-overall"
  mkdir -p $overall_cov_dir
  local wdir=$(basename $(dirname $BUNDLE_GEMFILE))
  cd $wdir
  ../cc-test-reporter format-coverage \
    --add-prefix "$wdir" \
    -t simplecov \
    -o ./coverage/codeclimate.$CI_NODE_INDEX.json \
    ./coverage/spec/.resultset.json

  cp ./coverage/codeclimate.$CI_NODE_INDEX.json ../$overall_cov_dir
  cd ../

  aws s3 sync $overall_cov_dir/ s3://$S3_BUCKET_NAME/coverage/$TRAVIS_BUILD_NUMBER
  aws s3 sync s3://$S3_BUCKET_NAME/coverage/$TRAVIS_BUILD_NUMBER $overall_cov_dir/

  ./cc-test-reporter sum-coverage \
    --output - --parts $CI_NODE_TOTAL \
    ./$overall_cov_dir/codeclimate.*.json | ./cc-test-reporter upload-coverage --input -
}

run()
{
  export CC_TEST_REPORTER_ID=3e42f82fe2b2f0601cafe4eca93a8c9d296dfa8f7af67d2e846a182a834bde59
  export CI_NODE_TOTAL=2
  CI_NODE_INDEX=-1
  for bundle_file in hailstorm-gem/Gemfile hailstorm-cli/Gemfile
  do
    BUNDLE_GEMFILE="$PWD/$bundle_file"
    export BUNDLE_GEMFILE
    CI_NODE_INDEX=$(expr $CI_NODE_INDEX + 1)
    export CI_NODE_INDEX
    before_script
    script
    after_script
  done
}

echo "Active Gemfile: $BUNDLE_GEMFILE"
while getopts 'sbadh' c
do
  case $c in
    s) script ;;
    b) before_script;;
    a) after_script ;;
    d) run ;;
    h|?) usage ;;
  esac
done
