(function() {
  var ChartTime, cfdCalculator, lumenize, root, timeSeriesGroupByCalculator, utils;

  root = this;

  lumenize = require('/lumenize');

  timeSeriesGroupByCalculator = lumenize.timeSeriesGroupByCalculator, ChartTime = lumenize.ChartTime;

  utils = lumenize.utils;

  cfdCalculator = function(results, config) {
    /*
      Takes the "results" from a query to Rally's Analytics API (or similar MVCC-based implementation)
      and returns the data points for a cumulative flow diagram (CFD).
    */
    var categories, ct, drillDownObjectIDs, firstTrackingDate, groupByAtArray, i, lastTrackingDate, listOfAtCTs, rangeSpec, row, series, timeSeriesGroupByCalculatorConfig, uniqueValues, _len, _ref;
    firstTrackingDate = '';
    for (i = 0, _len = results.length; i < _len; i++) {
      row = results[i];
      if (row[config.groupByField] === config.startTrackingGroupByFieldValue) {
        firstTrackingDate = row._ValidFrom;
        break;
      }
    }
    if (firstTrackingDate === '') {
      throw new Error("Couldn't find any data whose " + config.groupByField + " transititioned into groupByFieldValue " + config.startTrackingGroupByFieldValue);
    }
    lastTrackingDate = results[results.length - 1]._ValidFrom;
    rangeSpec = {
      workDays: config.workDays,
      holidays: config.holidays,
      start: new ChartTime(firstTrackingDate, 'day', config.timezone),
      pastEnd: new ChartTime(lastTrackingDate, 'day', config.timezone).add(1)
    };
    timeSeriesGroupByCalculatorConfig = {
      rangeSpec: rangeSpec,
      timezone: config.timezone,
      groupByField: config.groupByField,
      groupByFieldValues: config.groupByFieldValues,
      useAllGroupByFieldValues: config.useAllGroupByFieldValues,
      aggregationField: config.aggregationField,
      aggregationFunction: config.aggregationFunction,
      snapshotValidFromField: '_ValidFrom',
      snapshotUniqueID: 'ObjectID'
    };
    _ref = timeSeriesGroupByCalculator(results, timeSeriesGroupByCalculatorConfig), listOfAtCTs = _ref.listOfAtCTs, groupByAtArray = _ref.groupByAtArray, uniqueValues = _ref.uniqueValues;
    if (config.useAllGroupByFieldValues) {
      series = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'GroupBy');
      drillDownObjectIDs = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'DrillDown', uniqueValues, true);
    } else {
      series = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'GroupBy', config.groupByFieldValues);
      drillDownObjectIDs = lumenize.groupByAtArray_To_HighChartsSeries(groupByAtArray, config.groupByField, 'DrillDown', config.groupByFieldValues, true);
    }
    categories = (function() {
      var _i, _len2, _results;
      _results = [];
      for (_i = 0, _len2 = listOfAtCTs.length; _i < _len2; _i++) {
        ct = listOfAtCTs[_i];
        _results.push("" + (ct.toString()));
      }
      return _results;
    })();
    return {
      series: series,
      categories: categories,
      drillDownObjectIDs: drillDownObjectIDs
    };
  };

  root.cfdCalculator = cfdCalculator;

}).call(this);
