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
    query.version = '1.29'
    baseURL = query.getBaseURL()
    test.equal(baseURL, 'https://rally1.rallydev.com/analytics/1.29/12345/artifact/snapshot/query.js')
  
    test.done()
  
  testSetQuery: (test) ->
    query = new AnalyticsQuery(basicConfig)
    r2 = query.find({Project: 1234, Tag: 'Expedited', _At: '2012-01-01'})
    test.equal(r2, query)  # confirm chaining
    expected = 'find={"Project":1234,"Tag":"Expedited","_At":"2012-01-01"}&sort={"_ValidFrom":1}&start=0&pagesize=100000'
    test.equal(decodeURIComponent(query.getQueryString()), expected)   
        
    test.done()
    
  testGetAllHappy: (test) ->
    test.expect(3)
    query = new AnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock

    callback = () ->
      expectedText = '''{
      	"_rallyAPIMajor": "1", 
      	"_rallyAPIMinor": "27", 
      	"Errors": [], 
      	"Warnings": [], 
      	"TotalResultCount": 5, 
      	"StartIndex": 4, 
      	"PageSize": 2, 
      	"ETLDate": "2012-03-16T21:01:17.802Z", 
      	"Results": [
      		{"id": 5}
      	]
      }'''
      expectedResponse = JSON.parse(expectedText)
      test.equal(this.lastResponseText, expectedText)
      test.deepEqual(this.lastResponse, expectedResponse)
      test.deepEqual(this.allResults, [
        {id: 1},
        {id: 2},
        {id: 3},
        {id: 4},
        {id: 5}
      ])
      test.done()
      
    query.find({Project: 1234, _At: '2012-01-01'})
    query.getAll(callback)
    
  testGetAllMissingFind: (test) ->
    query = new AnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock

    callback = () ->
      test.done()
      
    f = () ->
      query.getAll(callback)
      
    test.throws(f, Error)
    
    test.done()
    