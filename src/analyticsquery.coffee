# !TODO: Add support for progress updates once each page
# !TODO: Add a lot more debug support. Include round trip time.
# !TODO: Deal with errors in the form of...
#   {
#     _rallyAPIMajor: "1"
#     _rallyAPIMinor: "27"
#     -Errors: [
#       "Server Error: Unauthorized for projects: 160265122,1566252877,192438691,57190214,79261273,416494543,132548747,285445783,42618248"
#     ]
#     Warnings: [ ]
#   }

root = this

jsType = do ->  # from http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
  classToType = {}
  for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
    classToType["[object " + name + "]"] = name.toLowerCase()

  (obj) ->
    strType = Object::toString.call(obj)
    classToType[strType] or "object"

class AnalyticsQuery
  ###
  This is the base class for all analytics query classes. For the most part, you are better off using
  one of the sub-classes but if you want more direct access, you can use this class as follows.
  
  ## Usage ##
  
  First, you need to "require" the desired analytics query class(es). In these examples, we're going to require a mock
  for the XMLHttpResponse Object but you will simply pass in the browser's XMHttpRequest Object (or 
  the equivalent from node-XMLHttpRequest if running on node.js)
  
      {XHRMock} = require('../../mock/XHRMock')
      rally_analytics = require('../')      
  
  Then, you need to set the config Object.
  
      config =
        'X-RallyIntegrationName': 'My Chart'
        'X-RallyIntegrationVendor': 'My Company'
        'X-RallyIntegrationVersion': '0.1.0'
        username: null  # if running in browser, will prompt
        password: null  # if running in Node.js will look for RALLY_USER/RALLY_PASSWORD environment variables
        workspaceOID: 12345
        additionalHeaders: [ 
          someHeader: 'Some Value'
        ]
  Which you can then use when instantiating a query.
  
      query = new rally_analytics.AnalyticsQuery(config)
      query.XHRClass = XHRMock  # Not required to hit actual Rally Analytics API

  Then you must set the query. `find` is required but you can also specify sort, fields, etc. Notice how you can chain these calls.

      query.find({Project: 1234, Tag: 'Expedited', _At: '2012-01-01'}).sort({_ValidFrom:1}).fields(['ScheduleState'])
    
  Of course you need to have a callback.
  
      callback = () ->
        console.log(this.allResults.length)  # will spit back 5 from our XHRMock
      # 5

  Finally, call getAll()

      query.getAll(callback)
      
  ## Properties you can inspect or set ##
  
  * **username** default null
  * **password** default null
  * **protocol** default "https"
  * **server** default "rally1.rallydev.com"
  * **service** default "analytics"
  * **version** defaults to latest current version
  * **endpoint** defaults to "artifact/snapshot/query.js"
  * **XHRClass** defaults to the local context XMLHttpResquest. Set to mock for testing.
  
  ## Properties you should only inspect ##
  
  Note, the context for the callback you provide to the `getAll()` method is set to the AnalyticsQuery instance
  so you can inspect these properties by simply prepending them with `this.` from inside of your callback.
  
  * **ETLDate** the ETLDate of the response in the first page
  * **lastResponseText** the string containing the most recent response/page
  * **lastResponse** the parsed JSON Object of the most recent response/page
  * **lastMeta** the meta data included at the top of the most recent response/page
  * **allResults** the Results from all pages concatenated together
  * **allMeta** the meta data from all pages concatentated together
  * **allErrors** NOT YET IMPLEMENTED
  * **allWarnings** NOT YET IMPLEMENTED
    
  ###
  constructor: (config) ->
    @_debug = false
    
    if process? and not window?  # assume running in Node.js
      XMLHttpRequest = require('xmlhttprequest').XMLHttpRequest
    else if root.XMLHttpRequest?
      XMLHttpRequest = root.XMLHttpRequest
    
    @XHRClass = XMLHttpRequest

    @_xhr = null  # the instance of XHR
    
    @_find = null
    @_fields = []
    @_sort = {_ValidFrom: 1}
    @_startIndex = 0
    @_pageSize = 100000  # Start with a really large number because it gets set to whatever comes back on the first page
    @_callback = null
    
    @headers = {}
    @headers['X-RallyIntegrationLibrary'] = 'rally_analytics-0.1.0'  # !TODO: Automatically modify version to match package.json
    if navigator?
      platform = navigator.appName + ' ' + navigator.appVersion
      os = navigator.platform
    else if process?
      platform = 'Node.js (or some other non-browser) ' + process.version
      os = process.platform
    @headers['X-RallyIntegrationPlatform'] = platform
    @headers['X-RallyIntegrationOS'] = os
    for key, value of config.additionalHeaders
      @headers[key] = value
      
    addRequiredHeader = (headers, key) ->
      if config[key]?
        headers[key] = config[key]
      else
        throw new Error("Must include config[#{key}] header when instantiating this rally_analytics.AnalyticsQuery object")
    addRequiredHeader(@headers, 'X-RallyIntegrationName')
    addRequiredHeader(@headers, 'X-RallyIntegrationVendor')
    addRequiredHeader(@headers, 'X-RallyIntegrationVersion')
 
      
    if config.workspaceOID?
      @workspaceOID = config.workspaceOID
    else if process?.env?.RALLY_WORKSPACE
      @workspaceOID = process.env.RALLY_WORKSPACE
    else
      throw new Error('Must provide a config.workspaceOID or set environment variable RALLY_WORKSPACE')
    
    if config.username?
      @username = config.username  # !TODO: Before creating this AnalyticsQuery object, we need to follow pattern of RallySettings in pyral: https://github.com/Rallydev/pyral/blob/master/pyral/config.py
    else if process?.env?.RALLY_USER
      @username = process.env.RALLY_USER
    else
      @username = undefined
    
    if config.password?
      @password = config.password
    else if process?.env?.RALLY_PASSWORD
      @password = process.env.RALLY_PASSWORD
    else
      @password = undefined
    
    @protocol = "https"
    @server = "rally1.rallydev.com"
    @service = "analytics"
    @version = "v2.0"  # !TODO: Set automatically
    @endpoint = "artifact/snapshot/query.js"
    
    @_firstPage = true
    @ETLDate = null
    @lastResponseText = ''
    @lastResponse = {}
    @lastMeta = {}
    @allResults = []
    @allMeta = []
