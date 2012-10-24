
root = this

root.XHRMock = require('../mock/XHRMock').XHRMock

analyticsquery = require('./analyticsquery')
root.AnalyticsQuery = analyticsquery.AnalyticsQuery
root.GuidedAnalyticsQuery = analyticsquery.GuidedAnalyticsQuery
root.AtAnalyticsQuery = analyticsquery.AtAnalyticsQuery
root.AtArrayAnalyticsQuery = analyticsquery.AtArrayAnalyticsQuery
root.BetweenAnalyticsQuery = analyticsquery.BetweenAnalyticsQuery
root.TimeInStateAnalyticsQuery = analyticsquery.TimeInStateAnalyticsQuery
root.TransitionsAnalyticsQuery = analyticsquery.PreviousToCurrentAnalyticsQuery