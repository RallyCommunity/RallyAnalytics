# rallycharttime
# ==============
#
# Copyright (c), 2012 Rally Software
# 
# The purpose of this project is to demonstrate how you would use ChartTime with Rally Software's APIs to 
# calculate metrics with precision and render useful charts.

charttime = require('../../charttime')
{ChartTime, ChartTimeIterator, ChartTimeRange} = charttime
{clone} = charttime.utils

ChartTime.setTZPath("../../charttime/vendor/tz")

# Let's say you have this data. I've put it in this CSV-style format for easy entry and comprehension.
resultsCSVStyle = [
    ["ObjectID", "_ValidFrom",           "KanbanState"  , "PlanEstimate", "TaskRemainingTotal"],
                                                        
    [1,          "2010-10-10T15:00:00Z", "Ready to pull", 5            , 15                   ],  # Shouldn't show up, 2010 not yet "In progress"

    [1,          "2011-01-02T13:00:00Z", "Ready to pull", 5            , 15                   ],  # !TODO: Should get the same results even without this line
    [1,          "2011-01-02T15:10:00Z", "In progress"  , 5            , 20                   ],  # Testing it starting at one state and switching later to another
    [2,          "2011-01-02T15:00:00Z", "Ready to pull", 3            , 5                    ],                
    [3,          "2011-01-02T15:00:00Z", "Ready to pull", 5            , 12                   ], 

    [2,          "2011-01-03T15:00:00Z", "In progress"  , 3            , 5                    ], 
    [3,          "2011-01-03T15:00:00Z", "Ready to pull", 5            , 12                   ], 
    [4,          "2011-01-03T15:00:00Z", "Ready to pull", 5            , 15                   ], 
    [1,          "2011-01-03T15:10:00Z", "In progress"  , 5            , 12                   ],  # Testing later change

    [1,          "2011-01-04T15:00:00Z", "Accepted"     , 5            , 0                    ], 
    [2,          "2011-01-04T15:00:00Z", "In test"      , 3            , 1                    ], 
    [3,          "2011-01-04T15:00:00Z", "In progress"  , 5            , 10                   ], 
    [4,          "2011-01-04T15:00:00Z", "Ready to pull", 5            , 15                   ], 
    [5,          "2011-01-04T15:00:00Z", "Ready to pull", 2            , 4                    ], 

    [3,          "2011-01-05T15:00:00Z", "In test"      , 5            , 5                    ],

    [1,          "2011-01-06T15:00:00Z", "Released"     , 5            , 0                    ], 
    [2,          "2011-01-06T15:00:00Z", "Accepted"     , 3            , 0                    ], 
    [4,          "2011-01-06T15:00:00Z", "In progress"  , 5            , 7                    ], 
    [5,          "2011-01-06T15:00:00Z", "Ready to pull", 2            , 4                    ], 

    [1,          "2011-01-07T15:00:00Z", "Released"     , 5            , 0                    ], 
    [2,          "2011-01-07T15:00:00Z", "Released"     , 3            , 0                    ], 
    [3,          "2011-01-07T15:00:00Z", "Accepted"     , 5            , 0                    ], 
    [4,          "2011-01-07T15:00:00Z", "In test"      , 5            , 3                    ], 
    [5,          "2011-01-07T15:00:00Z", "In progress"  , 2            , 4                    ]
]

# The CSV-style table is not what it would look like from the Rally API so let's fix that.
results = charttime.csvStyleArray_To_ArrayOfMaps(resultsCSVStyle)
# It now looks something like what we'd see from the Rally API...
#
#     results = [
#       {ObjectID: 1, _ValidFrom: "2010-01-01T15:00:00Z", KanbanState: "Ready to pull"},
#       {ObjectID: 1, _ValidFrom: "2011-01-01T15:10:00Z", KanbanState: "In progress"},
#       ...
#     ]
#
# The response from a Rally Analytics API query would be embedded in a top level JSON wrapper with a `Results` Array, but let's
# just proceed as if we've pulled it out of there into a local `results` variable.