#     @allErrors = []  # !TODO: Populate allErrors and allWarnings
#     @allWarnings = []
    
  resetFind: () ->
    @_find = null
    
  find: (@_find) ->
    return this  # to enable chaining
    
  sort: (@_sort) ->
    return this
    
  fields: (additionalFields) ->  # !TODO: Confirm that additionalFields is an array
    @_fields = @_fields.concat(additionalFields)
    return this

  hydrate: (@_hydrate) ->
    # !TODO: Confirm @_hydrate is an Array or true
    return this

  start: (@_startIndex) ->
    return this

  startIndex: (@_startIndex) ->
    return this

  pagesize: (@_pageSize) ->
    return this

  pageSize: (@_pageSize) ->
    return this
    
  auth: (@username, @password) ->
    return this
    
  debug: () ->
    @_debug = true

  getBaseURL: () ->
    return @protocol + '://' + [
      @server,
      @service,
      @version,
      'service/rally/workspace',
      @workspaceOID,
      @endpoint
    ].join('/')
    
  getQueryString: () ->
    findString = JSON.stringify(@_find)
    if @_find? and findString.length > 2
      queryArray = []
      queryArray.push('find=' + findString)
      if @_sort?
        queryArray.push('sort=' + JSON.stringify(@_sort))
      if @_fields?
        if @_fields[0] == true
          queryArray.push('fields=true')
        else if @_fields.length > 0
          queryArray.push('fields=' + JSON.stringify(@_fields))
      if @_hydrate?
        queryArray.push('hydrate=' + JSON.stringify(@_hydrate))  # !TODO: Test that this works for true
      queryArray.push('start=' + @_startIndex)
      queryArray.push('pagesize=' + @_pageSize)
      return queryArray.join('&')
    else
      throw new Error('find clause not set')
    
  getURL: () ->
    url = @getBaseURL() + '?' + @getQueryString()
    if @_debug
      console.log('\nfind: ', @_find)
      console.log('\nurl: ', url)
    return encodeURI(url)  # !TODO: May need to look into altnerative (maybe encodeURIComponent?) because won't encode '+', '=', and '&' in values correctly
    
