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
        	"PageSize": 2, 
        	"ETLDate": "2012-03-16T21:01:17.802Z", 
        	"Results": [
        		{"id": 1},
        		{"id": 2}
        	]
        }''',
     '''{
        	"_rallyAPIMajor": "1", 
        	"_rallyAPIMinor": "27", 
        	"Errors": [], 
        	"Warnings": [], 
        	"TotalResultCount": 5, 
        	"StartIndex": 2, 
        	"PageSize": 2, 
        	"ETLDate": "2012-03-16T21:01:17.802Z", 
        	"Results": [
        		{"id": 3},
        		{"id": 4}
        	]
        }''',
     '''{
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