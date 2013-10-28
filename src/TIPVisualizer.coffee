if exports?
  lumenize = require('../lib/lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{utils} = lumenize

class TIPVisualizer extends VisualizerBase
  ###
  ###

  initialize: () ->
    if @config.trace
      console.log('in TIPVisualizer.initialize')
    super()  # sets lumenizeCalculatorConfig.tz

    @config.toolTipFieldNames = []
    for s in @config.showTheseFieldsInToolTip
      if utils.type(s) is 'string'
        field = s
      else
        field = s.field
      @config.toolTipFieldNames.push(field)
      
    trackLastValueForTheseFields = ['_ValidTo'].concat(@config.toolTipFieldNames)
    unless @config.radiusField.field in trackLastValueForTheseFields
      trackLastValueForTheseFields.push(@config.radiusField.field)

    @config.lumenizeCalculatorConfig.trackLastValueForTheseFields = trackLastValueForTheseFields
    @config.lumenizeCalculatorConfig.granularity = 'hour'
    @config.lumenizeCalculatorConfig.workDayStartOn = @config.workDayStartOn
    @config.lumenizeCalculatorConfig.workDayEndBefore = @config.workDayEndBefore
    @config.lumenizeCalculatorConfig.holidays = @config.holidays
    @config.lumenizeCalculatorConfig.workDays = @config.workDays
    @LumenizeCalculatorClass = lumenize.TimeInStateCalculator

  onNewDataAvailable: () =>
    if @config.trace
      console.log('in TIPVisualizer.onNewDataAvailable')
    queryConfig = {
      'X-RallyIntegrationName': 'TIP Chart (prototype)',
      'X-RallyIntegrationVendor': 'Rally Red Pill',
      'X-RallyIntegrationVersion': '0.2.0',
      workspaceOID: @projectAndWorkspaceScope.workspaceOID
    }
    unless @upToDateISOString?
      @upToDateISOString = '2011-12-01T00:00:00.000Z'  # The first full month of the Lookback API

    @analyticsQuery = new TimeInStateAnalyticsQuery(queryConfig, @upToDateISOString, @config.statePredicate)

    if @projectAndWorkspaceScope.projectScopingUp
      if @config.debug
        console.log('Project scoping up. OIDs in scope: ', @projectAndWorkspaceScope.projectOIDsInScope)
      @analyticsQuery.scope('Project', @projectAndWorkspaceScope.projectOIDsInScope)
    else if @projectAndWorkspaceScope.projectScopingDown
      if @config.debug
        console.log('Project scoping down. Setting _ProjectHierarchy to: ', @projectAndWorkspaceScope.projectOID)
      @analyticsQuery.scope('_ProjectHierarchy', @projectAndWorkspaceScope.projectOID)
    else
      if @config.debug
        console.log('Project with no up or down scoping. Setting Project to: ', @projectAndWorkspaceScope.projectOID)
      @analyticsQuery.scope('Project', @projectAndWorkspaceScope.projectOID)

    @analyticsQuery
      .type(@config.type)
      .fields(@config.toolTipFieldNames)
#      .pagesize(3000)  # For debugging incremental update
 
    if @config.leafOnly
      @analyticsQuery.leafOnly()

    if @config.asOf?
      @analyticsQuery.additionalCriteria({_ValidFrom:{$lt:@getAsOfISOString()}})

    if @config.debug
      @analyticsQuery.debug()
      console.log('Requesting data...')

    @fetchPending = true

    @analyticsQuery.getPage(@onSnapshotsReceieved)

  getHashForCache: () ->
    if @config.trace
      console.log('in TIPVisualizer.getHashForCache')
    hashObject = {}
    userConfig = utils.clone(@userConfig)
    delete userConfig.debug
    delete userConfig.trace
    delete userConfig.daysToShow
    delete userConfig.showStillInProgress
    hashObject.userConfig = userConfig
    hashObject.projectAndWorkspaceScope = @projectAndWorkspaceScope
    hashObject.workspaceConfiguration = @workspaceConfiguration
    salt = 'TIP v0.2.95'
#    salt = Math.random().toString()
    hashString = JSON.stringify(hashObject)
    out = md5(hashString + salt)
    return out

  updateVisualizationData: () ->
    # override
    # Transform the data into whatever form your visualization expects from the data in the @lumenizeCalculator
    # Store your calculations into @visualizationData, which will be sent to the visualization create and update callbacks.
    # Try to fully populate the x-axis based upon today even if you have no data for later dates yet.
    if @config.trace
      console.log('in TIPVisualizer.updateVisualizationData')

    calculatorResults = @lumenizeCalculator.getResults()

#    if @config.debug
#      console.log('length of calculatorResults before @currentObjectID filtering: ', calculatorResults.length)
#    calculatorResults = (r for r in calculatorResults when r.ObjectID in @currentObjectIDs)
#    if @config.debug
#      console.log('length of calculatorResults after @currentObjectID filtering: ', calculatorResults.length)

    if calculatorResults.length == 0
      if @config.debug
        console.log('No calculatorResults.')
      if @fetchPending
        if @config.debug
          console.log('fetchPending is true so returning with visualizationData = null.')
        @visualizationData = null
        return
      else
        series = []
        if @config.debug
          console.log('fetchPending is false so filling in with blanks')
    else
      @virgin = false
      inProcessItems = []
      notInProcessItems = []
      if @config.asOf?
        asOfMilliseconds = new lumenize.Time(@config.asOf, 'millisecond', @config.lumenizeCalculatorConfig.tz).getJSDate(@config.lumenizeCalculatorConfig.tz).getTime()
      else
        asOfMilliseconds = new Date().getTime()
      millisecondsToShow = @userConfig.daysToShow * 1000 * 60 * 60 * 24
      startMilliseconds = asOfMilliseconds - millisecondsToShow
      for row in calculatorResults
        jsDateMilliseconds = new lumenize.Time(row._ValidTo_lastValue, 'millisecond', @config.lumenizeCalculatorConfig.tz).getJSDate(@config.lumenizeCalculatorConfig.tz).getTime()
        if jsDateMilliseconds > asOfMilliseconds
          row.x = asOfMilliseconds
        else
          row.x = jsDateMilliseconds
        row.x -= Math.random() * 1000 * 60 * 60 * 24  # Separate data points that show up on top of each other
        if @config.radiusField?
          row.marker = {radius: @config.radiusField.f(row[@config.radiusField.field + "_lastValue"])}
        if jsDateMilliseconds > startMilliseconds
          if jsDateMilliseconds < asOfMilliseconds
            notInProcessItems.push(row)
          else
            inProcessItems.push(row)

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

      # converting ticks (hours) into days and adding to inProcessItems
      for row in inProcessItems
        row.days = row.ticks / workHours
      for row in notInProcessItems
        row.days = row.ticks / workHours

    histogramResults = lumenize.histogram(notInProcessItems, 'days')
    unless histogramResults?
      if @config.debug
        console.log('No histogramResults. Returning.')
      return

    {buckets, chartMax, valueMax, bucketSize, clipped} = histogramResults

    for row in notInProcessItems
      row.y = row.clippedChartValue
    for row in inProcessItems
      if row.days > chartMax
        row.y = chartMax
      else
        row.y = row.days
#      console.log(row)

    histogramCategories = []
    histogramData = []
    for b in buckets
      histogramCategories.push(b.label)
      histogramData.push(b.count)

    series = [
      {name: 'Not in Process', data: notInProcessItems},
      {name: 'In Process', data: inProcessItems},
      {name: 'Percentile', data: [], yAxis: 1, showInLegend: false}
    ]
    @visualizationData = {series, histogramResults, histogramCategories, histogramData, startMilliseconds, asOfMilliseconds}

    # For almost all other charts, we'll be able to simply update the data but this TIP chart controls the tickInterval
    # which cannot be updated at run time according to HighCharts support so we have to recreate it each time.

  
this.TIPVisualizer = TIPVisualizer
  