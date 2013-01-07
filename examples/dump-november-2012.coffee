{AnalyticsQuery} = require('../')
fs = require('fs')

config =
  'X-RallyIntegrationName': 'Data Dumper'
  'X-RallyIntegrationVendor': 'Rally'
  'X-RallyIntegrationVersion': '0.1.0'
  # If not provided in this config object, it will get workspaceOID, username, and password from 
  # environment variables RALLY_WORKSPACE, RALLY_USER, and RALLY_PASSWORD

query = new AnalyticsQuery(config)

query.find({_ValidFrom:{$gte: '2012-11-01TZ', $lt:'2012-12-01TZ'}})
    .fields([
      "_id",
      "_SnapshotNumber",
      "_SnapshotDate",
      "ObjectID",
      "_ValidFrom",
      "_ValidTo",
      "Project",
      "_Revision",
      "_RevisionNumber",
      "_UnformattedID",
      "_TypeHierarchy",
      "_ItemHierarchy",
      "_ProjectHierarchy",
      "Blocked",
      "PlanEstimate",
      "TaskEstimateTotal",
      "TaskActualTotal",
      "TaskRemainingTotal",
      "ScheduleState",
      "CreationDate",
      "Owner",
      "User",
      "Predecessors",
      "Successors",
      "_PreviousValues._id",
      "_PreviousValues._SnapshotNumber",
      "_PreviousValues._SnapshotDate",
      "_PreviousValues.ObjectID",
      "_PreviousValues._ValidFrom",
      "_PreviousValues._ValidTo",
      "_PreviousValues.Project",
      "_PreviousValues._Revision",
      "_PreviousValues._RevisionNumber",
      "_PreviousValues._UnformattedID",
      "_PreviousValues._TypeHierarchy",
      "_PreviousValues._ItemHierarchy",
      "_PreviousValues._ProjectHierarchy",
      "_PreviousValues.Blocked",
      "_PreviousValues.PlanEstimate",
      "_PreviousValues.TaskEstimateTotal",
      "_PreviousValues.TaskActualTotal",
      "_PreviousValues.TaskRemainingTotal",
      "_PreviousValues.ScheduleState",
      "_PreviousValues.CreationDate",
      "_PreviousValues.Owner",
      "_PreviousValues.User",
      "_PreviousValues.Predecessors",
      "_PreviousValues.Successors"
    ])
#    .pagesize(10)
#    .hydrate([
#      "_TypeHierarchy",
#      "ScheduleState"
#    ])
#    .debug()

callback = () ->
  console.log("Retrieved #{this.allResults.length} snapshots")
  fs.writeFileSync('results.json', JSON.stringify(this.allResults))

#  uniqueTypesMap = {}
#  uniqueStatesMap = {}
#  for r in this.allResults
#    uniqueStatesMap[r.ScheduleState] = true
#    for t in r._TypeHierarchy
#      uniqueTypesMap[t] = true
#
#  uniqueTypes = []
#  uniqueStates = []
#  for key of uniqueTypesMap
#    if isNaN(Number(key))
#      uniqueTypes.push(key)
#  for key of uniqueStatesMap
#    uniqueStates.push(key)
#
#  query2 = new AnalyticsQuery(config)
##  query2.find({ObjectID: 12345, ScheduleState: {$in: uniqueStates}, _TypeHierarchy: {$in: uniqueTypes}})
#  query2.find({ObjectID: 12345, ScheduleState: "Released"})
#      .debug()
#
#  callback2 = () ->
#    console.log("Retrieved #{this.allResults.length} snapshots")
#
#  query2.getAll(callback2)

query.getAll(callback)