#   getPage:(callback) ->
#     callback.call(this)
#     return this

  getAll: (@_callback) ->
    unless @_find?
      throw new Error('Must set find clause before calling getAll')
    unless @XHRClass?
      throw new Error('Must set XHRClass')
    @_xhr = new @XHRClass()
    @_xhr.onreadystatechange = @_gotResponse
    @_xhr.open('GET', @getURL(), true, @username, @password)
    for key, value of @headers
      @_xhr.setRequestHeader(key, value)
    @_xhr.send()
    return this
    
  _gotResponse: () =>
    # !TODO: Implement code to deal with errors at the XHR level as well as non-200 response codes
    if @_debug
      console.log('readyState: ', @_xhr.readyState)
    if @_xhr.readyState == 4
      _return = () =>
          @_firstPage = true 
          @_startIndex = 0
          @_callback.call(this)
                
      @lastResponseText = @_xhr.responseText
      if @_debug
        console.log('headers: ' + @_xhr.getAllResponseHeaders())
        console.log('status: ' + @_xhr.status)
        console.log('lastResponseText: ' + @lastResponseText)
        console.log('lastResponseJSON: ' + JSON.stringify(JSON.parse(@lastResponseText), undefined, 2))
      @lastResponse = JSON.parse(@lastResponseText)
      
      # if error
      if @lastResponse.Errors.length > 0
        # !TODO: Maybe throw away partially complete allResults?
        console.log('Errors\n' + JSON.stringify(@lastResponse.Errors))
        _return()
      else
        if @_firstPage
          @_firstPage = false
          @allResults = []
          @allMeta = []
  #         @allErrors = []
  #         @allWarnings = []
          # add ETLDate clause so subsequent pages are from the same moment in time
          @ETLDate = @lastResponse.ETLDate
          @_pageSize = @lastResponse.PageSize
          newFind = {'$and':[@_find, {'_ValidFrom': {'$lte': @ETLDate}}]}
          @_find = newFind
        else
          # !TODO: Check that TotalResultCount hasn't changed and error if it has
        
        # populate @allResults
        for o in @lastResponse.Results
          @allResults.push(o)
          
        # populate @allMeta
        @lastMeta = {}  
        for key, value of @lastResponse
          unless key == 'Results'
            @lastMeta[key] = value
        @allMeta.push(@lastMeta)
        
        # if last page, return else call again
        if @lastResponse.Results.length + @lastResponse.StartIndex >= @lastResponse.TotalResultCount
          _return()
        else
          @_startIndex += @_pageSize
          @_xhr = new @XHRClass()
          @_xhr.onreadystatechange = @_gotResponse
          @_xhr.open('GET', @getURL(), true, @username, @password)
          for key, value of @headers
            @_xhr.setRequestHeader(key, value)
          @_xhr.send()
    
    
