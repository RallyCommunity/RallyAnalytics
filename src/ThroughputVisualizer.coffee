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
    super()

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
    unless @upToDateISOString?
      @upToDateISOString = '2011-12-01T00:00:00.000Z'  # The first full month of the Lookback API

    @analyticsQuery = new TransitionsAnalyticsQuery(queryConfig, @upToDateISOString, @config.transitionsPredicate)
    @analyticsQueryToSubtract = new TransitionsAnalyticsQuery(queryConfig, @upToDateISOString, @config.transitionsToSubtractPredicate)

    if @projectAndWorkspaceScope.projectScopingUp
      @analyticsQuery.scope('Project', @projectAndWorkspaceScope.projectOIDsInScope)
      @analyticsQueryToSubtract.scope('Project', @projectAndWorkspaceScope.projectOIDsInScope)
    else if @projectAndWorkspaceScope.projectScopingDown
      @analyticsQuery.scope('_ProjectHierarchy', @projectAndWorkspaceScope.projectOID)
      @analyticsQueryToSubtract.scope('_ProjectHierarchy', @projectAndWorkspaceScope.projectOID)
    else
      @analyticsQuery.scope('Project', @projectAndWorkspaceScope.projectOID)
      @analyticsQueryToSubtract.scope('Project', @projectAndWorkspaceScope.projectOID)

    @analyticsQuery.type(@config.type)
    @analyticsQueryToSubtract.type(@config.type)

    if @config.fieldsToSum?
      @analyticsQuery.fields(@config.fieldsToSum)
      @analyticsQueryToSubtract.fields(@config.fieldsToSum)

    if @config.leafOnly
      @analyticsQuery.leafOnly()

#    @analyticsQuery.pagesize(30)  # For debugging incremental update

    if @config.asOf?
      criteria = {}
      criteria[@config.validFromField] = {$lt: @getAsOfISOString()}
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

  _gotSnapshotsToSubtract: (@snapshotsToSubtract, @startOnToSubtract, @endBeforeToSubtract) =>
    @gotSnapshotsToSubtract = true
    @onSnapshotsReceieved()

  @_truncateTo: (s, isoString, validFromField) ->
    out = []
    for row in s
      if row[validFromField] <= isoString
        out.push(row)
    return out

  onSnapshotsReceieved: (snapshots, startOn, endBefore, queryInstance = null, snapshotsToSubtract) =>
    unless @gotSnapshots and @gotSnapshotsToSubtract
      return
    utils.assert(@startOn == @startOnToSubtract, 'startOn for the snapshots and snapshotsToSubtract should match.')
    startOn = @startOn

    # If the one is denser than the other (snapshots should be more dense than snapshotsToSubtract), truncate it to the endBefore of the denser one
    if @endBefore <= @endBeforeToSubtract
      endBefore = @endBefore
      snapshotsToSubtract = ThroughputVisualizer._truncateTo(@snapshotsToSubtract, endBefore, @config.validFromField)
      snapshots = @snapshots
    else
      endBefore = @endBeforeToSubtract
      @endBefore = endBefore
      snapshots = ThroughputVisualizer._truncateTo(@snapshots, endBefore, @config.validFromField)
      snapshotsToSubtract = @snapshotsToSubtract

    if snapshots.length > 0 or snapshotsToSubtract > 0
      @dirty = true
    else
      @dirty = false
    @lastQueryReceivedMilliseconds = new Date().getTime()
    @upToDateISOString = endBefore
    @deriveFieldsOnSnapshots(snapshots)
    @deriveFieldsOnSnapshots(snapshotsToSubtract)
    asOfISOString = @getAsOfISOString()
    if asOfISOString < endBefore
      endBefore = asOfISOString
    @updateCalculator(snapshots, startOn, endBefore, snapshotsToSubtract)  # This should also update the cache
    @updateVisualization()
    unless @config.asOf? and @upToDateISOString < @config.asOf
      if @analyticsQuery.hasMorePages() or @analyticsQueryToSubtract.hasMorePages()
        @onNewDataAvailable()
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
    salt = 'Throughput v0.2.80'
#    salt = Math.random().toString()
    hashString = JSON.stringify(hashObject)
    out = md5(hashString + salt)
    return out

  updateVisualizationData: () ->
    # override
    # Transform the data into whatever form your visualization expects from the data in the @lumenizeCalculator
    # Store your calculations into @visualizationData, which will be sent to the visualization create and update callbacks.
    # Try to fully populate the x-axis based upon today even if you have no data for later dates yet.

    calculatorResults = @lumenizeCalculator.getResults()

    if calculatorResults.length == 0
      @visualizationData = null
      @createVisualizationCB(@visualizationData)
      return

#    unless @dirty
#      return

    if @config.debug
      console.log(calculatorResults)

    highestTimeString = @getAsOfISOString()

    lowestTimePeriod = new Time(highestTimeString, @config.granularity, @config.tz).addInPlace(-1 * @config.numberOfPeriodsToShow + 1).toString()
    highestTimePeriod = new Time(highestTimeString, @config.granularity, @config.tz).toString()

    categories = []
    ids = []
    countValues = []
    series = []
    for row in calculatorResults
      if lowestTimePeriod <= row.timePeriod <= highestTimePeriod
        categories.push(row.timePeriod)
        ids.push(row.ids)
        countValues.push(row.count_values)
    categories[categories.length - 1] += '*'

    for f, index in @config.fieldNames
      data = []
      for row in calculatorResults
        if lowestTimePeriod <= row.timePeriod <= highestTimePeriod
          data.push(row[f])
      series.push({name: @config.seriesNames[index], data: data})

    @visualizationData = {categories, series, ids, countValues}

    # For almost all other charts, we'll be able to simply update the data but this TIP chart controls the tickInterval
    # which cannot be updated at run time according to HighCharts support so we have to recreate it each time.
    @createVisualizationCB(@visualizationData)

  updateVisualization: () ->
    # most likely override. The default here is to just recreate it again but you should try to update the HighCharts
    # Objects in @visualizations.
    @updateVisualizationData()
    chart = @visualizations.chart
    series = chart.series
    for s, index in @visualizationData.series
      series[index].setData(s.data, false)
    chart.xAxis[0].setCategories(@visualizationData.categories, false)
    chart.redraw()
  
this.ThroughputVisualizer = ThroughputVisualizer
  