# Everything above this point was just to simulate a response from a Rally Analytics API query. Now, let's show you what to do with it.
# Let's assume we have a UI that lets us configure the CFD chart. This UI puts its settings in a config Object like this...
#
# Note, the timezone and workDays values could come directly from Rally's WorkspaceConfiguration.
# !TODO: Add request to typeDef endpoint (or the Kanban preferences for this project) to get the list and order for config.stateFieldValues.
config =
  stateField: "KanbanState"
  stateFieldValues: ['Ready to pull', 'In progress', 'Accepted', 'Released'] # 'In test' intentionally missing
  useAllStateFieldValues: false
  startTrackingState: "In progress"
  aggregationField: "PlanEstimate"
  aggregationFunction: "$sum"
  workDays: 'Sunday, Monday, Tuesday, Wednesday, Thursday, Friday' # They work on Sundays
  timezone: 'America/New_York'
  holidays: [
    {month: 12, day: 25},
    {year: 2011, month: 11, day: 26},
    {year: 2011, month: 1, day: 5}  # Made up holiday to demo holiday knockout
  ]

# We're going to assume the data is sorted by _ValidFrom but if it wasn't, we shold do that now.
# Next, we're going to find the first record where something moves into the `startTrackingState`.
firstTrackingDate = ''
for row, i in results
  if row[config.stateField] == config.startTrackingState
    firstTrackingDate = row._ValidFrom
    break
if firstTrackingDate == ''
  throw new Error("Couldn't find any data whose #{stateField} transititioned into state #{startTrackingState}")

# and the last day for this CFD
lastTrackingDate = results[results.length - 1]._ValidFrom

# Now is where it starts to get a bit tricky. We're now going to identify the values for the x-axis of our CFD.
# We're going to first create a ChartTimeRange that will emit an iterator of sub-ranges for each day that we are interested
# in.
#
# We now have a ChartTimeRange with the appropriate start and pastEnd values.
# Notice how we passed in the timezone of interest when creating the start and pastEnd ChartTimes.
# The firstTrackingDate and lastTrackingDate are strings in GMT. 2am GMT on January 2nd is actually on January 1st
# in New York. Since, we want the analysis to be in New York's perspective even if we are rendering
# this chart from a computer in Denver, LA, or Bangalore, we need to tell ChartTime the timezone context 
# for any GMT date/time stamps.
rangeSpec =
  workDays: config.workDays
  holidays: config.holidays
  start: new ChartTime(firstTrackingDate, 'day', config.timezone)
  pastEnd: new ChartTime(lastTrackingDate, 'day', config.timezone).add(1)
range = new ChartTimeRange(rangeSpec)

# Now let's use ChartTime's ability to iterate over a range to find the sub ranges, one for each day
# Let's take a look at what's in subRanges at this point.
# This code will print out...
#
#     [ '2011-01-02 to 2011-01-03',
#       '2011-01-03 to 2011-01-04',
#       '2011-01-04 to 2011-01-06',
#       '2011-01-06 to 2011-01-07',
#       '2011-01-07 to 2011-01-08' ]
#
# Q: What happened to 2011-01-05?
#
# >A: Well, it was a holiday.
#
# Q: Why did the sub range that would have included 2011-01-05 expand to two days?
#
# >A: ChartTimeRanges work hard to make sure there are never any gaps.
# In theory, there _shouldn't_ be any real work on that day.
# So, you don't want days on your chart where your metric trends flatline.
# But what if someone did a little work on a holiday or a weekend. You wouldn't want to 
# miss those events. In this example, someone moved ObjectID #3 into "In test" on our January 5 holiday.
# That event is counted for the 2011-01-04 to 2011-01-06 period.
subRanges = range.getIterator('ChartTimeRange').getAll()
subRangeStrings = ("#{r.start.toString()} to #{r.pastEnd.toString()}" for r in subRanges)
console.log(subRangeStrings)