class GuidedAnalyticsQuery extends AnalyticsQuery
  ###
  To help you write performant queries against the non-traditional data model of Rally's Analytics engine, we provide a guided mode 
  for composing queries. Like the raw AnalyticsQuery, you start by creating a GuidedAnalyticsQuery Object. 
  
      query = new rally_analytics.GuidedAnalyticsQuery(config)
      query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API
  
  **Scope**
  
  Then you must specify at least one highly selective criteria using the scope method:
  
      query.scope('Project', 1234) # or [1234, 5678]
      query.scope('_ProjectHierarchy', 1234) # or [1234, 5678], also accepts 'ProjectHierarchy'
      query.scope('Iteration', 1234) # or [1234, 5678]
      query.scope('Release', 1234) # or [1234, 5678]
      query.scope('_ItemHierarchy', 1234) # also accepts 'ItemHierarchy'
      query.scope('Tags', 'Top 10') # or ['Top 10', 'Expedite'], also accepts Tag
      
  The 'ProjectHierarchy' scope is not necessarily highly selective. So you should make sure that you
  either have some other criteria or that you don't have too many Projects in scope beneith the specified Project(s).
  
  Alternatively, you can specify your scope in one big object:
  
      query.scope({
        _ProjectHierarchy: 1234,
        Iteration: [1234, 5678], 
      })
      
  **Type**
  
  You can optionally limit your query to one or more work item types. Defaults to all types.
  
      query.type('Defect') # alteratively ['Defect', 'HierarchicalRequirement']
      
  Note, a change is expected to be made such that the Analytics API will require ObjectIDs of the types.
  When that happens, we may update this REST toolkit to hide that from you but you'll need to update
  to the latest version.
  
  **Leaf Nodes Only**  
  
  You can also specify that you only want leaf nodes to be returned by the query.
  
      query.leafOnly()
      
  It will expand to a clause like: 
      
      {
        '$or': [
          {_TypeHierarchy: "HierarchicalRequirement", Children: null},
          {_TypeHierarchy:"PortfolioItem", Children: null, UserStories: null}
        ]
      }

  **Additional Criteria**
  
  You can also specify additional critaria. This can be useful for defining "sub-classes" of work items.
      
      query.additionalCriteria({Environment: 'Production'})
      
  **Chaining**
  
  Chaining is supported, so you could say:
  
      query = new rally_analytics.GuidedAnalyticsQuery(config)
      query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API
      query.scope('_ProjectHierarchy', 1234)
           .type('HierarchicalRequirement')
           .leafOnly()
           .additionalCriteria({Blocked: true})
           
      query.find()
      console.log(JSON.stringify(query._find, undefined, 2))
      # {
      #   "$and": [
      #     {
      #       "_ProjectHierarchy": 1234
      #     },
      #     {
      #       "_TypeHierarchy": "HierarchicalRequirement"
      #     },
      #     {
      #       "$or": [
      #         {
      #           "_TypeHierarchy": "HierarchicalRequirement",
      #           "Children": null
      #         },
      #         {
      #           "_TypeHierarchy": "PortfolioItem",
      #           "Children": null,
      #           "UserStories": null
      #         }
      #       ]
      #     },
      #     {
      #       "Blocked": true
      #     }
      #   ]
      # }

      
  ###
  constructor: (config) ->
    super(config)
    @_scope = {}
    @_type = null
    @_additionalCriteria = []
    
  generateFind: () ->
    compoundArray = []
    if JSON.stringify(@_scope).length > 2
      compoundArray.push(@_scope)
    else
      throw new Error('Must set scope first.')
    if @_type?
      compoundArray.push(@_type)
    for c in @_additionalCriteria
      compoundArray.push(c)
    if 0 < compoundArray.length < 2
      return compoundArray[0]
    else
      return {'$and':compoundArray}
    
  find: () ->
    if arguments.length > 0
      throw new Error('Do not call find() directly to set query. Use scope(), type(), and additionalCriteria()')
    super(@generateFind())
    return this
    
  resetScope: () ->
    @_scope = {}
    
  scope: (key, value) ->
    addToScope = (k, v) =>
      if k == 'ItemHierarchy'
        k = '_ItemHierarchy'
      if k == 'Tag'
        k = 'Tags'
      if k == 'ProjectHierarchy'
        k = '_ProjectHierarchy'
      okKeys = ['Project', '_ProjectHierarchy', 'Iteration', 'Release', 'Tags', '_ItemHierarchy']
      unless k in okKeys
        throw new Error("Key for scope() call must be one of #{okKeys}")
      if jsType(v) == 'array'
        @_scope[k] = {'$in': v}  # Note, even for _ItemHierarchy/_ProjectHierarchy this behaves as expected {_ItemHierarchy: {$in:[1, 2]}} will bring back the decendants of 1 and the decendants of 2.
      else
        @_scope[k] = v
      
    if jsType(key) == 'object'
      for k, v of key
        addToScope(k, v)
    else if arguments.length == 2
      addToScope(key, value)
    else
      throw new Error('Must provide an Object in first parameter or two parameters (key, value).')
    
    return this
      
  resetType: () ->
    @_type = null
  
  type: (type) ->
    @_type = {'_TypeHierarchy': type}
    return this

  resetAdditionalCriteria: () ->
    @_additionalCriteria = []
  
  additionalCriteria: (criteria) ->
    @_additionalCriteria.push(criteria)
    return this
    
  leafOnly: () ->
    @additionalCriteria({
      '$or': [
        {_TypeHierarchy: "HierarchicalRequirement", Children: null},
        {_TypeHierarchy:"PortfolioItem", Children: null, UserStories: null}
      ]
    })
    return this
    
  getAll: (callback) ->
    @find()
    super(callback)

