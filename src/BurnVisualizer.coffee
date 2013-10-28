if exports?
  lumenize = require('../lib/lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{utils, Time} = lumenize

class BurnVisualizer extends VisualizerBase
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
      console.log('in BurnVisualizer.initialize')
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


#    @config.lumenizeCalculatorConfig.deriveFieldsOnInput = [
#      {field: 'AcceptedStoryCount', f: (row) ->
#        if row.ScheduleState in ['Accepted', 'Released']
#          return 1
#        else
#          return 0
#      },
#      {field: 'AcceptedStoryPoints', f: (row) ->
#        if row.ScheduleState in ['Accepted', 'Released']  # !TODO: Need to use correct value for "Released" for their Workspace
#          return row.PlanEstimate
#        else
#          return 0
#      }
#    ]

    @config.acceptedStates = ['Accepted', 'Released']  # !TODO: Push this into the HTML

    @config.lumenizeCalculatorConfig.metrics = [
      {as: 'StoryCountBurnUp', f: 'filteredCount', filterField: 'ScheduleState', filterValues: @config.acceptedStates},
      {as: 'StoryUnitBurnUp', field: 'PlanEstimate', f: 'filteredSum', filterField: 'ScheduleState', filterValues: @config.acceptedStates},
      {as: 'StoryUnitScope', field: 'PlanEstimate', f: 'sum'},
      {as: 'StoryCountScope', f: 'count'},
#      {as: 'StoryCountBurnUp', field: 'AcceptedStoryCount', f: 'sum'},
#      {as: 'StoryUnitBurnUp', field: 'AcceptedStoryPoints', f: 'sum'},
      {as: 'TaskUnitBurnDown', field: 'TaskRemainingTotal', f: 'sum'},
      {as: 'TaskUnitScope', field: 'TaskEstimateTotal', f: 'sum'}  # Note, we don't have the task count denormalized in stories so we can't have TaskCountScope nor TaskUnitBurnDown
    ]

    @config.lumenizeCalculatorConfig.summaryMetricsConfig = [
      {field: 'TaskUnitScope', f: 'max'},
      {field: 'TaskUnitBurnDown', f: 'max'},
      {field: 'StoryUnitScope', f: 'max'},
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
      },
      {as: 'StoryUnitBurnDown', f: (row, index, summaryMetrics, seriesData) ->
        return row.StoryUnitScope - row.StoryUnitBurnUp
      },
# This version of the ideal line starts the StoryUnitScope_max
#      {as: 'StoryUnitIdeal', f: (row, index, summaryMetrics, seriesData) ->
#        max = summaryMetrics.StoryUnitScope_max
#        increments = seriesData.length - 1
#        incrementAmount = max / increments
#        return Math.floor(100 * (max - (index * incrementAmount))) / 100
#      }

# This version of the ideal line starts the first point on the StoryUnitBurnDown series
      {as: 'StoryUnitIdeal', f: (row, index, summaryMetrics, seriesData) ->
        max = seriesData[0].StoryUnitBurnDown
        increments = seriesData.length - 1
        incrementAmount = max / increments
        return Math.floor(100 * (max - (index * incrementAmount))) / 100
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

    if @config.scopeData.ObjectID?
      scopeValue = @config.scopeData.ObjectID
    else
      scopeValue = @config.scopeValue
    @analyticsQuery.scope(@config.scopeField, scopeValue)

    fields = ["ObjectID", "_ValidFrom", "_ValidTo", "ScheduleState", "PlanEstimate", "TaskRemainingTotal", "TaskEstimateTotal"]
    @analyticsQuery
      .type(['HierarchicalRequirement','Defect','TestCase','DefectSuite'])
      .leafOnly()
      .fields(fields)
      .hydrate(['ScheduleState'])
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
      console.log('in BurnVisualizer.getHashForCache')
    hashObject = {}
    userConfig = utils.clone(@userConfig)
    delete userConfig.debug
    delete userConfig.trace
    hashObject.userConfig = userConfig
    hashObject.projectAndWorkspaceScope = @projectAndWorkspaceScope
    hashObject.workspaceConfiguration = @workspaceConfiguration
    salt = 'Burn v0.2.11'
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

    seriesData = calculatorResults.seriesData

    series = lumenize.arrayOfMaps_To_HighChartsSeries(seriesData, @config.chartSeries)
    for s in series
      if s.displayName?
        s.name = s.displayName

    categories = (row.label for row in seriesData)

    @visualizationData = {series, categories}

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
  
this.BurnVisualizer = BurnVisualizer
  