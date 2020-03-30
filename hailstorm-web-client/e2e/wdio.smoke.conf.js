const devConf = require('./wdio.conf');
devConf.config.baseUrl = 'http://localhost:8080';
devConf.config.cucumberOpts.tagExpression = '@smoke';
exports.config = devConf.config;