class AtAnalyticsQuery extends GuidedAnalyticsQuery
  ###
  This pattern will tell you what a set of Artfacts looked like at particular moments in time
    
      query = new rally_analytics.AtAnalyticsQuery(config, '2012-01-01T12:34:56.789Z')
      query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API
      
  It will expand to a query like this:
      
      query.scope('_ProjectHierarchy', 1234)
      query.find()
      console.log(JSON.stringify(query._find, undefined, 2))
      # {
      #   "$and": [
      #     {
      #       "_ProjectHierarchy": 1234
      #     },
      #     {
      #       "_At": "2012-01-01T12:34:56.789Z"
      #     }
      #   ]
      # }

  ###
  constructor: (config, zuluDateString) ->
    super(config)
    unless zuluDateString?
      throw new Error('Must provide a zuluDateString when instantiating an AtAnalyticsQuery.')
    @_additionalCriteria.push({_At: zuluDateString})

class AtArrayAnalyticsQuery extends GuidedAnalyticsQuery
  ###
  This pattern is not implemented at this time but the intention is for it to tell you what a 
  set of Artfacts looked like at particular moments in time. In the mean time, use the "Between"
  pattern defined above combined with the Lumenize `snapshotArray_To_AtArray` function. 
  Eventually, this will be the ideal pattern to use for Burn charts, CFD charts, and most time-series charts
  It's the same as the 'At' pattern except that the second parameter can be a list of timestamps.
  
  `query = new rally_analytics.AtArrayAnalyticsQuery(config, ['2012-01-01T12:34:56.789Z', '2012-01-02T12:34:56.789Z', ...])`
      
  Altneratively, we may make it possible to submit a ChartTimeIterator spec.
  
  The way to implement this in the short term is to use the Between pattern and wrap in the Lumenize 
  `snapshotArray_To_AtArray` transformation.
     
  Note: it's tempting to try to make this more efficient by just looking for snapshots where the fields of interest change. 
  However, that approach would not pick up on the deletions/restores nor the changing of the work item so it no longer meets 
  the other criteria.
    
  Note: when/if there is server-side support for finding the results at these points in time, this query pattern will be updated
  to take advantage of it.

  ###
  constructor: (config, arrayOfZuluDates) ->
    super(config)
    throw new Error('AtArrayAnalyticsQuery is not yet implemented')

class BetweenAnalyticsQuery extends GuidedAnalyticsQuery
  ###
  This pattern will return all of the snapshots active in a particular timebox. The results are in the form expected by the 
  Lumenize function `snapshotArray_To_AtArray`, which will tell you what each work item looked like at a provided list of
  datetimes. This is the current recommended approach for most time-series charts. The burncalculator and cfdcalculator
  use this approach. Note: the 'AtArray' approach will supercede this for time-series charts at some point in the future.
    
      query = new rally_analytics.BetweenAnalyticsQuery(config, '2012-01-01T12:34:56.789Z', '2012-01-10T12:34:56.789Z')
      query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API

  It will expand to a query like this:
  
      query.scope('_ProjectHierarchy', 1234)
      query.find()
      console.log(JSON.stringify(query._find, undefined, 2))
      # {
      #   "$and": [
      #     {
      #       "_ProjectHierarchy": 1234
      #     },
      #     {
      #       "_ValidFrom": {
      #         "$lt": "2012-01-10T12:34:56.789Z"
      #       }, 
      #       "_ValidTo": {
      #         "$gt": "2012-01-01T12:34:56.789Z"
      #       }
      #     }
      #   ]
      # }
  ###
  constructor: (config, startOn, endBefore) ->
    super(config)
    unless startOn? and endBefore?
      throw new Error('Must provide two zulu data strings when instantiating a BetweenAnalyticsQuery.')
    criteria = {"_ValidFrom": {$lt: endBefore}, "_ValidTo": {$gt: startOn}}
    @_additionalCriteria.push(criteria)
    @sort({_ValidFrom:1})
 
