
root = this

jsType = do ->  # from http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
  classToType = {}
  for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
    classToType["[object " + name + "]"] = name.toLowerCase()

  (obj) ->
    strType = Object::toString.call(obj)
    classToType[strType] or "object"

class RallyQuery
  ###
  This is hack to get around the fact that I didn't have App SDK 2.0 access when I started.
  I continue to use it for prototypes until I can ramp up on SDK 2.0.
  ###

  constructor: (config) ->
    @debug = false
    
    if process? and not window?  # assume running in Node.js
      XMLHttpRequest = require('xmlhttprequest').XMLHttpRequest
    else if root.XMLHttpRequest?
      XMLHttpRequest = root.XMLHttpRequest
    
    @XHRClass = XMLHttpRequest

    @_xhr = null  # the instance of XHR
    
    @_query = ''
    @_fetch = true
    @_order = null
    @_startIndex = 0
    @_pageSize = 200  # Start with a really large number because it gets set to whatever comes back on the first page
    @_callback = null
    
    @headers = {}
    @headers['X-RallyIntegrationLibrary'] = 'rally_analytics-0.1.0'  # !TODO: Automatically modify version to match package.json
    if navigator?
      platform = navigator.appName + ' ' + navigator.appVersion
      userAgent = navigator.userAgent 
      os = navigator.platform
    else if process?
      platform = 'Node.js (or some other non-browser) ' + process.version
      userAgent = 'Rally analytics toolkit on Node.js (or some other non-browser)' 
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
          
    @username = config.username  # !TODO: Before creating this AnalyticsQuery object, we need to follow pattern of RallySettings in pyral: https://github.com/Rallydev/pyral/blob/master/pyral/config.py
    @password = config.password
    
    @protocol = "https"
    @server = "rally1.rallydev.com/slm"
    @service = "webservice"
    @version = "1.31"  # !TODO: Set automatically
    @endpoint = "preferences.js"
    
    @_firstPage = true

    @lastResponseText = ''
    @lastResponse = {}
    @lastMeta = {}
    @allResults = []
    @allMeta = []
#     @allErrors = []  # !TODO: Populate allErrors and allWarnings
#     @allWarnings = []
    
  resetQuery: () ->
    @_query = null
    
  query: (@_query) ->
    return this  # to enable chaining
    
  order: (@_order) ->
    return this
    
  fetch: (@_fetch) ->
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

  getBaseURL: () ->
    return @protocol + '://' + [
      @server,
      @service,
      @version,
      @endpoint
    ].join('/')
    
  getQueryString: () ->
    if @_query?
      queryArray = []
      queryArray.push('query=' + @_query)
      if @_order?
        queryArray.push('order=' + @_order)
      if @_fetch?
        queryArray.push('fetch=' + @_fetch)
      queryArray.push('start=' + @_startIndex)
      queryArray.push('pagesize=' + @_pageSize)
      return queryArray.join('&')
    else
      throw new Error('find clause not set')
    
  getURL: () ->
    return @getBaseURL() + '?' + @getQueryString()
    
#   getPage:(callback) ->
#     callback.call(this)
#     return this

  getAll: (@_callback) ->
    unless @_query?
      throw new Error('Must set query clause before calling getAll')
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
      if @debug
        console.log('\nlastResponse\n' + @lastResponseText)
      @lastResponse = JSON.parse(@lastResponseText).QueryResult
      
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
          @_pageSize = @lastResponse.PageSize
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
    

root.RallyQuery = RallyQuery

