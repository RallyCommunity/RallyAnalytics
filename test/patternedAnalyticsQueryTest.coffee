{XHRMock} = require('../mock/XHRMock')
rally_analytics = require('../')
{AtAnalyticsQuery, BetweenAnalyticsQuery, AtArrayAnalyticsQuery, TimeInStateAnalyticsQuery, PreviousToCurrenAnalyticsQuery} = rally_analytics

basicConfig =
  'X-RallyIntegrationName'     : 'testName'
  'X-RallyIntegrationVendor'   : 'testRally'
  'X-RallyIntegrationVersion'  : '0.1.0'
  workspaceOID: 12345

exports.patternedAnalyticsQueryTest =

  setUp: (callback) ->
    XHRMock.sendCount = 0
    callback()
    
  testConstructor: (test) ->
    config =
      'X-RallyIntegrationName'     : 'testName'
      'X-RallyIntegrationVendor'   : 'testRally'
      'X-RallyIntegrationVersion'  : '0.1.0'
      additionalHeaders: { 
        myHeader: 'myHeader'
      }
      username: 'anyone@anywhere.com' # If left off, will prompt user
      password: 'xxxxx'
      workspaceOID: 12345
    
    query = new AtAnalyticsQuery(config, 'hello', '2012-01-01T00:00:00.000Z')
    query.XHRClass = XHRMock
    
    test.equal(query.XHRClass, XHRMock)
    test.ok(query.headers['myHeader']?)
    test.equal(query.headers['X-RallyIntegrationName'], 'testName')
    test.equal(query.headers['X-RallyIntegrationVendor'], 'testRally')
    test.equal(query.headers['X-RallyIntegrationVersion'], '0.1.0')
    test.equal(query.username, 'anyone@anywhere.com')
    test.equal(query.password, 'xxxxx')
    
    test.done()
    
  testThrowsMissingAtDate: (test) ->    
    f = () ->
      query = new AtAnalyticsQuery(basicConfig)
      
    test.throws(f, Error)
    
    test.done()
        
  testGetPageHappy: (test) ->
    test.expect(2)
    query = new BetweenAnalyticsQuery(basicConfig, 'hello', '2012-01-01T00:00:00.000Z', '2012-04-01T00:00:00.000Z')
    query.XHRClass = XHRMock    

    callback = (lastPageResults, startOn, endBefore, aqInstance) ->
      expectedText = '''{
      	"_rallyAPIMajor": "1", 
      	"_rallyAPIMinor": "27", 
      	"Errors": [], 
      	"Warnings": [], 
      	"TotalResultCount": 5, 
      	"StartIndex": 0,
        "PageSize": 3,
        "ETLDate": "2012-03-16T21:01:17.802Z",
        "Results": [
          {"id": 1, "_ValidFrom": "2012-03-16T21:01:17.000Z"},
          {"id": 2, "_ValidFrom": "2012-03-16T21:01:17.001Z"},
          {"id": 3, "_ValidFrom": "2012-03-16T21:01:17.002Z"}
      	]
      }'''
      expectedResponse = JSON.parse(expectedText)
      test.deepEqual(aqInstance.lastResponse, expectedResponse)
      test.deepEqual(lastPageResults, [
        {"id": 1, "_ValidFrom": "2012-03-16T21:01:17.000Z"},
        {"id": 2, "_ValidFrom": "2012-03-16T21:01:17.001Z"}
      ])
      test.done()
      
    query.scope('Project', 1234)
    query.getPage(callback)

    