class TimeInStateAnalyticsQuery extends GuidedAnalyticsQuery
  ###
  This pattern will only return snapshots where the specified clause is true.
  This is useful for Cycle Time calculations as well as calculating Flow Efficiency or Blocked Time.
  
      query = new rally_analytics.TimeInStateAnalyticsQuery(config, {KanbanState: {$gte: 'In Dev', $lt: 'Accepted'}})
      query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API
  ###
  constructor: (config, predicate) ->
    super(config)
    unless predicate?
      throw new Error('Must provide a predicate when instantiating a TimeInStateAnalyticsQuery.')
    @_additionalCriteria.push(predicate)
    @fields(['ObjectID', '_ValidFrom', '_ValidTo'])
    @sort({_ValidFrom:1})

class TransitionsAnalyticsQuery extends GuidedAnalyticsQuery
  ###
  This pattern will return the snapshots where the _PreviousValue matches the first query clause parameter and the "current"
  value matches the second query clause parameter. In other words, it finds particular transitions. It is useful for 
  Throughput/Velocity calculations. 
  
  !TODO: Indent below to make sure it works and add example
  query = new TransitionsAnalyticsQuery(config,
    {ScheduleState: {$lt: 'Accepted'}}, 
    {ScheduleState: {$gte: 'Accepted'}}
  )
  query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API

  
  The first predicate is actually converted such that any non-operator key is prepended with "_PreviousValues.". In the example
  above, "{ScheduleState: {$lt: 'Accepted'}}" becomes "{'_PreviousValues.ScheduleState': {$lt: 'Accepted'}}". So this will return
  the snapshots that made this particular transition from before state to after state.
  
  Note, you should also run the query swapping the two predicates and subtract the two calculations before reporting a Thoughput or 
  Velocity result. Without doing so, any story that crosses the boudary multiple times would get double, triple, etc. counted.
  
  In a future version, you may be able to specify aggregation functions ($count, $sum, $push, etc.) on a particular field when 
  making this query, because when you use this pattern, you are usually interested in the sum or count and not the actual snapshots.
  In the mean time, if you are only interested in the count, simply specify pagesize of 1 and inspect the TotalResultCount in the top
  section of the response.
  
  There is a good reason that Throughput and Velocity are defined with two predicates rather than just specifying the line to the left
  of "Accepted". Let's say, work is not really "Accepted" until the Ready flag is checked. You could write that query like so:
  
  !TODO: Indent below to make sure it works and add example
  query = new rally_analytics.TransitionsAnalyticsQuery(config,
    {$or: [{KanbanState: {$lt: 'Accepted'}}, {KanbanState: 'Accepted', Ready: false}]}, 
    {$or: [{KanbanState: 'Accepted', Ready: true}, {KanbanState: {$gt: 'Accepted'}}]}
  )
  query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API
      
  It will expand to a query like this:

  !TODO: Indent below to make sure it works and add example
  query.scope('_ProjectHierarchy', 1234)
  query.find()
  console.log(JSON.stringify(query._find, undefined, 2))
  # 
  ###
  constructor: (config, arrayOfZuluDates) ->
    super(config)
    throw new Error('Not yet implemented')

root.AnalyticsQuery = AnalyticsQuery
root.GuidedAnalyticsQuery = GuidedAnalyticsQuery
root.AtAnalyticsQuery = AtAnalyticsQuery
root.AtArrayAnalyticsQuery = AtArrayAnalyticsQuery
root.BetweenAnalyticsQuery = BetweenAnalyticsQuery
root.TimeInStateAnalyticsQuery = TimeInStateAnalyticsQuery
root.TransitionsAnalyticsQuery = TransitionsAnalyticsQuery