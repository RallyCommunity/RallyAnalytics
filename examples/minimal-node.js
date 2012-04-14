var AnalyticsQuery = require('../lib/analyticsquery.js').AnalyticsQuery;

var config = {
  'X-RallyIntegrationName': 'My Chart',
  'X-RallyIntegrationVendor': 'My Company',
  'X-RallyIntegrationVersion': '0.1.0'
};

var query = new AnalyticsQuery(config);

query.find({
  FormattedID: "S34854"
}).fields(true).debug();

var callback = function() {
  return console.log(this.allResults);
};

query.getAll(callback);
