if exports?
  lumenize = require('../lib/lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{utils, Time} = lumenize

class CFDVisualizer extends VisualizerBase
  ###
  ###

#  monitorScopeDropdown: (javascriptScope) =>
#    parent.Rally.environment.getMessageBus().subscribe("timeBoxScopeChange", (a) =>
#      record = a.getRecord()
#      data = record.data
#      javascriptScope.userConfig.scopeData = data
#      javascriptScope.config.scopeData = data
#      javascriptScope.config.lumenizeCalculatorConfig.startOn = new Time(@config.scopeData.StartDate)
#        .getISOStringInTZ(@config.lumenizeCalculatorConfig.tz)
#      javascriptScope.config.lumenizeCalculatorConfig.endBefore = new Time(@config.scopeData.EndDate)
#        .addInPlace(1, @config.lumenizeCalculatorConfig.granularity)
#        .getISOStringInTZ(@config.lumenizeCalculatorConfig.tz)
#      javascriptScope.scopeDataSet = true
#      javascriptScope.onConfigOrScopeUpdated()
#    )

  initialize: () ->
    if @config.trace
      console.log('in CFDVisualizer.initialize')
    super()  # sets lumenizeCalculatorConfig.tz

#    if parent?.Rally?.environment?
#      @scopeDataSet = false
#      setTimeout(@monitorScopeDropdown, 3000, this)
#    else  # else if we're in development, put some dummy data in here and say that we're set.
#      @scopeDataSet = true

    # else if the scope information is set in the config object run with that
    # else display a message that this was designed to run on an iteration scoped dashboards or have the scope set manually

    if @config.granularity?
      @config.lumenizeCalculatorConfig.granularity = @config.granularity
    else
      @config.lumenizeCalculatorConfig.granularity = lumenize.Time.DAY
    @config.lumenizeCalculatorConfig.workDayStartOn = @config.workDayStartOn
    @config.lumenizeCalculatorConfig.workDayEndBefore = @config.workDayEndBefore
    @config.lumenizeCalculatorConfig.holidays = @config.holidays
    @config.lumenizeCalculatorConfig.workDays = @config.workDays
    @config.lumenizeCalculatorConfig.startOn = new Time(@config.scopeData.StartDate, Time.MILLISECOND, @config.lumenizeCalculatorConfig.tz)
      .getISOStringInTZ('GMT')
    @config.lumenizeCalculatorConfig.endBefore = new Time(@config.scopeData.EndDate, Time.MILLISECOND, @config.lumenizeCalculatorConfig.tz)
      .addInPlace(1, @config.lumenizeCalculatorConfig.granularity)  # !TODO: This might not be sufficient. I might need to move along the timeline.
      .getISOStringInTZ('GMT')

    allowedValues = (cs.name for cs in @config.chartSeries)

#    @config.lumenizeCalculatorConfig.metrics = [
#      {f: 'groupByCount', groupByField: @config.kanbanStateField, allowedValues: allowedValues}
#    ]

    @config.lumenizeCalculatorConfig.metrics = [
      {f: 'groupBySum', field: 'PlanEstimate', groupByField: @config.kanbanStateField, allowedValues: allowedValues}
    ]

    @LumenizeCalculatorClass = lumenize.TimeSeriesCalculator

  onNewDataAvailable: () =>

    if @config.trace
      console.log('in CFDVisualizer.onNewDataAvailable')
    queryConfig = {
      'X-RallyIntegrationName': 'Burn Chart (prototype)',
      'X-RallyIntegrationVendor': 'Rally Red Pill',
      'X-RallyIntegrationVersion': '0.2.0',
      workspaceOID: @projectAndWorkspaceScope.workspaceOID
    }
    unless @upToDateISOString?
      @upToDateISOString = '2011-12-01T00:00:00.000Z'  # The first full month of the Lookback API

    @analyticsQuery = new GuidedAnalyticsQuery(queryConfig, @upToDateISOString)

    if @config.scopeValue is 'scope'
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
    else if @config.scopeData.ObjectID?
      scopeValue = @config.scopeData.ObjectID
      @analyticsQuery.scope(@config.scopeField, scopeValue)
    else
      scopeValue = @config.scopeValue
      @analyticsQuery.scope(@config.scopeField, scopeValue)

    fields = ["ObjectID", "_ValidFrom", "_ValidTo", "PlanEstimate"]
    fields.push(@config.kanbanStateField)
    @analyticsQuery
      .type(['HierarchicalRequirement','Defect','TestCase','DefectSuite'])
      .leafOnly()
      .fields(fields)
      .hydrate([@config.kanbanStateField])
#      .pagesize(100)  # For debugging incremental update

    if @config.asOf?
      @analyticsQuery.additionalCriteria({_ValidFrom:{$lt:@getAsOfISOString()}})

    if @config.debug
      @analyticsQuery.debug()
      console.log('Requesting data...')

    @fetchPending = true

    @analyticsQuery.getPage(@onSnapshotsReceieved)

  getHashForCache: () ->
    if @config.trace
      console.log('in CFDVisualizer.getHashForCache')
    hashObject = {}
    userConfig = utils.clone(@userConfig)
    delete userConfig.debug
    delete userConfig.trace
    hashObject.userConfig = userConfig
    hashObject.projectAndWorkspaceScope = @projectAndWorkspaceScope
    hashObject.workspaceConfiguration = @workspaceConfiguration
    salt = 'CFD v0.2.11'
    salt = Math.random().toString()
    hashString = JSON.stringify(hashObject)
    out = md5(hashString + salt)
    return out

  updateVisualizationData: () ->
    # override
    # Transform the data into whatever form your visualization expects from the data in the @lumenizeCalculator
    # Store your calculations into @visualizationData, which will be sent to the visualization create and update callbacks.
    # Try to fully populate the x-axis based upon today even if you have no data for later dates yet.
    if @config.trace
      console.log('in CFDVisualizer.updateVisualizationData')

    calculatorResults = @lumenizeCalculator.getResults()

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

    seriesData = calculatorResults.seriesData

    series = lumenize.arrayOfMaps_To_HighChartsSeries(seriesData, @config.chartSeries)
    for s in series
      if s.displayName?
        s.name = s.displayName

    categories = (row.label for row in seriesData)

    lowestValueInLastState = lumenize.functions.min(series[series.length-1].data)

    @visualizationData = {series, categories, lowestValueInLastState}

  updateVisualization: () ->
    # most likely override. The default here is to just recreate it again but you should try to update the HighCharts
    # Objects in @visualizations.
    @updateVisualizationData()

    @visualizations.lowestValueInLastState = @visualizationData.lowestValueInLastState
    chart = @visualizations.chart
    chart.yAxis[0].setExtremes(@visualizationData.lowestValueInLastState)
    series = chart.series
    for s, index in @visualizationData.series
      series[index].setData(s.data, false)
    chart.xAxis[0].setCategories(@visualizationData.categories, false)
    chart.redraw()
  
this.CFDVisualizer = CFDVisualizer
  