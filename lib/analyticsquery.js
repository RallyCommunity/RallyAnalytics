(function() {
  var AnalyticsQuery, AtAnalyticsQuery, AtArrayAnalyticsQuery, BetweenAnalyticsQuery, GuidedAnalyticsQuery, TimeInStateAnalyticsQuery, TransitionsAnalyticsQuery, jsType, root,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; },
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  root = this;

  jsType = (function() {
    var classToType, name, _i, _len, _ref;
    classToType = {};
    _ref = "Boolean Number String Function Array Date RegExp Undefined Null".split(" ");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      name = _ref[_i];
      classToType["[object " + name + "]"] = name.toLowerCase();
    }
    return function(obj) {
      var strType;
      strType = Object.prototype.toString.call(obj);
      return classToType[strType] || "object";
    };
  })();

  AnalyticsQuery = (function() {
    /*
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
    */
    function AnalyticsQuery(config) {
      this._gotResponse = __bind(this._gotResponse, this);
      var XMLHttpRequest, addRequiredHeader, key, os, platform, value, _ref, _ref2, _ref3, _ref4;
      this._debug = false;
      if ((typeof process !== "undefined" && process !== null) && !(typeof window !== "undefined" && window !== null)) {
        XMLHttpRequest = require('node-XMLHttpRequest').XMLHttpRequest;
      } else if (root.XMLHttpRequest != null) {
        XMLHttpRequest = root.XMLHttpRequest;
      }
      this.XHRClass = XMLHttpRequest;
      this._xhr = null;
      this._find = null;
      this._fields = null;
      this._sort = {
        _ValidFrom: 1
      };
      this._startIndex = 0;
      this._pageSize = 100000;
      this._callback = null;
      this.headers = {};
      this.headers['X-RallyIntegrationLibrary'] = 'rally_analytics-0.1.0';
      if (typeof navigator !== "undefined" && navigator !== null) {
        platform = navigator.appName + ' ' + navigator.appVersion;
        os = navigator.platform;
      } else if (typeof process !== "undefined" && process !== null) {
        platform = 'Node.js (or some other non-browser) ' + process.version;
        os = process.platform;
      }
      this.headers['X-RallyIntegrationPlatform'] = platform;
      this.headers['X-RallyIntegrationOS'] = os;
      _ref = config.additionalHeaders;
      for (key in _ref) {
        value = _ref[key];
        this.headers[key] = value;
      }
      addRequiredHeader = function(headers, key) {
        if (config[key] != null) {
          return headers[key] = config[key];
        } else {
          throw new Error("Must include config[" + key + "] header when instantiating this rally_analytics.AnalyticsQuery object");
        }
      };
      addRequiredHeader(this.headers, 'X-RallyIntegrationName');
      addRequiredHeader(this.headers, 'X-RallyIntegrationVendor');
      addRequiredHeader(this.headers, 'X-RallyIntegrationVersion');
      if (config.workspaceOID != null) {
        this.workspaceOID = config.workspaceOID;
      } else if (typeof process !== "undefined" && process !== null ? (_ref2 = process.env) != null ? _ref2.RALLY_WORKSPACE : void 0 : void 0) {
        this.workspaceOID = process.env.RALLY_WORKSPACE;
      } else {
        throw new Error('Must provide a config.workspaceOID or set environment variable RALLY_WORKSPACE');
      }
      if (config.username != null) {
        this.username = config.username;
      } else if (typeof process !== "undefined" && process !== null ? (_ref3 = process.env) != null ? _ref3.RALLY_USER : void 0 : void 0) {
        this.username = process.env.RALLY_USER;
      } else {
        this.username = void 0;
      }
      if (config.password != null) {
        this.password = config.password;
      } else if (typeof process !== "undefined" && process !== null ? (_ref4 = process.env) != null ? _ref4.RALLY_PASSWORD : void 0 : void 0) {
        this.password = process.env.RALLY_PASSWORD;
      } else {
        this.password = void 0;
      }
      this.protocol = "https";
      this.server = "rally1.rallydev.com";
      this.service = "analytics";
      this.version = "1.27";
      this.endpoint = "artifact/snapshot/query.js";
      this._firstPage = true;
      this.ETLDate = null;
      this.lastResponseText = '';
      this.lastResponse = {};
      this.lastMeta = {};
      this.allResults = [];
      this.allMeta = [];
    }

    AnalyticsQuery.prototype.resetFind = function() {
      return this._find = null;
    };

    AnalyticsQuery.prototype.find = function(_find) {
      this._find = _find;
      return this;
    };

    AnalyticsQuery.prototype.sort = function(_sort) {
      this._sort = _sort;
      return this;
    };

    AnalyticsQuery.prototype.fields = function(_fields) {
      this._fields = _fields;
      return this;
    };

    AnalyticsQuery.prototype.start = function(_startIndex) {
      this._startIndex = _startIndex;
      return this;
    };

    AnalyticsQuery.prototype.startIndex = function(_startIndex) {
      this._startIndex = _startIndex;
      return this;
    };

    AnalyticsQuery.prototype.pagesize = function(_pageSize) {
      this._pageSize = _pageSize;
      return this;
    };

    AnalyticsQuery.prototype.pageSize = function(_pageSize) {
      this._pageSize = _pageSize;
      return this;
    };

    AnalyticsQuery.prototype.auth = function(username, password) {
      this.username = username;
      this.password = password;
      return this;
    };

    AnalyticsQuery.prototype.debug = function() {
      return this._debug = true;
    };

    AnalyticsQuery.prototype.getBaseURL = function() {
      return this.protocol + '://' + [this.server, this.service, this.version, this.workspaceOID, this.endpoint].join('/');
    };

    AnalyticsQuery.prototype.getQueryString = function() {
      var findString, queryArray;
      findString = JSON.stringify(this._find);
      if ((this._find != null) && findString.length > 2) {
        queryArray = [];
        queryArray.push('find=' + findString);
        if (this._sort != null) {
          queryArray.push('sort=' + JSON.stringify(this._sort));
        }
        if (this._fields != null) {
          queryArray.push('fields=' + JSON.stringify(this._fields));
        }
        queryArray.push('start=' + this._startIndex);
        queryArray.push('pagesize=' + this._pageSize);
        return queryArray.join('&');
      } else {
        throw new Error('find clause not set');
      }
    };

    AnalyticsQuery.prototype.getURL = function() {
      var url;
      url = this.getBaseURL() + '?' + this.getQueryString();
      if (this._debug) {
        console.log('\nfind: ', this._find);
        console.log('\nurl: ', url);
      }
      return encodeURI(url);
    };

    AnalyticsQuery.prototype.getAll = function(_callback) {
      var key, value, _ref;
      this._callback = _callback;
      if (this._find == null) {
        throw new Error('Must set find clause before calling getAll');
      }
      if (this.XHRClass == null) throw new Error('Must set XHRClass');
      this._xhr = new this.XHRClass();
      this._xhr.onreadystatechange = this._gotResponse;
      this._xhr.open('GET', this.getURL(), true, this.username, this.password);
      _ref = this.headers;
      for (key in _ref) {
        value = _ref[key];
        this._xhr.setRequestHeader(key, value);
      }
      this._xhr.send();
      return this;
    };

    AnalyticsQuery.prototype._gotResponse = function() {
      var key, newFind, o, value, _i, _len, _ref, _ref2, _ref3, _return,
        _this = this;
      if (this._debug) console.log('readyState: ', this._xhr.readyState);
      if (this._xhr.readyState === 4) {
        _return = function() {
          _this._firstPage = true;
          _this._startIndex = 0;
          return _this._callback.call(_this);
        };
        this.lastResponseText = this._xhr.responseText;
        if (this._debug) {
          console.log('headers: ' + this._xhr.getAllResponseHeaders());
          console.log('status: ' + this._xhr.status);
          console.log('lastResponse: ' + this.lastResponseText);
        }
        this.lastResponse = JSON.parse(this.lastResponseText);
        if (this.lastResponse.Errors.length > 0) {
          console.log('Errors\n' + JSON.stringify(this.lastResponse.Errors));
          return _return();
        } else {
          if (this._firstPage) {
            this._firstPage = false;
            this.allResults = [];
            this.allMeta = [];
            this.ETLDate = this.lastResponse.ETLDate;
            this._pageSize = this.lastResponse.PageSize;
            newFind = {
              '$and': [
                this._find, {
                  '_ValidFrom': {
                    '$lte': this.ETLDate
                  }
                }
              ]
            };
            this._find = newFind;
          } else {

          }
          _ref = this.lastResponse.Results;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            o = _ref[_i];
            this.allResults.push(o);
          }
          this.lastMeta = {};
          _ref2 = this.lastResponse;
          for (key in _ref2) {
            value = _ref2[key];
            if (key !== 'Results') this.lastMeta[key] = value;
          }
          this.allMeta.push(this.lastMeta);
          if (this.lastResponse.Results.length + this.lastResponse.StartIndex >= this.lastResponse.TotalResultCount) {
            return _return();
          } else {
            this._startIndex += this._pageSize;
            this._xhr = new this.XHRClass();
            this._xhr.onreadystatechange = this._gotResponse;
            this._xhr.open('GET', this.getURL(), true, this.username, this.password);
            _ref3 = this.headers;
            for (key in _ref3) {
              value = _ref3[key];
              this._xhr.setRequestHeader(key, value);
            }
            return this._xhr.send();
          }
        }
      }
    };

    return AnalyticsQuery;

  })();

  GuidedAnalyticsQuery = (function(_super) {

    __extends(GuidedAnalyticsQuery, _super);

    /*
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
              {_Type: "HierarchicalRequirement", Children: null},
              {_Type:"PortfolioItem", Children: null, UserStories: null}
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
          #       "_Type": "HierarchicalRequirement"
          #     },
          #     {
          #       "$or": [
          #         {
          #           "_Type": "HierarchicalRequirement",
          #           "Children": null
          #         },
          #         {
          #           "_Type": "PortfolioItem",
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
    */

    function GuidedAnalyticsQuery(config) {
      GuidedAnalyticsQuery.__super__.constructor.call(this, config);
      this._scope = {};
      this._type = null;
      this._additionalCriteria = [];
    }

    GuidedAnalyticsQuery.prototype.generateFind = function() {
      var c, compoundArray, _i, _len, _ref, _ref2;
      compoundArray = [];
      if (JSON.stringify(this._scope).length > 2) {
        compoundArray.push(this._scope);
      } else {
        throw new Error('Must set scope first.');
      }
      if (this._type != null) compoundArray.push(this._type);
      _ref = this._additionalCriteria;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        compoundArray.push(c);
      }
      if ((0 < (_ref2 = compoundArray.length) && _ref2 < 2)) {
        return compoundArray[0];
      } else {
        return {
          '$and': compoundArray
        };
      }
    };

    GuidedAnalyticsQuery.prototype.find = function() {
      if (arguments.length > 0) {
        throw new Error('Do not call find() directly to set query. Use scope(), type(), and additionalCriteria()');
      }
      return GuidedAnalyticsQuery.__super__.find.call(this, this.generateFind());
    };

    GuidedAnalyticsQuery.prototype.resetScope = function() {
      return this._scope = {};
    };

    GuidedAnalyticsQuery.prototype.scope = function(key, value) {
      var addToScope, k, v,
        _this = this;
      addToScope = function(k, v) {
        var okKeys;
        if (k === 'ItemHierarchy') k = '_ItemHierarchy';
        if (k === 'Tag') k = 'Tags';
        if (k === 'ProjectHierarchy') k = '_ProjectHierarchy';
        okKeys = ['Project', '_ProjectHierarchy', 'Iteration', 'Release', 'Tags', '_ItemHierarchy'];
        if (__indexOf.call(okKeys, k) < 0) {
          throw new Error("Key for scope() call must be one of " + okKeys);
        }
        if (jsType(v) === 'array') {
          return _this._scope[k] = {
            '$in': v
          };
        } else {
          return _this._scope[k] = v;
        }
      };
      if (jsType(key) === 'object') {
        for (k in key) {
          v = key[k];
          addToScope(k, v);
        }
      } else if (arguments.length === 2) {
        addToScope(key, value);
      } else {
        throw new Error('Must provide an Object in first parameter or two parameters (key, value).');
      }
      return this;
    };

    GuidedAnalyticsQuery.prototype.resetType = function() {
      return this._type = null;
    };

    GuidedAnalyticsQuery.prototype.type = function(type) {
      this._type = {
        '_Type': type
      };
      return this;
    };

    GuidedAnalyticsQuery.prototype.resetAdditionalCriteria = function() {
      return this._additionalCriteria = [];
    };

    GuidedAnalyticsQuery.prototype.additionalCriteria = function(criteria) {
      this._additionalCriteria.push(criteria);
      return this;
    };

    GuidedAnalyticsQuery.prototype.leafOnly = function() {
      this.additionalCriteria({
        '$or': [
          {
            _Type: "HierarchicalRequirement",
            Children: null
          }, {
            _Type: "PortfolioItem",
            Children: null,
            UserStories: null
          }
        ]
      });
      return this;
    };

    GuidedAnalyticsQuery.prototype.getAll = function(callback) {
      this.find();
      return GuidedAnalyticsQuery.__super__.getAll.call(this, callback);
    };

    return GuidedAnalyticsQuery;

  })(AnalyticsQuery);

  AtAnalyticsQuery = (function(_super) {

    __extends(AtAnalyticsQuery, _super);

    /*
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
    */

    function AtAnalyticsQuery(config, zuluDateString) {
      AtAnalyticsQuery.__super__.constructor.call(this, config);
      if (zuluDateString == null) {
        throw new Error('Must provide a zuluDateString when instantiating an AtAnalyticsQuery.');
      }
      this._additionalCriteria.push({
        _At: zuluDateString
      });
    }

    return AtAnalyticsQuery;

  })(GuidedAnalyticsQuery);

  AtArrayAnalyticsQuery = (function(_super) {

    __extends(AtArrayAnalyticsQuery, _super);

    /*
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
    */

    function AtArrayAnalyticsQuery(config, arrayOfZuluDates) {
      AtArrayAnalyticsQuery.__super__.constructor.call(this, config);
      throw new Error('AtArrayAnalyticsQuery is not yet implemented');
    }

    return AtArrayAnalyticsQuery;

  })(GuidedAnalyticsQuery);

  BetweenAnalyticsQuery = (function(_super) {

    __extends(BetweenAnalyticsQuery, _super);

    /*
      This pattern will return all of the snapshots related to a particular timebox. The results are in the form expected by the 
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
          #       "$or": [
          #         {
          #           "_ValidFrom": {
          #             "$lte": "2012-01-01T12:34:56.789Z"
          #           },
          #           "_ValidTo": {
          #             "$gt": "2012-01-01T12:34:56.789Z"
          #           }
          #         },
          #         {
          #           "_ValidFrom": {
          #             "$gte": "2012-01-01T12:34:56.789Z",
          #             "$lt": "2012-01-10T12:34:56.789Z"
          #           }
          #         }
          #       ]
          #     }
          #   ]
          # }
    */

    function BetweenAnalyticsQuery(config, zuluDateString1, zuluDateString2) {
      var criteria;
      BetweenAnalyticsQuery.__super__.constructor.call(this, config);
      if (!((zuluDateString1 != null) && (zuluDateString2 != null))) {
        throw new Error('Must provide two zuluDateStrings when instantiating a BetweenAnalyticsQuery.');
      }
      criteria = {
        '$or': [
          {
            _ValidFrom: {
              '$lte': zuluDateString1
            },
            _ValidTo: {
              '$gt': zuluDateString1
            }
          }, {
            _ValidFrom: {
              '$gte': zuluDateString1,
              '$lt': zuluDateString2
            }
          }
        ]
      };
      this._additionalCriteria.push(criteria);
      this.sort({
        _ValidFrom: 1
      });
    }

    return BetweenAnalyticsQuery;

  })(GuidedAnalyticsQuery);

  TimeInStateAnalyticsQuery = (function(_super) {

    __extends(TimeInStateAnalyticsQuery, _super);

    /*
      This pattern will only return snapshots where the specified clause is true.
      This is useful for Cycle Time calculations as well as calculating Flow Efficiency or Blocked Time.
      
          query = new rally_analytics.TimeInStateAnalyticsQuery(config, {KanbanState: {$gte: 'In Dev', $lt: 'Accepted'}})
          query.XHRClass = XHRMock  # Not required to hit real Rally Analytics API
    */

    function TimeInStateAnalyticsQuery(config, predicate) {
      TimeInStateAnalyticsQuery.__super__.constructor.call(this, config);
      if (predicate == null) {
        throw new Error('Must provide a predicate when instantiating a TimeInStateAnalyticsQuery.');
      }
      this._additionalCriteria.push(predicate);
      this.fields(['ObjectID', '_ValidFrom', '_ValidTo']);
      this.sort({
        _ValidFrom: 1
      });
    }

    return TimeInStateAnalyticsQuery;

  })(GuidedAnalyticsQuery);

  TransitionsAnalyticsQuery = (function(_super) {

    __extends(TransitionsAnalyticsQuery, _super);

    /*
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
    */

    function TransitionsAnalyticsQuery(config, arrayOfZuluDates) {
      TransitionsAnalyticsQuery.__super__.constructor.call(this, config);
      throw new Error('Not yet implemented');
    }

    return TransitionsAnalyticsQuery;

  })(GuidedAnalyticsQuery);

  root.AnalyticsQuery = AnalyticsQuery;

  root.GuidedAnalyticsQuery = GuidedAnalyticsQuery;

  root.AtAnalyticsQuery = AtAnalyticsQuery;

  root.AtArrayAnalyticsQuery = AtArrayAnalyticsQuery;

  root.BetweenAnalyticsQuery = BetweenAnalyticsQuery;

  root.TimeInStateAnalyticsQuery = TimeInStateAnalyticsQuery;

  root.TransitionsAnalyticsQuery = TransitionsAnalyticsQuery;

}).call(this);
