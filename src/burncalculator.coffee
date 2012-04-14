root = this

if exports?
  lumenize = require('../lib/lumenize')  # in node.js
else
  lumenize = require('/lumenize')  # in the browser

{ChartTime, timeSeriesCalculator} = lumenize
utils = lumenize.utils

burnCalculator = (results, config) ->
  ###
  Takes the "results" from a query to Rally's Analytics API (or similar MVCC-based implementation)
  and returns the series for burn charts. 
  ###
  if config.granularity?  # !TODO: Test granularities other than 'day'
    granularity = config.granularity
  else
    granularity = 'day'
    
  start = config.start
  if utils.type(start) == 'string'
    start = new ChartTime(start, granularity, config.workspaceConfiguration.TimeZone)
  
  pastEnd = new ChartTime(results[results.length - 1]._ValidFrom, granularity, config.workspaceConfiguration.TimeZone).add(1)
  
  rangeSpec =
    workDays: config.workspaceConfiguration.WorkDays
    holidays: config.holidays
    start: start  # !TODO: Upgrade this to support all of ChartTimeIterator's flexibility
    pastEnd: pastEnd
    
  unless config.upSeriesType?
    config.upSeriesType = 'Sums'
    
  derivedFields = []
  if config.upSeriesType == 'Points'
    derivedFields.push({name: 'Accepted', f: (row) ->
      if row.ScheduleState in config.acceptedStates
        return row.PlanEstimate
      else
        return 0
    })
  else if config.upSeriesType == 'Story Count'
    derivedFields.push({name: 'Accepted', f: (row) ->
      if row.ScheduleState in config.acceptedStates
        return 1
      else
        return 0
    })
  else
    console.error("Unrecognized upSeriesType: #{config.upSeriesType}")
  
  seriesNames = []
  aggregations = []
  for s in config.series
    seriesFound = true
    switch s
      when 'down'
        name = 'Task To Do (Hours)'
        f = '$sum'
        field = 'TaskRemainingTotal'
        yAxis = 0
        type = 'column'
      when 'ideal'
        name = "Ideal (Hours)"
        f = '$sum'
        field = 'TaskEstimateTotal'
        yAxis = 0
        type = 'line'
      when 'up'
        name = "Accepted (#{config.upSeriesType})"
        f = '$sum'
        field = 'Accepted'
        yAxis = 1
        type = 'column'
      when 'scope'
        name = "Scope (#{config.upSeriesType})"
        if config.upSeriesType == 'Story Count'
          f = '$count'
        else if config.upSeriesType == 'Points'
          f = '$sum'
        field = 'PlanEstimate'
        yAxis = 1
        type = 'line'
      else
        if s.name? and s.f? and s.field?
          name = s.name
          f = s.f
          field = s.field
          type = 'column'
        else
          seriesFound = false
          console.error("Unrecognizable series: #{s}")
    if seriesFound  
      aggregations.push({name: name, as: name, f: f, field: field, yAxis: yAxis, type: type})
      seriesNames.push(name)
  
  timeSeriesCalculatorConfig = 
    rangeSpec: rangeSpec
    derivedFields: derivedFields 
    aggregations: aggregations
    timezone: config.workspaceConfiguration.TimeZone
    snapshotValidFromField: '_ValidFrom'
    snapshotUniqueID: 'ObjectID'
  
  # See https://github.com/lmaccherone/Lumenize for information about Lumenize
  {listOfAtCTs, aggregationAtArray} = lumenize.timeSeriesCalculator(results, timeSeriesCalculatorConfig)

  series = lumenize.aggregationAtArray_To_HighChartsSeries(aggregationAtArray, aggregations)
  categories = ("#{ct.toString()}" for ct in listOfAtCTs)  # !TODO: Should be smarter about skipping some when we have more than will fit on the x-axis
  originalPointCount = categories.length
  
  # Create the ideal line
  i = 0
  while series[i].name.indexOf("Ideal") < 0
    i++
  idealData = series[i].data
  maxTaskEstimateTotal = lumenize.functions.$max(idealData)
  idealStep = maxTaskEstimateTotal / (originalPointCount - 1)
  for i in [0..originalPointCount - 2]
    idealData[i] = (originalPointCount - 1 - i) * idealStep
  idealData[originalPointCount - 1] = 0
  
  # Experiment
#   categories.push('projection')
#   categories.push('testing2')
#   series[1].data.push(null)  # It won't show 'testing1' on the x-axis unless there is data for it. null counts but won't plot. zero will plot as zero.
      
  return {categories, series}
  
root.burnCalculator = burnCalculator