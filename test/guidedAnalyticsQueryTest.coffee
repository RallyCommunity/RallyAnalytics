{XHRMock} = require('../mock/XHRMock')
rally_analytics = require('../')
{GuidedAnalyticsQuery} = rally_analytics

basicConfig =
  'X-RallyIntegrationName'     : 'testName'
  'X-RallyIntegrationVendor'   : 'testRally'
  'X-RallyIntegrationVersion'  : '0.1.0'
  workspaceOID: 12345

exports.guidedAnalyticsQueryTest =

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
    
    query = new GuidedAnalyticsQuery(config)
    query.XHRClass = XHRMock
    test.equal(query.XHRClass, XHRMock)
    test.ok(query.headers['myHeader']?)
    test.equal(query.headers['X-RallyIntegrationName'], 'testName')
    test.equal(query.headers['X-RallyIntegrationVendor'], 'testRally')
    test.equal(query.headers['X-RallyIntegrationVersion'], '0.1.0')
    test.equal(query.username, 'anyone@anywhere.com')
    test.equal(query.password, 'xxxxx')
    
    test.done()
    
  testThrowsCallingFind: (test) ->
    query = new GuidedAnalyticsQuery(basicConfig)
    
    f = () ->
      query.find({something:'hello'})
      
    test.throws(f, Error)
    
    test.done()
    
  testThrowsWhenFindNotSet: (test) ->
    query = new GuidedAnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock
    
    f2 = () ->
      query.getAll(() -> console.log('never get here'))
      
    test.throws(f2, Error)
    
    test.done()
    
  testScope: (test) ->
    query = new GuidedAnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock
    
    query.resetScope()
    test.deepEqual(query._scope, {})
    
    query.scope({Project: 12345})
    query.find()
    test.deepEqual(query._find, {Project:12345})

    query.resetScope()
    query.scope('Tag', 'Support Top 10')
    query.find()
    test.deepEqual(query._find, {Tags:'Support Top 10'})

    query.resetScope()
    query.scope('Tags', ['Support Top 10', 'Expedite'])
    query.find()
    test.deepEqual(query._find, {Tags: {'$in': ['Support Top 10', 'Expedite']}})
    
    test.done()

  testType: (test) ->
    query = new GuidedAnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock
    
    f = () ->
      query.type('Artifact')
      query.find()
    
    test.throws(f, Error)
    
    query.scope({Iteration:[12345, 67890]})
    query.type('Artifact')
    query.find()
    test.deepEqual(query._find, {'$and': [{Iteration: {'$in': [12345, 67890]}}, {_TypeHierarchy: 'Artifact'}]}) # !TODO: Test case for Type as an array
    
    test.done()

  testLeafOnly: (test) ->
    query = new GuidedAnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock

    query.scope('Project', 12345)
    query.leafOnly()      
    query.find()
    test.deepEqual(query._find, {
      "$and": [
        {
          "Project": 12345
        },
        {
          "$or": [
            {
              "_TypeHierarchy": "HierarchicalRequirement",
              "Children": null
            },
            {
              "_TypeHierarchy": "PortfolioItem",
              "Children": null,
              "UserStories": null
            }
          ]
        }
      ]
    })
    
    test.done()
    
  testAddditionalCriteria: (test) ->
    query = new GuidedAnalyticsQuery(basicConfig)
    query.XHRClass = XHRMock

    f = () ->
      query.resetAdditionalCriteria()
      query.additionalCriteria({'additional': 'criteria'})
      query.find()
    
    test.throws(f, Error)

    query.scope({_ItemHierarchy:[12345, 67890]})
    query.resetAdditionalCriteria()
    query.additionalCriteria({'additional':'criteria'})
    query.find()  # Normal user wouldn't call this. We're calling it to simulate a getAll
    test.deepEqual(query._find, {'$and': [{_ItemHierarchy: {'$in': [12345, 67890]}}, {'additional': 'criteria'}]})

    query.scope({ItemHierarchy:12345})
    query.resetAdditionalCriteria()
    query.additionalCriteria({'additional':'criteria'})
    query.type('Artifact')
    query.find()
    test.deepEqual(query._find, {'$and': [{_ItemHierarchy: 12345}, {_TypeHierarchy: 'Artifact'}, {'additional': 'criteria'}]})
    
    test.done()
    
  testGetAllHappy: (test) ->
    test.expect(3)
    query = new GuidedAnalyticsQuery(basicConfig)
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
      
    query.scope('Project', 1234)
    query.getAll(callback)

    