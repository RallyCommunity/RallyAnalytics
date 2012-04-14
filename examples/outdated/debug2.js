(function() {
  var histogramSpec;

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

  ({
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
  });

}).call(this);
