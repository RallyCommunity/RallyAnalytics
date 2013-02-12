root = this

lumenize = require('/lumenize')

{timeSeriesGroupByCalculator, Time} = lumenize
utils = lumenize.utils

cfdCalculator = (results, config) ->
  ###
  Takes the "results" from a query to Rally's Analytics API (or similar MVCC-based implementation)
  and returns the data points for a cumulative flow diagram (CFD). 
  ###
  
  # Find the last day for this CFD
  
  lastTrackingDate = results[results.length - 1]._ValidFrom
  lastTrackingCT = new Time(lastTrackingDate, 'day', config.timezone).add(1)
  
  # Find the first record where something moves into the `startTrackingGroupByFieldValue`.
  firstTrackingDate = ''  # !TODO: Upgrade this to match timeSeriesCalculator
  for row, i in results
    if row[config.groupByField] == config.startTrackingGroupByFieldValue
      firstTrackingDate = row._ValidFrom
      break
  if firstTrackingDate == ''
    throw new Error("Couldn't find any data whose #{config.groupByField} transitioned into groupByFieldValue #{config.startTrackingGroupByFieldValue}")
    
  firstTrackingCT = new Time(firstTrackingDate, 'day', config.timezone)
  
  if config.maxDaysBack?
    maxDaysBackCT = lastTrackingCT.add(-1 * config.maxDaysBack, 'day')
    if firstTrackingCT.lessThan(maxDaysBackCT)
      firstTrackingCT = maxDaysBackCT
    
  timelineConfig =
    workDays: config.workDays
    holidays: config.holidays
    startOn: firstTrackingCT
    endBefore: lastTrackingCT
  
  console.log('timelineConfig:\n' + JSON.stringify(timelineConfig, undefined, 4))
    
  timeSeriesGroupByCalculatorConfig = 
    timelineConfig: timelineConfig
    timezone: config.timezone
    groupByField: config.groupByField
    groupByFieldValues: config.groupByFieldValues
    useAllGroupByFieldValues: config.useAllGroupByFieldValues
    aggregationField: config.aggregationField
    aggregationFunction: config.aggregationFunction
    snapshotValidFromField: '_ValidFrom'
    snapshotValidToField: '_ValidTo'
    snapshotUniqueID: 'ObjectID'

  console.log('before call to timeSeriesGroupByCalculator')
  {listOfAtCTs, groupByAtArray, uniqueValues} = timeSeriesGroupByCalculator(results, timeSeriesGroupByCalculatorConfig)
  console.log('after call to timeSeriesGroupByCalculator')

  # Get it into HighCharts form
  if config.useAllGroupByFieldValues
    series = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'GroupBy')
    drillDownObjectIDs = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'DrillDown', uniqueValues, true)
  else
    series = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'GroupBy', config.groupByFieldValues)
    drillDownObjectIDs = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'DrillDown', config.groupByFieldValues, true)
    
  # HighCharts needs a categories Array for the x-axis so...
  categories = ("#{ct.toString()}" for ct in listOfAtCTs)  # !TODO: Should be smarter about skipping some when we have more than will fit on the x-axis

  # find the min for the last state
  lowestValueInLastState = null
  unless config.useAllGroupByFieldValues
    lowestValueInLastState = lumenize.functions.min(series[series.length-1].data)

  return {series, categories, drillDownObjectIDs, lowestValueInLastState}
  
root.cfdCalculator = cfdCalculator