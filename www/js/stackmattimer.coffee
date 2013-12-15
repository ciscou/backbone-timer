$ ->
  Time = Backbone.Model.extend
    formattedTime: ->
      ms      = Math.floor @get("ms")
      [s, ms] = @divmod ms, 1000
      [m, s ] = @divmod s,  60
      "#{m}:#{@twoDigits(s)}.#{@threeDigits(ms)}"
    toTemplateJSON: ->
      json = @toJSON()
      _.extend json, formattedTime: @formattedTime()
    divmod: (x, y) ->
      [Math.floor(x / y), x % y]
    twoDigits: (x) -> @nDigits(x, 2)
    threeDigits: (x) -> @nDigits(x, 3)
    nDigits: (x, n) ->
      s = "00#{x}"
      s.slice s.length-n, s.length

  TimeList = Backbone.Collection.extend
    localStorage: new Backbone.LocalStorage("TimeList")
    model: Time
    average5: ->
      @average(5)
    average12: ->
      @average(12)
    average: (n) ->
      if @length >= n
        times = @slice(0, n).map (e) -> e.get("ms")
        sum   = times.reduce ((a, e) -> a + e), 0
        best  = _.min times
        worst = _.max times
        (sum - best - worst) / (n - 2)
  Times = new TimeList

  TimeView = Backbone.View.extend
    tagName: "li"
    template: _.template $("#time-template").html()
    initialize: ->
      @listenTo @model, "change", @render
      @listenTo @model, "destroy", @remove
    render: ->
      @$el.html @template @model.toTemplateJSON()
      @

  DisplayView = Backbone.View.extend
    el: $("#display")
    template: _.template $("#display-template").html()
    initialize: ->
      @listenTo @model, "change", @render
      @render()
    render: ->
      @$el.html @template @model.toTemplateJSON()
      @

  AppView = Backbone.View.extend
    el: $("#stackmattimer")
    events:
      "mousedown  #pad": "onMouseDown"
      "mouseup    #pad": "onMouseUp",
      "touchstart #pad": "onMouseDown",
      "touchend   #pad": "onMouseUp",
      "click      #puzzles .puzzle": "onClickPuzzle"
    initialize: ->
      @$pad      = @$("#pad")
      @$scramble = @$("#scramble")
      @currentTime = new Time ms: 0
      new DisplayView model: @currentTime
      @listenTo Times, "add", @addTime
      @listenTo Times, "all", @render
      Times.fetch()
      @start()
    render: ->
      average5  = Times.average5()
      average12 = Times.average12()
      @$("#average-5").text if average5?
                              new Time(ms: average5).formattedTime()
                            else
                              "N/A"
      @$("#average-12").text if average12?
                               new Time(ms: average12).formattedTime()
                             else
                               "N/A"
    addTime: (time) ->
      view = new TimeView model: time
      @$("#time-list li:first-child").after view.render().el
    onMouseDown: (e) ->
      e.preventDefault()
      if @state == "start"
        @state = "pressing"
        @pressingTo = setTimeout _.bind(@onPressingTimeout, this), 400
        @$pad.text "Wait..."
      else if @state == "running"
        @state = "finished"
        clearTimeout @runningTo
        @$pad.text "Finished"
        Times.create @currentTime.attributes, at: 0
    onMouseUp: (e) ->
      e.preventDefault()
      if @state == "pressing"
        @start()
        clearTimeout @pressingTo
      else if @state == "ready"
        @startTime = new Date().getTime()
        @currentTime.set("ms", 0)
        @runningTo = setTimeout _.bind(@onRunningTimeout, this), 50
        @state = "running"
        @$pad.text "Press to stop"
      else if @state == "finished"
        @start()
        $(".left-off-canvas-toggle").click()
    onClickPuzzle: (e) ->
      e.preventDefault()
      @$scramble.text $(e.currentTarget).data("puzzle")
      $(".right-off-canvas-toggle").click()
      _.chain(Times.models).clone().each (model) -> model.destroy()
    onPressingTimeout: ->
      @state = "ready"
      @$pad.text "Release to start"
    onRunningTimeout: ->
      elapsed = new Date().getTime() - @startTime
      @currentTime.set("ms", elapsed)
      @runningTo = setTimeout _.bind(@onRunningTimeout, this), 50
    start: ->
      @state = "start"
      @$pad.text "Press and hold to start"

  new AppView()
