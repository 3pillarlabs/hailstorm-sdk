const devConf = require('./wdio.conf');
devConf.config.baseUrl = 'http://localhost:8080';
devConf.config.specs = ['./features/amazon_cloud_load_generation.feature']
devConf.config.cucumberOpts.failFast = true;
devConf.config.logLevel = 'info';
// devConf.config.cucumberOpts.tagExpression = '@focus';
exports.config = devConf.config;
