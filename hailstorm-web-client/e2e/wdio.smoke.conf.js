const devConf = require('./wdio.conf');
devConf.config.baseUrl = 'http://localhost:8080';
devConf.config.cucumberOpts.tagExpression = '@smoke';
devConf.config.cucumberOpts.failFast = true;
exports.config = devConf.config;
