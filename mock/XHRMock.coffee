root = this

class XHRMock

  @sendCount = 0
  
  @responses = [
     '''{
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
        }''',
     '''{
        	"_rallyAPIMajor": "1", 
        	"_rallyAPIMinor": "27", 
        	"Errors": [], 
        	"Warnings": [], 
        	"TotalResultCount": 5, 
        	"StartIndex": 2, 
        	"PageSize": 3,
        	"ETLDate": "2012-03-16T21:01:17.802Z", 
        	"Results": [
        		{"id": 3, "_ValidFrom": "2012-03-16T21:01:17.002Z"},
        		{"id": 4, "_ValidFrom": "2012-03-16T21:01:17.003Z"},
            {"id": 5, "_ValidFrom": "2012-03-16T21:01:17.004Z"}
        	]
        }'''
  ]

  constructor: (@debug = false) ->
    @onreadystatechange = null
    @DONE = 4
    @headers = {}
    @readyState = @DONE
    @status = 200
    @responseText = ''
        
  open: (@method, @url) ->
    if @debug
      console.log("method: #{@method}, url: #{@url}")
    
  send: (@message) ->
    @responseText = XHRMock.responses[XHRMock.sendCount]
    XHRMock.sendCount++
    @onreadystatechange.call(this)
    
  setRequestHeader: (key, value) ->
    @headers[key] = value
    
root.XHRMock = XHRMock