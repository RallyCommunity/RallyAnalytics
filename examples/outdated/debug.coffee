            

          lumenize = require('/index')
          ChartTime = lumenize.ChartTime
          ChartTime.setTZPath('anything')
          ChartTimeRange = lumenize.ChartTimeRange
          # ChartTimeIterator = lumenize.ChartTimeIterator
          # ChartTimeInStateCalculator = lumenize.ChartTimeInStateCalculator
          histogram = lumenize.histogram
          
          $(document).ready( () ->
            # fetch the snapshots and pass them to processSnapshots
            processSnapshots([])
          )
          
          
          processSnapshots = (snapshots) ->
            granularity = 'hour'
            timezone = 'America/Chicago'
            uniqueIDField = 'ObjectID'
              
            rangeSpec =
              granularity: granularity
              start: '2011-01-01'
              pastEnd: '2011-04-01'
              startWorkTime:
                hour: 9
                minute: 0
              pastEndWorkTime:
                hour: 17
                minute: 0
            
            r1 = new ChartTimeRange(rangeSpec)
            
            i1 = r1.getIterator('ChartTime')
              
            # isc1 = i1.getChartTimeInStateCalculator(timezone)
            # timeInState = isc1.timeInState(snapshots, '_ValidFrom', '_ValidTo', uniqueIDField)
            
            # ---
            # Replace with call to ChartTimeInState above
            timeInState = []
            row
            hourCT
              
            baseChance = Math.random() * 0.5
            while i1.hasNext() 
              hourCT = i1.next()
              if Math.random() < baseChance #>
                row = 
                  ObjectID: i1.count
                  ticks: Math.pow(4, (Math.random() + 0.7) * 2.6) + 4 * 8
                  finalEventAt: hourCT.getJSDate(timezone)
                timeInState.push(row);
                if Math.random() < baseChance #> different value but same hourCT
                  row = 
                    ObjectID: i1.count
                    ticks: Math.pow(4, (Math.random() + 0.7) * 2.6) + 4 * 8
                    finalEventAt: hourCT.getJSDate(timezone)
                  timeInState.push(row);
              if (Math.random() < baseChance / 20) #>
                row = 
                  ObjectID: i1.count
                  ticks: Math.pow(4, (Math.random() + 0.9) * 2.6)
                  finalEventAt: hourCT.getJSDate(timezone)
                timeInState.push(row)
              if Math.random() < baseChance / 20 #>
                row =
                  ObjectID: i1.count
                  ticks: Math.random() * 40
                  finalEventAt: hourCT.getJSDate(timezone)
                timeInState.push(row)
            # ----
            
            if (r1.pastEndWorkMinutes > r1.startWorkMinutes)
              workMinutes = r1.pastEndWorkMinutes - r1.startWorkMinutes
            else
              workMinutes = 24 * 60 - r1.startWorkMinutes
              workMinutes += r1.pastEndWorkMinutes
            workHours = workMinutes / 60
                   
            for row in timeInState
              row.days = row.ticks / workHours
            
            histogramField = 'days'
            histogramResults = histogram(timeInState, histogramField)
            unless histogramResults  # returns null if it can't calculate a histogram
              return
            
            {buckets, chartMax, valueMax, bucketSize, clipped} = histogramResults
            
            data = []
            tooltipLookup = {}
            for row in timeInState
              milliseconds = row.finalEventAt.getTime()
              while tooltipLookup[milliseconds]   # Hack so we get different index
                milliseconds++
              data.push([milliseconds, row.clippedChartValue])
              tooltipLookup[milliseconds] = row
            
            histogramCategories = []
            histogramData = []
            for b in buckets
              histogramCategories.push(b.label)
              histogramData.push(-1 * b.count)
            
            scatter = new Highcharts.Chart({
              chart:
                renderTo: 'scatter-container'
                defaultSeriesType: 'scatter'
              legend:
                enabled: false
              credits:
                enabled: false
              title:
                text: 'Cycle Time Scatter'
              subtitle:
                text: ''
              xAxis:
                startOnTick: false
                tickmarkPlacement: 'on'
                title:
                  enabled: false
                type: 'datetime'
              yAxis: [
                {
                  title:
                    text: null
                  # endOnTick: true,
                  tickInterval: 1
                  labels:
                    formatter: () ->
                      if this.value != 0
                        return Highcharts.numberFormat(buckets[this.value - 1].percentile * 100, 1) + "%"
                  min: 0,
                  max: buckets.length                        
                },
                {
                  title:
                      text: 'Cycle Time (Work Days)'
                  opposite: true,
                  endOnTick: false,
                  tickInterval: bucketSize,
                  labels:
                    formatter: () ->
                      # console.log(JSON.stringify(this, undefined, 2))
                      if this.value == chartMax
                        if clipped
                          return '' + valueMax + '*'
                        else
                          return chartMax
                      else
                        return this.value / 1
                  min: 0
                  max: chartMax
                }
              ]           
              tooltip:
                formatter: () ->
                  lookupRow = tooltipLookup[this.x]
                  return uniqueIDField + ': ' + lookupRow[uniqueIDField] + '<br />' + # !TODO: Upgrade to link to revisions page in Rally
                    this.series.name + ': <b>' + Highcharts.numberFormat(lookupRow[histogramField], 1) + '</b> work days'
              series: [
            	  {
            			name: 'Cycle time'
            			data: data
            			yAxis: 1
                },
            		{
            		  name: 'Percentile'
            		  data: []
            		}
              ]
            })
            
                        
            histogram = new Highcharts.Chart({
              chart:
                renderTo: 'histogram-container'
                defaultSeriesType: 'bar'
              legend: 
                enabled: false
              credits:
                enabled: false
            	title:
            		text: 'Cycle Time Histogram'
            	subtitle:
            		text: ''
            	xAxis: [{
            		opposite: true
            		reversed: false
            		categories: histogramCategories
            	}]
            	yAxis:
            		title:
            			text: null
            		labels:
            			formatter: () ->
            				return Math.abs(this.value)
            		max: 0
            	plotOptions:
            		series:
            			stacking: 'normal'
            	tooltip:
            		formatter: () ->
            			return '' + this.point.category +' work days: <b>' + Highcharts.numberFormat(Math.abs(this.point.y), 0) + '</b>'
            	series: [{
            		name: 'Cycle time'
            		data: histogramData
            	}]
            }, (chart) ->
                if clipped
                  chart.renderer.text('* non-linear', 20, 65).add()
            )
