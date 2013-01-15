# !TODO: Add support for deriveFieldsOnResults

###
The general structure of an incrementally update-able visualization follows these steps:

1. Gather the parameters you'll need to specify the visualization
   a. Gather some info from Rally's standard WSAPI
   b. Gather some info from the user.

2. Create a hash from info from above to be used as the key for cache lookup.

3. Restore the cached calculation using LocalCache.

4. Render the cached calculation. Leave space for updates on the x-axis. Show spinners for missing parts.

5. Query the Lookback API for the incremental "snapshots" not found in the cache.
   Get one page's worth of updates. Maybe 10,000 snapshots max?

6. Update the calculation/manipulation/aggregation of the snapshot data.

7. Update the chart.

8. If there are still more pages of snapshots to update repeat starting at step 5.
###

if exports?
  lumenize = require('../lib/Lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{utils} = lumenize

class VisualizerBase  # maybe extends Observable
  ###
  @class ChartVisualizerBase
    This is intended to the be the base class for ChartVisualizers. It assumes a template method pattern where the parts
    of the algorithm that have to do with saving to and restoring from the LocalCache (using localStorage API) and
    providing events for config changes or data updates.

    You must override these methods:
      * initialize() - set @LumenizeCalculatorClass (implements Lumenize.iCalculator)

    You may wish to override:
      * deriveFields(snapshots)

  @cfg {Number} [refreshIntervalMilliseconds = 30 * 60 * 1000] Defaults to 30 minutes

  @property {Object} userConfig This is whatever the users passes in under the @userConfig parameter in the constructor. It is useful for creating the cache hash. The contents of this will be visualizer specific

  @property {Object} config Starts with all the values in userConfig but more may be added
  @property {Number} [config.refreshIntervalMilliseconds = 5 * 60 * 1000] The chart will automatically refresh after this many milliseconds
  @property {Object} [config.deriveFieldsConfig] If you include this, it will pass it into Lumenize.deriveFields as the config Object every time it gets new snapshots to process.
  @property {Boolean} [config.debug = false]
  @property {Object} config.lumenizeCalculatorConfig The config that will be passed to the Lumenize calculator upon instantiation. Do not put x-axis range info in here.

  @property {Object} projectAndWorkspaceScope
  @property {Number} projectAndWorkspaceScope.workspaceOID
  @property {Boolean} projectAndWorkspaceScope.projectScopingUp
  @property {Boolean} projectAndWorkspaceScope.projectScopingDown
  @property {Number} projectAndWorkspaceScope.projectOID

  @property {Object} workspaceConfiguration Has whatever fields come from Rally but WorkDays and TimeZone (note Caps) are often used by calculators

  @property {Lumenize.iCalculator} LumenizeCalculatorClass Must be set; typically in your initialize() method

  @property {Object} visualizationData This is where you store the data that you want to communicate to your visualizations.
    It will be passed into createVisualizationCB.

  @property {iAnalyticsQuery} analyticsQuery Instantiate this in your onNewDataAvailable() method.

  @property {String} upToDate A ISOString (e.g. '2012-01-01T12:34:56.789Z') indicating the last moment that this chart is
    up to date. You should not set this but you can read from it. It will be set when new snapshots are added or it's
    restored from the cache.
  @readonly
  ###
  # The properties below are meant to be private and won't be documented
  # @property {LocalCache} cache
  # @property {Object} timeoutHandle
  # @property {Lumenize.iCalculator} lumenizeCalculator
  # @property {Function} createVisualizationCB function that takes one parameter @visualizationData
  # @property {Boolen} dirty Flag to know whether or not to refresh the visualizations

  constructor: (@visualizations, @userConfig, @createVisualizationCB) ->
    ###
    You should not have a constructor for the sub-class. Rather, put your code in initialize(). If for some crazy
    reason you really want a constructor, make sure it looks like this:
    ```
    constructor: (myCustomArgument, remainingArguments...) ->
      # Any code you want to execute before initialize(). Use myCustomArgument.
      super(remainingArguments...)
      # Any code you want to execute after initialize(). Use myCustomArgument.
    ```
    ###
    @config = utils.clone(@userConfig)
    @timeoutHandle = null
    @cache = new LocalCache()
    unless @config.debug?
      @config.debug = false

    @getProjectAndWorkspaceScope()

  getProjectAndWorkspaceScope: () ->
    if top == self
      workspaceOID = 41529001
      projectScopingUp = false
      projectScopingDown = true
#       projectOID = 279050021  # A-Team
      projectOID = 81147451  # RallyDev
    else
      workspaceOID = __WORKSPACE_OID__
      projectScopingUp = __PROJECT_SCOPING_UP__
      projectScopingDown = __PROJECT_SCOPING_DOWN__
      projectOID = __PROJECT_OID__
    scope = {workspaceOID, projectScopingUp, projectScopingDown, projectOID}

    _callback = (projectAndWorkspaceScope) =>
      @projectAndWorkspaceScope = projectAndWorkspaceScope
      @getWorkspaceConfiguration()

    # Call to fetch this data passing in _callback
    _callback(scope)  # !TODO: Delete this line once a real query and callback is added

  getWorkspaceConfiguration: () ->
    workspaceConfiguration = {
      DateFormat: 'MM/dd/yyyy',
      DateTimeFormat: 'MM/dd/yyyy hh:mm:ss a',
      IterationEstimateUnitName: 'Points',
      ReleaseEstimateUnitName: 'Points',
      TaskUnitName: 'Hours',
      TimeTrackerEnabled: true,
      TimeZone: 'America/Denver',
      WorkDays: 'Monday,Tuesday,Wednesday,Thursday,Friday'
    }

    _callback = (workspaceConfiguration) =>
      @workspaceConfiguration = workspaceConfiguration
      @initialize()
      @onConfigOrScopeUpdated()  # or maybe @fireEvent('CONFIG_OR_SCOPE_UPDATED')

    # Call to fetch this data passing in _callback
    _callback(workspaceConfiguration)  # !TODO: Delete this line once a real query and callback is added

  onConfigOrScopeUpdated: () ->  # register this as the callback for events where the configuration changes
    savedState = @cache.getItem(@getHashForCache())
    if savedState?
      @lumenizeCalculator = @LumenizeCalculatorClass.newFromSavedState(savedState)
      @upToDate = @lumenizeCalculator.upToDate
    else
      @lumenizeCalculator = new @LumenizeCalculatorClass(@config.lumenizeCalculatorConfig)
      @upToDate = null

    @createOrUpdateVisualization()
    @onNewDataAvailable()

  onSnapshotsReceieved: (snapshots, startOn, endBefore, queryInstance = null) =>
    if snapshots.length > 0
      @dirty = true
    else
      @dirty = false
    @lastQueryReceivedMilliseconds = new Date().getTime()
    @upToDate = endBefore
    @deriveFieldsOnSnapshots(snapshots)
    if @asOfISOString < endBefore
      endBefore = @asOfISOString
    @updateCalculator(snapshots, startOn, endBefore)  # This should also update the cache
    @createOrUpdateVisualization()
    unless @config.asOf? and @upToDate < @config.asOf
      if @analyticsQuery.hasMorePages()
        @onNewDataAvailable()  # This is intentionally calling @onNewDataAvailable rather than getPage(). Your @onNewDataAvailable could just call getPage() or it can do something else like the TIP Chart requires.
      else
        @newDataExpected(undefined, @config.refreshIntervalMilliseconds)

  newDataExpected: (paddingDelay = 30 * 1000, etlDelay = 30 * 60 * 1000) ->  # Register this as event handler for when data on the page changes. Need to adjust padding based upon usage
    delay = etlDelay + paddingDelay
    if @timeoutHandle?
      clearTimeout(@timeoutHandle)
    @timeoutHandle = setTimeout(@onNewDataAvailable, delay)

  removeFromCacheAndRecalculate: () ->
    @upToDate = null
    @cache.removeItem(@getHashForCache())
    @onConfigOrScopeUpdated()

  updateCalculator: (snapshots, startOn, endBefore, rest...) ->
    ###
    @method updateCalculator
      Allows you to incrementally add snapshots to this calculator. It will also update the cache.
    @param {Object[]} snapshots An array of temporal data model snapshots.
    @param {String} startOn A ISOString (e.g. '2012-01-01T12:34:56.789Z') indicating the time start of the period of
      interest. On the second through nth call, this must equal the previous endBefore.
    @param {String} endBefore A ISOString (e.g. '2012-01-01T12:34:56.789Z') indicating the moment just past the time
      period of interest. This should be the ETLDate from the results of your query to the Lookback API.
    ###
    @lumenizeCalculator.addSnapshots(snapshots, startOn, endBefore, rest...)
    savedState = @lumenizeCalculator.getStateForSaving()
    @cache.setItem(@getHashForCache(), savedState)

  # You may want to override the following methods

  initialize: () ->
    # Optionally override. This is called after the @workspaceConfiguration and @projectAndWorkspaceScope is set in case
    # you need those values in your initialization.
    unless @config.lumenizeCalculatorConfig?
      @config.lumenizeCalculatorConfig = {}
    @config.lumenizeCalculatorConfig.workDays = @workspaceConfiguration.WorkDays
    if @userConfig.tz?
      @config.lumenizeCalculatorConfig.tz = @userConfig.tz
    else
      @config.tz = @workspaceConfiguration.TimeZone
      @config.lumenizeCalculatorConfig.tz = @workspaceConfiguration.TimeZone  # You may want to override this with the user timezone
    # Set holidays here once they are avaialable from Rally data model

    if @config.asOf?
      @asOfISOString = new lumenize.Time(@config.asOf, 'millisecond').getISOStringInTZ(@config.lumenizeCalculatorConfig.tz)
    else
      @asOfISOString = null


  deriveFieldsOnSnapshots: (snapshots) ->
    # Optionally override if you need to do something special. Otherwise, it will use @config.deriveFieldsOnSnapshotsConfig
    # !TODO: Just pass the config into the TimeInStateCalculator once it's upgraded to support this
    if @config.deriveFieldsOnSnapshotsConfig?
      Lumenize.deriveFields(snapshots, @config.deriveFieldsOnSnapshotsConfig)

  # You are expected to override the following methods

  onNewDataAvailable: () ->
    # override
    # Be sure to set @analyticsQuery in here. The last line of this method should be:
    #
    #   ```@analyticsQuery.getPage(@onSnapshotsReceieved)```
    #
    # Your @analyticsQuery should implement hasMorePages() method that returns a boolean indicating
    # if there are more pages. It will then call @analyticsQuery.getPage(@onSnapshotsReceived). Make sure your
    # iAnalyticsQuery.getPage method will call the passed in callback (@onSnapshotsReceived) with the right parameters:
    # (snapshots, startOn, endBefore).
    #
    # example code might look like this:
    # queryConfig = {<your_query_config_settings}
    # @analyticsQuery = new AnalyticsQuery(queryConfig, @upToDate, <other_parameters>)
    # # set parameters of query
    # @analyticsQuery.getPage(@onSnapshotsReceieved)

    @analyticsQuery.getPage(@onSnapshotsReceieved)  # must be last line of this method

  createOrUpdateVisualization: () ->
    # override
    # Transform the data into whatever form your visualization expects from the data in the @lumenizeCalculator

  getHashForCache: () ->
    # override
    # Use config parameters, scope, whatever to provide a unique hash for cached instances of this visualizer.
    # You do not want any information about the current time to creep into this hash because this is meant to
    # be incrementally updateable. However, if there is an absolute time like '2011-12-01' (the first full month after
    # the Lookback API started capturing data), that's OK to be included. You may wish to add the version of your
    # visualizer (or even the Lumenize version) as salt to this cache, which would force a recalculation whenever
    # the version updated.


this.VisualizerBase = VisualizerBase