# The pastEnd values are the ones we are most interested in so let's take a look at those.
# Note, these represent the moments just past the end of the days where the activity happens. So, if there is 
# activity on 2011-01-02, we'll want to look at the value at midnight at the end of that day, which is
# 2011-01-03T00:00:00.000 or 2011-01-03 for short.
#
#     [ '2011-01-03', '2011-01-04', '2011-01-06', '2011-01-07', '2011-01-08' ]
#
# These are the points we want on our x-axis. 
pastEnds = (r.pastEnd for r in subRanges)
console.log(("#{r.toString()}" for r in pastEnds))

# Now we need to know the state of each work item **AT** each of these points.
# The ChartTime `snapshotArray_To_AtArray` helper function will give us what we need:
#
#     [ [ {ObjectID: 1,  KanbanState: 'In progress', PlanEstimate: 5, TaskRemainingTotal: 20 },
#         {ObjectID: 2,  KanbanState: 'Ready to pull', PlanEstimate: 3, TaskRemainingTotal: 5 },
#         {ObjectID: 3,  KanbanState: 'Ready to pull', PlanEstimate: 5, TaskRemainingTotal: 12 } ],
#       [ {ObjectID: 1,  KanbanState: 'In progress', PlanEstimate: 5, TaskRemainingTotal: 12 },
#         {ObjectID: 2,  KanbanState: 'In progress', PlanEstimate: 3, TaskRemainingTotal: 5 },
#         {ObjectID: 3,  KanbanState: 'Ready to pull', PlanEstimate: 5, TaskRemainingTotal: 12 },
#         {ObjectID: 4,  KanbanState: 'Ready to pull', PlanEstimate: 5, TaskRemainingTotal: 15 } ],
#       [ {ObjectID: 1,  KanbanState: 'Accepted', PlanEstimate: 5, TaskRemainingTotal: 0 },
#         {ObjectID: 2,  KanbanState: 'In test', PlanEstimate: 3, TaskRemainingTotal: 1 },
#         {ObjectID: 3,  KanbanState: 'In test', PlanEstimate: 5, TaskRemainingTotal: 5 },
#         {ObjectID: 4,  KanbanState: 'Ready to pull', PlanEstimate: 5, TaskRemainingTotal: 15 },
#         {ObjectID: 5,  KanbanState: 'Ready to pull', PlanEstimate: 2, TaskRemainingTotal: 4 } ],
#       [ {ObjectID: 1,  KanbanState: 'Released', PlanEstimate: 5, TaskRemainingTotal: 0 },
#         {ObjectID: 2,  KanbanState: 'Accepted', PlanEstimate: 3, TaskRemainingTotal: 0 },
#         {ObjectID: 3,  KanbanState: 'In test', PlanEstimate: 5, TaskRemainingTotal: 5 },
#         {ObjectID: 4,  KanbanState: 'In progress', PlanEstimate: 5, TaskRemainingTotal: 7 },
#         {ObjectID: 5,  KanbanState: 'Ready to pull', PlanEstimate: 2, TaskRemainingTotal: 4 } ],
#       [ {ObjectID: 1,  KanbanState: 'Released', PlanEstimate: 5, TaskRemainingTotal: 0 },
#         {ObjectID: 2,  KanbanState: 'Released', PlanEstimate: 3, TaskRemainingTotal: 0 },
#         {ObjectID: 3,  KanbanState: 'Accepted', PlanEstimate: 5, TaskRemainingTotal: 0 },
#         {ObjectID: 4,  KanbanState: 'In test', PlanEstimate: 5, TaskRemainingTotal: 3 },
#         {ObjectID: 5,  KanbanState: 'In progress', PlanEstimate: 2, TaskRemainingTotal: 4 } ] ]
atArray = charttime.snapshotArray_To_AtArray(results, pastEnds, '_ValidFrom', 'ObjectID', config.timezone)
# console.log('atArray = ', atArray)

