if exports?
  lumenize = require('../lib/lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{utils} = lumenize

class BurnVisualizer extends VisualizerBase
  ###
  ###

  initialize: () ->
    if @config.trace
      console.log('in BurnVisualizer.initialize')
    super()

    if @config.granularity?
      @config.lumenizeCalculatorConfig.granularity = @config.granularity
    else
      @config.lumenizeCalculatorConfig.granularity = lumenize.Time.DAY
    @config.lumenizeCalculatorConfig.workDayStartOn = @config.workDayStartOn
    @config.lumenizeCalculatorConfig.workDayEndBefore = @config.workDayEndBefore
    @config.lumenizeCalculatorConfig.holidays = @config.holidays
    @config.lumenizeCalculatorConfig.workDays = @config.workDays

    @config.lumenizeCalculatorConfig.deriveFieldsOnInput = [
      {field: 'AcceptedStoryCount', f: (row) ->
        if row.ScheduleState in ['Accepted', 'Released']
          return 1
        else
          return 0
      },
      {field: 'AcceptedStoryPoints', f: (row) ->
        if row.ScheduleState in ['Accepted', 'Released']
          return row.PlanEstimate
        else
          return 0
      }
    ]

    @config.lumenizeCalculatorConfig.metrics = [
      {as: 'StoryUnitScope', field: 'PlanEstimate', f: 'sum'},
      {as: 'StoryCountScope', f: 'count'},
      {as: 'StoryCountBurnUp', field: 'AcceptedStoryCount', f: 'sum'},
      {as: 'StoryUnitBurnUp', field: 'AcceptedStoryPoints', f: 'sum'},
      {as: 'TaskUnitBurnDown', field: 'TaskRemainingTotal', f: 'sum'},
      {as: 'TaskUnitScope', field: 'TaskEstimateTotal', f: 'sum'}  # Note, we don't have the task count denormalized in stories so we can't have TaskCountScope nor TaskUnitBurnDown
    ]

    @config.lumenizeCalculatorConfig.summaryMetricsConfig = [
      {field: 'TaskUnitScope', f: 'max'},
      {field: 'TaskUnitBurnDown', f: 'max'},
      {as: 'TaskUnitBurnDown_max_index', f: (seriesData, summaryMetrics) ->
        for row, index in seriesData
          if row.TaskUnitBurnDown is summaryMetrics.TaskUnitBurnDown_max
            return index
      }
    ]

    @config.lumenizeCalculatorConfig.deriveFieldsAfterSummary = [
      {as: 'Ideal', f: (row, index, summaryMetrics, seriesData) ->
        max = summaryMetrics.TaskUnitScope_max
        increments = seriesData.length - 1
        incrementAmount = max / increments
        return Math.floor(100 * (max - index * incrementAmount)) / 100
      },
      {as: 'Ideal2', f: (row, index, summaryMetrics, seriesData) ->
        if index < summaryMetrics.TaskUnitBurnDown_max_index
          return null
        else
          max = summaryMetrics.TaskUnitBurnDown_max
          increments = seriesData.length - 1 - summaryMetrics.TaskUnitBurnDown_max_index
          incrementAmount = max / increments
          return Math.floor(100 * (max - (index - summaryMetrics.TaskUnitBurnDown_max_index) * incrementAmount)) / 100
      }
    ]

    @LumenizeCalculatorClass = lumenize.TimeSeriesCalculator

  onNewDataAvailable: () =>
    if @config.trace
      console.log('in BurnVisualizer.onNewDataAvailable')
    queryConfig = {
      'X-RallyIntegrationName': 'Burn Chart (prototype)',
      'X-RallyIntegrationVendor': 'Rally Red Pill',
      'X-RallyIntegrationVersion': '0.2.0',
      workspaceOID: @projectAndWorkspaceScope.workspaceOID
    }
    unless @upToDateISOString?
      @upToDateISOString = '2011-12-01T00:00:00.000Z'  # The first full month of the Lookback API

    @analyticsQuery = new GuidedAnalyticsQuery(queryConfig, @upToDateISOString)

    @analyticsQuery.scope(@config.scopeField, @config.scopeValue)

    fields = ["ObjectID", "_ValidFrom", "_ValidTo", "ScheduleState", "PlanEstimate", "TaskRemainingTotal", "TaskEstimateTotal"]
    @analyticsQuery
      .type('HierarchicalRequirement')
      .leafOnly()
      .fields(fields)
      .hydrate(['ScheduleState'])
#      .pagesize(3000)  # For debugging incremental update

    if @config.asOf?
      @analyticsQuery.additionalCriteria({_ValidFrom:{$lt:@getAsOfISOString()}})

    if @config.debug
      @analyticsQuery.debug()
      console.log('Requesting data...')

    @fetchPending = true

    @analyticsQuery.getPage(@onSnapshotsReceieved)

  getHashForCache: () ->
    if @config.trace
      console.log('in BurnVisualizer.getHashForCache')
    hashObject = {}
    userConfig = utils.clone(@userConfig)
    delete userConfig.debug
    delete userConfig.trace
    hashObject.userConfig = userConfig
    hashObject.projectAndWorkspaceScope = @projectAndWorkspaceScope
    hashObject.workspaceConfiguration = @workspaceConfiguration
    salt = 'Burn v0.2.0'
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
      console.log('in BurnVisualizer.updateVisualizationData')

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

    console.log(calculatorResults)

    series = lumenize.aggregationAtArray_To_HighChartsSeries(calculatorResults.seriesData, @config.chartSeries)
    categories = (row.tick for row in calculatorResults.seriesData)
    console.log(categories)

    console.log(series)

    @visualizationData = {series, categories}

    # For almost all other charts, we'll be able to simply update the data but this TIP chart controls the tickInterval
    # which cannot be updated at run time according to HighCharts support so we have to recreate it each time.

  
this.BurnVisualizer = BurnVisualizer
  