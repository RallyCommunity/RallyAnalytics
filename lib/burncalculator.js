(function() {
  var ChartTime, burnCalculator, lumenize, root, timeSeriesCalculator, utils;
  var __hasProp = Object.prototype.hasOwnProperty, __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (__hasProp.call(this, i) && this[i] === item) return i; } return -1; };

  root = this;

  if (typeof exports !== "undefined" && exports !== null) {
    lumenize = require('../lib/lumenize');
  } else {
    lumenize = require('/lumenize');
  }

  ChartTime = lumenize.ChartTime, timeSeriesCalculator = lumenize.timeSeriesCalculator;

  utils = lumenize.utils;

  burnCalculator = function(results, config) {
    /*
      Takes the "results" from a query to Rally's Analytics API (or similar MVCC-based implementation)
      and returns the series for burn charts.
    */
    var aggregationAtArray, aggregations, categories, ct, derivedFields, f, field, granularity, i, idealData, idealStep, listOfAtCTs, maxTaskEstimateTotal, name, originalPointCount, pastEnd, rangeSpec, s, series, seriesFound, seriesNames, start, timeSeriesCalculatorConfig, type, yAxis, _i, _len, _ref, _ref2, _ref3;
    if (config.granularity != null) {
      granularity = config.granularity;
    } else {
      granularity = 'day';
    }
    start = config.start;
    if (utils.type(start) === 'string') {
      start = new ChartTime(start, granularity, config.workspaceConfiguration.TimeZone);
    }
    pastEnd = new ChartTime(results[results.length - 1]._ValidFrom, granularity, config.workspaceConfiguration.TimeZone).add(1);
    rangeSpec = {
      workDays: config.workspaceConfiguration.WorkDays,
      holidays: config.holidays,
      start: start,
      pastEnd: pastEnd
    };
    if (config.upSeriesType == null) config.upSeriesType = 'Sums';
    derivedFields = [];
    if (config.upSeriesType === 'Points') {
      derivedFields.push({
        name: 'Accepted',
        f: function(row) {
          var _ref;
          if (_ref = row.ScheduleState, __indexOf.call(config.acceptedStates, _ref) >= 0) {
            return row.PlanEstimate;
          } else {
            return 0;
          }
        }
      });
    } else if (config.upSeriesType === 'Story Count') {
      derivedFields.push({
        name: 'Accepted',
        f: function(row) {
          var _ref;
          if (_ref = row.ScheduleState, __indexOf.call(config.acceptedStates, _ref) >= 0) {
            return 1;
          } else {
            return 0;
          }
        }
      });
    } else {
      console.error("Unrecognized upSeriesType: " + config.upSeriesType);
    }
    seriesNames = [];
    aggregations = [];
    _ref = config.series;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      s = _ref[_i];
      seriesFound = true;
      switch (s) {
        case 'down':
          name = 'Task To Do (Hours)';
          f = '$sum';
          field = 'TaskRemainingTotal';
          yAxis = 0;
          type = 'column';
          break;
        case 'ideal':
          name = "Ideal (Hours)";
          f = '$sum';
          field = 'TaskEstimateTotal';
          yAxis = 0;
          type = 'line';
          break;
        case 'up':
          name = "Accepted (" + config.upSeriesType + ")";
          f = '$sum';
          field = 'Accepted';
          yAxis = 1;
          type = 'column';
          break;
        case 'scope':
          name = "Scope (" + config.upSeriesType + ")";
          if (config.upSeriesType === 'Story Count') {
            f = '$count';
          } else if (config.upSeriesType === 'Points') {
            f = '$sum';
          }
          field = 'PlanEstimate';
          yAxis = 1;
          type = 'line';
          break;
        default:
          if ((s.name != null) && (s.f != null) && (s.field != null)) {
            name = s.name;
            f = s.f;
            field = s.field;
            type = 'column';
          } else {
            seriesFound = false;
            console.error("Unrecognizable series: " + s);
          }
      }
      if (seriesFound) {
        aggregations.push({
          name: name,
          as: name,
          f: f,
          field: field,
          yAxis: yAxis,
          type: type
        });
        seriesNames.push(name);
      }
    }
    timeSeriesCalculatorConfig = {
      rangeSpec: rangeSpec,
      derivedFields: derivedFields,
      aggregations: aggregations,
      timezone: config.workspaceConfiguration.TimeZone,
      snapshotValidFromField: '_ValidFrom',
      snapshotUniqueID: 'ObjectID'
    };
    _ref2 = lumenize.timeSeriesCalculator(results, timeSeriesCalculatorConfig), listOfAtCTs = _ref2.listOfAtCTs, aggregationAtArray = _ref2.aggregationAtArray;
    series = lumenize.aggregationAtArray_To_HighChartsSeries(aggregationAtArray, aggregations);
    categories = (function() {
      var _j, _len2, _results;
      _results = [];
      for (_j = 0, _len2 = listOfAtCTs.length; _j < _len2; _j++) {
        ct = listOfAtCTs[_j];
        _results.push("" + (ct.toString()));
      }
      return _results;
    })();
    originalPointCount = categories.length;
    i = 0;
    while (series[i].name.indexOf("Ideal") < 0) {
      i++;
    }
    idealData = series[i].data;
    maxTaskEstimateTotal = lumenize.functions.$max(idealData);
    idealStep = maxTaskEstimateTotal / (originalPointCount - 1);
    for (i = 0, _ref3 = originalPointCount - 2; 0 <= _ref3 ? i <= _ref3 : i >= _ref3; 0 <= _ref3 ? i++ : i--) {
      idealData[i] = (originalPointCount - 1 - i) * idealStep;
    }
    idealData[originalPointCount - 1] = 0;
    return {
      categories: categories,
      series: series
    };
  };

  root.burnCalculator = burnCalculator;

}).call(this);
