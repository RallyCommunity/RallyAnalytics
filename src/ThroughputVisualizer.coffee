if exports?
  lumenize = require('../lib/lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{utils, Time} = lumenize

class ThroughputVisualizer extends VisualizerBase
  ###
  @cfg {String} tz The timezone for analysis in the form like `America/New_York`
  @cfg {String} [validFromField = "_ValidFrom"]
  @cfg {String} [validToField = "_ValidTo"]
  @cfg {String} [uniqueIDField = "ObjectID"]
  @cfg {String} granularity 'month', 'week', 'quarter', etc. Use Time.MONTH, Time.WEEK, etc.
  @cfg {Number} numberOfPeriodsToShow
  @cfg {String[]} [fieldsToSum=[]] It will track the count automatically but it can keep a running sum of other fields also
  ###

  initialize: () ->
    super()  # sets @asOfISOString

    unless @config.validFromField?
      @config.validFromField = '_ValidFrom'

    @config.lumenizeCalculatorConfig.validFromField = @config.validFromField
    @config.lumenizeCalculatorConfig.validToField = @config.validToField
    @config.lumenizeCalculatorConfig.uniqueIDField = @config.uniqueIDField
    @config.lumenizeCalculatorConfig.granularity = @config.granularity
    @config.lumenizeCalculatorConfig.fieldsToSum = @config.fieldsToSum
    @config.lumenizeCalculatorConfig.asterixToDateTimePeriod = false
    @LumenizeCalculatorClass = lumenize.TransitionsCalculator

  onNewDataAvailable: () =>

    queryConfig = {
      'X-RallyIntegrationName': 'ThroughputVisualizer (prototype)',
      'X-RallyIntegrationVendor': 'Rally Red Pill',
      'X-RallyIntegrationVersion': '0.1.0',
      workspaceOID: @projectAndWorkspaceScope.workspaceOID
    }
    unless @upToDate?
      @upToDate = '2011-12-01T00:00:00.000Z'  # The first full month of the Lookback API

    @analyticsQuery = new TransitionsAnalyticsQuery(queryConfig, @upToDate, @config.transitionsPredicate)
    @analyticsQueryToSubtract = new TransitionsAnalyticsQuery(queryConfig, @upToDate, @config.transitionsToSubtractPredicate)

    if @projectAndWorkspaceScope.projectScopingDown
      @analyticsQuery.scope('_ProjectHierarchy', @projectAndWorkspaceScope.projectOID)
      @analyticsQueryToSubtract.scope('_ProjectHierarchy', @projectAndWorkspaceScope.projectOID)
    else
      @analyticsQuery.scope('Project', @projectAndWorkspaceScope.projectOID)
      @analyticsQueryToSubtract.scope('Project', @projectAndWorkspaceScope.projectOID)

    @analyticsQuery.type(@config.type)
    @analyticsQueryToSubtract.type(@config.type)

#    @analyticsQuery.leafOnly()

#    @analyticsQuery.pagesize(3000)  # For debugging incremental update

    if @config.asOf?
      criteria = {}
      criteria[@config.validFromField] = {$lt: @asOfISOString}
      @analyticsQuery.additionalCriteria(criteria)
      @analyticsQueryToSubtract.additionalCriteria(criteria)

    if @config.debug
      @analyticsQuery.debug()
      @analyticsQueryToSubtract.debug()
      console.log('Requesting data...')

    @gotSnapshots = false
    @gotSnapshotsToSubtract = false
    @analyticsQuery.getPage(@_gotSnapshots)
    @analyticsQueryToSubtract.getPage(@_gotSnapshotsToSubtract)

  _gotSnapshots: (@snapshots, @startOn, @endBefore) =>
    @gotSnapshots = true
    @onSnapshotsReceieved()

  _gotSnapshotsToSubtract: (@snapshotsToSubtract, startOn, endBefore) =>
    @gotSnapshotsToSubtract = true
    @onSnapshotsReceieved()

  onSnapshotsReceieved: (snapshots, startOn, endBefore, queryInstance = null, snapshotsToSubtract) =>
    unless @gotSnapshots and @gotSnapshotsToSubtract
      return
    snapshots = @snapshots
    snapshotsToSubtract = @snapshotsToSubtract
    startOn = @startOn
    endBefore = @endBefore
    if snapshots.length > 0 or snapshotsToSubtract > 0
      @dirty = true
    else
      @dirty = false
    @lastQueryReceivedMilliseconds = new Date().getTime()
    @upToDate = endBefore
    @deriveFieldsOnSnapshots(snapshots)
    @deriveFieldsOnSnapshots(snapshotsToSubtract)
    if @asOfISOString < endBefore
      endBefore = @asOfISOString
    @updateCalculator(snapshots, startOn, endBefore, snapshotsToSubtract)  # This should also update the cache
    @createOrUpdateVisualization()
    unless @config.asOf? and @upToDate < @config.asOf
      if @analyticsQuery.hasMorePages() or @analyticsQueryToSubtract.hasMorePages()
        if @analyticsQuery.hasMorePages()
          @gotSnapshots = false
          @analyticsQuery.getPage(@_gotSnapshots)
        if @analyticsQueryToSubtract.hasMorePages()
          @gotSnapshotsToSubtract = false
          @analyticsQueryToSubtract.getPage(@_gotSnapshotsToSubtract)
      else
        @newDataExpected(undefined, @config.refreshIntervalMilliseconds)

  getHashForCache: () ->
    hashObject = {}
    userConfig = utils.clone(@userConfig)
    delete userConfig.debug
    delete userConfig.periodsToShow
    hashObject.userConfig = userConfig
    hashObject.projectAndWorkspaceScope = @projectAndWorkspaceScope
    hashObject.workspaceConfiguration = @workspaceConfiguration
    salt = 'Throughput v0.2.70'
    salt = Math.random().toString()
    hashString = JSON.stringify(hashObject)
    out = md5(hashString + salt)
    return out

  createOrUpdateVisualization: () ->
    # override
    # Transform the data into whatever form your visualization expects from the data in the @lumenizeCalculator
    # Store your calculations into @visualizationData, which will be sent to the visualization create and update callbacks.
    # Try to fully populate the x-axis based upon today even if you have no data for later dates yet.

    calculatorResults = @lumenizeCalculator.getResults()

    if calculatorResults.length == 0
      @visualizationData = null
      @createVisualizationCB(@visualizationData)
      return

    unless @dirty
      return

    if @config.debug
      console.log(calculatorResults)

    if @config.asOf?
      highestTimeString = @asOfISOString
    else
      highestTimeString = Time.getISOStringFromJSDate()

    lowestTimePeriod = new Time(highestTimeString, @config.granularity, @config.tz).addInPlace(-1 * @config.numberOfPeriodsToShow + 1).toString()
    highestTimePeriod = new Time(highestTimeString, @config.granularity, @config.tz).toString()

    categories = []
    series = []
    for row in calculatorResults
      if lowestTimePeriod <= row.timePeriod <= highestTimePeriod
        categories.push(row.timePeriod)
    categories[categories.length - 1] += '*'

    for f, index in @config.fieldNames
      data = []
      for row in calculatorResults
        if lowestTimePeriod <= row.timePeriod <= highestTimePeriod
          data.push(row[f])
      series.push({name: @config.seriesNames[index], data: data})

    @visualizationData = {categories, series}

    # For almost all other charts, we'll be able to simply update the data but this TIP chart controls the tickInterval
    # which cannot be updated at run time according to HighCharts support so we have to recreate it each time.
    @createVisualizationCB(@visualizationData)

    return
  
this.ThroughputVisualizer = ThroughputVisualizer
  