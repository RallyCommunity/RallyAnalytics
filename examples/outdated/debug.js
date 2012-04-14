(function() {
  var ChartTime, ChartTimeRange, histogram, lumenize, processSnapshots;

  lumenize = require('/index');

  ChartTime = lumenize.ChartTime;

  ChartTime.setTZPath('anything');

  ChartTimeRange = lumenize.ChartTimeRange;

  histogram = lumenize.histogram;

  $(document).ready(function() {
    return processSnapshots([]);
  });

  processSnapshots = function(snapshots) {
    var b, baseChance, bucketSize, buckets, chartMax, clipped, data, granularity, histogramCategories, histogramData, histogramField, histogramResults, histogramSpec, hourCT, i1, milliseconds, r1, rangeSpec, row, scatter, timeInState, timezone, tooltipLookup, uniqueIDField, valueMax, workHours, workMinutes, _i, _j, _k, _len, _len2, _len3;
    granularity = 'hour';
    timezone = 'America/Chicago';
    uniqueIDField = 'ObjectID';
    rangeSpec = {
      granularity: granularity,
      start: '2011-01-01',
      pastEnd: '2011-04-01',
      startWorkTime: {
        hour: 9,
        minute: 0
      },
      pastEndWorkTime: {
        hour: 17,
        minute: 0
      }
    };
    r1 = new ChartTimeRange(rangeSpec);
    i1 = r1.getIterator('ChartTime');
    timeInState = [];
    row;
    hourCT;
    baseChance = Math.random() * 0.5;
    while (i1.hasNext()) {
      hourCT = i1.next();
      if (Math.random() < baseChance) {
        row = {
          ObjectID: i1.count,
          ticks: Math.pow(4, (Math.random() + 0.7) * 2.6) + 4 * 8,
          finalEventAt: hourCT.getJSDate(timezone)
        };
        timeInState.push(row);
        if (Math.random() < baseChance) {
          row = {
            ObjectID: i1.count,
            ticks: Math.pow(4, (Math.random() + 0.7) * 2.6) + 4 * 8,
            finalEventAt: hourCT.getJSDate(timezone)
          };
          timeInState.push(row);
        }
      }
      if (Math.random() < baseChance / 20) {
        row = {
          ObjectID: i1.count,
          ticks: Math.pow(4, (Math.random() + 0.9) * 2.6),
          finalEventAt: hourCT.getJSDate(timezone)
        };
        timeInState.push(row);
      }
      if (Math.random() < baseChance / 20) {
        row = {
          ObjectID: i1.count,
          ticks: Math.random() * 40,
          finalEventAt: hourCT.getJSDate(timezone)
        };
        timeInState.push(row);
      }
    }
    if (r1.pastEndWorkMinutes > r1.startWorkMinutes) {
      workMinutes = r1.pastEndWorkMinutes - r1.startWorkMinutes;
    } else {
      workMinutes = 24 * 60 - r1.startWorkMinutes;
      workMinutes += r1.pastEndWorkMinutes;
    }
    workHours = workMinutes / 60;
    for (_i = 0, _len = timeInState.length; _i < _len; _i++) {
      row = timeInState[_i];
      row.days = row.ticks / workHours;
    }
    histogramField = 'days';
    histogramResults = histogram(timeInState, histogramField);
    if (!histogramResults) return;
    buckets = histogramResults.buckets, chartMax = histogramResults.chartMax, valueMax = histogramResults.valueMax, bucketSize = histogramResults.bucketSize, clipped = histogramResults.clipped;
    data = [];
    tooltipLookup = {};
    for (_j = 0, _len2 = timeInState.length; _j < _len2; _j++) {
      row = timeInState[_j];
      milliseconds = row.finalEventAt.getTime();
      while (tooltipLookup[milliseconds]) {
        milliseconds++;
      }
      data.push([milliseconds, row.clippedChartValue]);
      tooltipLookup[milliseconds] = row;
    }
    histogramCategories = [];
    histogramData = [];
    for (_k = 0, _len3 = buckets.length; _k < _len3; _k++) {
      b = buckets[_k];
      histogramCategories.push(b.label);
      histogramData.push(-1 * b.count);
    }
    scatter = new Highcharts.Chart({
      chart: {
        renderTo: 'scatter-container',
        defaultSeriesType: 'scatter'
      },
      legend: {
        enabled: false
      },
      credits: {
        enabled: false
      },
      title: {
        text: 'Cycle Time Scatter'
      },
      subtitle: {
        text: ''
      },
      xAxis: {
        startOnTick: false,
        tickmarkPlacement: 'on',
        title: {
          enabled: false
        },
        type: 'datetime'
      },
      yAxis: [
        {
          title: {
            text: null
          },
          tickInterval: 1,
          labels: {
            formatter: function() {
              if (this.value !== 0) {
                return Highcharts.numberFormat(buckets[this.value - 1].percentile * 100, 1) + "%";
              }
            }
          },
          min: 0,
          max: buckets.length
        }, {
          title: {
            text: 'Cycle Time (Work Days)'
          },
          opposite: true,
          endOnTick: false,
          tickInterval: bucketSize,
          labels: {
            formatter: function() {
              if (this.value === chartMax) {
                if (clipped) {
                  return '' + valueMax + '*';
                } else {
                  return chartMax;
                }
              } else {
                return this.value / 1;
              }
            }
          },
          min: 0,
          max: chartMax
        }
      ],
      tooltip: {
        formatter: function() {
          var lookupRow;
          lookupRow = tooltipLookup[this.x];
          return uniqueIDField + ': ' + lookupRow[uniqueIDField] + '<br />' + this.series.name + ': <b>' + Highcharts.numberFormat(lookupRow[histogramField], 1) + '</b> work days';
        }
      },
      series: [
        {
          name: 'Cycle time',
          data: data,
          yAxis: 1
        }, {
          name: 'Percentile',
          data: []
        }
      ]
    });
    histogramSpec = {
      chart: {
        renderTo: 'histogram-container',
        defaultSeriesType: 'bar'
      },
      legend: {
        enabled: false
      },
      credits: {
        enabled: false
      }
    };
    return {
      title: {
        text: 'Cycle Time Histogram'
      },
      subtitle: {
        text: ''
      },
      xAxis: [
        {
          opposite: true,
          reversed: false,
          categories: histogramCategories
        }
      ],
      yAxis: {
        title: {
          text: null
        },
        labels: {
          formatter: function() {
            return Math.abs(this.value);
          }
        },
        max: 0
      },
      plotOptions: {
        series: {
          stacking: 'normal'
        }
      },
      tooltip: {
        formatter: function() {
          return '' + this.point.category(+' work days: <b>' + Highcharts.numberFormat(Math.abs(this.point.y), 0) + '</b>');
        }
      },
      series: [
        {
          name: 'Cycle time',
          data: histogramData
        }
      ]
    };
  };

  histogram = new Highcharts.Chart(histogramSpec, function(chart) {
    if (clipped) return chart.renderer.text('* non-linear', 20, 65).add();
  });

}).call(this);