# Next, we need to aggregate the sums and counts in each KanbanState for each day. CharTime includes
# some tools to help us with this as well. You need to provide a specification for the aggregation.
# The first element of this specification is the `groupBy` field. This is analagous to
# the `GROUP BY` column in an SQL express.
#
# Then you need to say what aggregations you want. For each aggregation, you must provide a `field` and `f`
# (function) value. You can optionally provide an alias for the aggregation with the 'as` field. There
# are a number of built in functions including:
#
# * $count
# * $sum
# * $sumSquares
# * $average
# * $variance
# * $stdDev
# * $min
# * $max
# * $push. An Array of all values (allows duplicates). This is ideal for drill down.
# * $addToSet. An Array of unique values. This is good for generating an OLAP dimension.
# * $p<n> <n>th percentile where <n> is some number in the form of ##[.##]. (e.g. $p40, $p99, $p99.9)
# * $median. alias for $p50
#
# Alternatively, you can provide your own function (it takes one parameter, which is an
# Array of values) like the `mySum` example here.
#
# Below are examples are alternative example `aggregations` specs:
#
#     {field: 'ObjectID', f: '$count'}  
#
#     {as: 'mySum', field: 'PlanEstimate', f: (values) ->
#       temp = 0
#       for v in values
#         temp += v
#       return temp
#     }
spec =
  groupBy: config.stateField
  uniqueValues: clone(config.stateFieldValues)
  aggregations: [
    {as: 'CFDField', field: config.aggregationField, f: config.aggregationFunction}
    {as: 'Drill-down', field:'ObjectID', f:'$push'}
  ]
  
aggregationArray = charttime.groupByAt(atArray, spec)  

# At this point the first row of our `allSeries` array looks like this:
#
#     [ { 'CFDField': 8, KanbanState: 'Ready to pull' },
#       { 'CFDField': 5, KanbanState: 'In progress' },
#       { 'CFDField': 0, KanbanState: 'Accepted' },
#       { 'CFDField': 0, KanbanState: 'Released' },
#       { 'CFDField': 0, KanbanState: 'In test' } ]
#
# Notice how the order that we specified in spec.uniqueValues was honored.
# Also, notice that we neglected to specify 'In test' in our spec.uniqueValues but it didn't get lost. 
# 'In test' is tacked onto the end of every row in the allSeries Array. This way, you get the best of
# both worlds. The ability to specify order but no risk of missing anything.
# Even if you had not specified anything in spec.uniqueValues, the order of all rows in
# allSeries would be exactly (albeit random) the same and cover all possible values.
console.log(aggregationArray[0])

# Note: groupByAt has the side-effect that spec.uniqueValues are upgraded with the missing values.
# "In test" was mising from the original config. You can use this if you want to calculate other 
# metrics for each of the groupBy values or just to confirm that you aren't missing some data.
# 
#     WARNING: Data found for values that are not in config.stateFieldValues. Data found for values:
#         In test
if config.stateFieldValues? and config.stateFieldValues.length < spec.uniqueValues.length
  console.log('\nWARNING: Data found for values that are not in config.stateFieldValues. Data found for values:')
  for v in spec.uniqueValues
    unless v in config.stateFieldValues
      console.log('    ' + v)

# for HighCharts, we need to get it into this form
#
#     [ { name: 'Ready to pull', data: [ 8, 10, 7, 2, 0 ] },
#       { name: 'In progress', data: [ 5, 8, 0, 5, 2 ] },
#       { name: 'Accepted', data: [ 0, 0, 5, 3, 5 ] },
#       { name: 'Released', data: [ 0, 0, 0, 5, 8 ] } ]
if config.useAllStateFieldValues
  cfdSeries = charttime.aggregationArray_To_HighChartsSeries(aggregationArray, config.stateField, 'CFDField')
else
  cfdSeries = charttime.aggregationArray_To_HighChartsSeries(aggregationArray, config.stateField, 'CFDField', config.stateFieldValues)  
console.log(cfdSeries)


