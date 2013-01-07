if exports?
  lumenize = require('../lib/lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{utils} = lumenize

class TIPChartCalculator extends ChartCalculatorBase
  ###
  ###

  initialize: () ->
    super()
    trackLastValueForTheseFields = ['_ValidTo']
    for s in @config.showTheseFieldsInToolTip
      trackLastValueForTheseFields.push(s)
    @config.lumenizeCalculatorConfig.trackLastValueForTheseFields = trackLastValueForTheseFields
    @config.lumenizeCalculatorConfig.granularity = 'hour'
    @config.lumenizeCalculatorConfig.workDayStartOn = @config.workDayStartOn
    @config.lumenizeCalculatorConfig.workDayEndBefore = @config.workDayEndBefore
    @config.lumenizeCalculatorConfig.holidays = @config.holidays
    @config.lumenizeCalculatorConfig.workDays = @config.workDays
    @LumenizeCalculatorClass = lumenize.TimeInStateCalculator

  onNewDataAvailable: () =>
    queryConfig = {
      'X-RallyIntegrationName': 'TIP Chart (prototype)',
      'X-RallyIntegrationVendor': 'Rally Red Pill',
      'X-RallyIntegrationVersion': '0.2.0',
      workspaceOID: @projectAndWorkspaceScope.workspaceOID
    }
    unless @upToDate?
      @upToDate = '2011-12-01T00:00:00.000Z'  # The first full month of the Lookback API

    @analyticsQuery = new TimeInStateAnalyticsQuery(queryConfig, @upToDate, @config.statePredicate)

    if @projectAndWorkspaceScope.projectScopingDown
      @analyticsQuery.scope('_ProjectHierarchy', @projectAndWorkspaceScope.projectOID)
    else
      @analyticsQuery.scope('Project', @projectAndWorkspaceScope.projectOID)

    @analyticsQuery
      .type(@config.type)
      .fields(@userConfig.showTheseFieldsInToolTip)
#      .pagesize(3000)  # !TODO: Delete this after done debugging

    if @config.leafOnly
      @analyticsQuery.leafOnly()

    if @config.debug
      @analyticsQuery.debug()
      console.log('Requesting data...')

    @analyticsQuery.getPage(@onSnapshotsReceieved)

  getHashForCache: () ->
    hashObject = {}
    userConfig = utils.clone(@userConfig)
    delete userConfig.debug
    delete userConfig.daysToShow
    delete userConfig.showStillInProgress
    hashObject.userConfig = userConfig
    hashObject.projectAndWorkspaceScope = @projectAndWorkspaceScope
    hashObject.workspaceConfiguration = @workspaceConfiguration
    salt = 'v0.2.56'
#    salt = Math.random().toString()
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

    timeInState = []
    nowMilliseconds = new Date().getTime()
    millisecondsToShow = @userConfig.daysToShow * 1000 * 60 * 60 * 24
    for row in calculatorResults
      jsDateMilliseconds = new lumenize.Time(row._ValidTo_lastValue, 'millisecond').getJSDate(@config.lumenizeCalculatorConfig.tz).getTime()
      if jsDateMilliseconds > nowMilliseconds
        row.x = nowMilliseconds
      else
        row.x = jsDateMilliseconds
      row.x -= Math.random() * 1000 * 60 * 60  # Seperate data points that show up on top of each other
      if @userConfig.showStillInProcess or jsDateMilliseconds < nowMilliseconds
        if nowMilliseconds - row.x < millisecondsToShow
          timeInState.push(row)

    unless timeInState.length > 0
      return

    # calculating workHours from workDayStartOn and workDayEndBefore
    startOnInMinutes = @config.workDayStartOn.hour * 60
    if @config.workDayStartOn?.minute
      startOnInMinutes += @config.workDayStartOn.minute
    endBeforeInMinutes = @config.workDayEndBefore.hour * 60
    if @config.workDayEndBefore?.minute
      endBeforeInMinutes += @config.workDayEndBefore.minute
    if startOnInMinutes < endBeforeInMinutes
      workMinutes = endBeforeInMinutes - startOnInMinutes
    else
      workMinutes = 24 * 60 - startOnInMinutes
      workMinutes += endBeforeInMinutes
    workHours = workMinutes / 60

    # converting ticks (hours) into days and adding to timeInState
    for row in timeInState
      row.days = row.ticks / workHours

    histogramResults = lumenize.histogram(timeInState, 'days')
    unless histogramResults?
      return

    {buckets, chartMax, valueMax, bucketSize, clipped} = histogramResults

    for row in timeInState
      row.y = row.clippedChartValue

    if @config.debug
      console.log(timeInState)

    histogramCategories = []
    histogramData = []
    for b in buckets
      histogramCategories.push(b.label)
      histogramData.push(b.count)

    @visualizationData = {timeInState, histogramResults, histogramCategories, histogramData}

    # For almost all other charts, we'll be able to simply update the data but this TIP chart controls the tickInterval
    # which cannot be updated at run time according to HighCharts support so we have to recreate it each time.
    @createVisualizationCB(@visualizationData)

    return
  
this.TIPChartCalculator = TIPChartCalculator
  