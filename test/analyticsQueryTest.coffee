{XHRMock} = require('../mock/XHRMock')
rally_analytics = require('../')
{AnalyticsQuery} = rally_analytics

basicConfig =
  'X-RallyIntegrationName'     : 'testName'
  'X-RallyIntegrationVendor'   : 'testRally'
  'X-RallyIntegrationVersion'  : '0.1.0'
  workspaceOID: 12345

exports.analyticsQueryTest =

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
    
    query = new AnalyticsQuery(config)
    query.XHRClass = XHRMock
    test.equal(query.XHRClass, XHRMock)
    test.ok(query.headers['myHeader']?)
    test.equal(query.headers['X-RallyIntegrationName'], 'testName')
    test.equal(query.headers['X-RallyIntegrationVendor'], 'testRally')
    test.equal(query.headers['X-RallyIntegrationVersion'], '0.1.0')
    test.equal(query.username, 'anyone@anywhere.com')
    test.equal(query.password, 'xxxxx')
    
    test.done()
    
  testMissingRequiredConfiguration: (test) ->
    f = () ->
      config =
        'X-RallyIntegrationName'     : 'testName'
        'X-RallyIntegrationVendor'   : 'testRally'
        'X-RallyIntegrationVersion'  : '0.1.0'
        workspaceOID: 12345
      r = new AnalyticsQuery(config)
      
    f()  # just to confirm that it doesn't fail with the four above required configuration values

    f1 = () ->
      config1 =
        'X-RallyIntegrationName'     : 'testName'
        'X-RallyIntegrationVendor'   : 'testRally'
        workspaceOID: 12345
      r1 = new AnalyticsQuery(config1)
        
    test.throws(f1, Error)
    
    test.done()
    
  testBaseURL: (test) ->
    query = new AnalyticsQuery(basicConfig)
    query.version = 'v2.0'
    baseURL = query.getBaseURL()
    test.equal(baseURL, 'https://rally1.rallydev.com/analytics/v2.0/service/rally/workspace/12345/artifact/snapshot/query.js')
  
    test.done()
  
  testSetQuery: (test) ->
    query = new AnalyticsQuery(basicConfig)
    r2 = query.find({Project: 1234, Tag: 'Expedited', _At: '2012-01-01'})
    test.equal(r2, query)  # confirm chaining
    expected = 'find={"Project":1234,"Tag":"Expedited","_At":"2012-01-01"}&sort={"_ValidFrom":1}&start=0&pagesize=10000000'
    test.equal(decodeURIComponent(query.getQueryString()), expected)   
        
    test.done()
    
  testGetPageHappy: (test) ->
    test.expect(11)
    query = new AnalyticsQuery(basicConfig, 'hello')
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
      test.equal(lastPageResults.length, 2)
      test.equal(startOn, 'hello')
      test.equal(endBefore, "2012-03-16T21:01:17.002Z")

      aqInstance.getPage(callback2)

    callback2 = (lastPageResults, startOn, endBefore, aqInstance) ->
      test.deepEqual(lastPageResults, [
        {"id": 3, "_ValidFrom": "2012-03-16T21:01:17.002Z"},
        {"id": 4, "_ValidFrom": "2012-03-16T21:01:17.003Z"}
        {"id": 5, "_ValidFrom": "2012-03-16T21:01:17.004Z"}
      ])
      test.equal(startOn, '2012-03-16T21:01:17.002Z')
      test.equal(endBefore, "2012-03-16T21:01:17.802Z")

      test.equal(aqInstance.allResults.length, 5)
      test.ok(!aqInstance.hasMorePages())

      f = () ->
        aqInstance.getPage(callback4)

      test.throws(f, Error)

      test.done()

    callback4 = (lastPageResults, startOn, endBefore, aqInstance) ->
      test.ok(false)  # This should never run
      test.done()
      
    query.find({Project: 1234, _At: '2012-01-01'})
    query.getPage(callback)
    
  testGetPageMissingFind: (test) ->
    query = new AnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock

    callback = () ->
      test.done()
      
    f = () ->
      query.getPage(callback)
      
    test.throws(f, Error)
    
    test.done()
    