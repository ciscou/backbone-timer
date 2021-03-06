$ ->
  Time = Backbone.Model.extend
    defaults:
      plus2: false
      dnf  : false
    formattedTime: ->
      ms = @get "ms"
      return "DNF" if @get("dnf")
      return "N/A" unless ms?

      ms      = Math.round ms
      [s, ms] = @divmod ms, 1000
      [m, s ] = @divmod s,  60
      ft = "#{m}:#{@twoDigits(s)}.#{@threeDigits(ms)}"
      ft += " +2" if @get("plus2")
      ft
    getMsWithPenalties: ->
      if @get("dnf")
        Infinity
      else
        ms = @get("ms")
        ms += 2000 if @get("plus2")
        ms
    togglePlus2: ->
      @save plus2: !@get("plus2")
    toggleDnf: ->
      @save dnf: !@get("dnf")
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
    sessionAverage: ->
      attrs = {}
      if @length > 0
        times = @map (t) -> t.getMsWithPenalties()
        sum = times.reduce ((a, e) -> a + e), 0
        attrs.dnf = !isFinite(sum)
        attrs.ms = sum / @length
      new Time attrs
    average5: ->
      @average(5)
    average12: ->
      @average(12)
    bestAverage5: ->
      @bestAverage(5)
    bestAverage12: ->
      @bestAverage(12)
    average: (n, offset=0) ->
      attrs = {}
      if @length-offset >= n
        latestN = @slice(@length-n-offset, @length-offset)
        times = latestN.map (t) -> t.getMsWithPenalties()
        timesWithoutBestAndWorst = _.sortBy(times, (t) -> t).slice(1, n-1)
        sum = timesWithoutBestAndWorst.reduce ((a, e) -> a + e), 0
        attrs.dnf = !isFinite(sum)
        attrs.ms = sum / (n-2)
      new Time attrs
    bestAverage: (n) ->
      attrs = {}
      if @length >= n
        averages = (@average(n, offset) for offset in [0..@length-n])
        times = averages.map (t) -> t.getMsWithPenalties()
        best = _.min times
        attrs.dnf = !isFinite(best)
        attrs.ms = best
      new Time attrs
  Times = new TimeList

  TimeView = Backbone.View.extend
    tagName: "li"
    template: _.template $("#time-template").html()
    events:
      "click .plus2" : "onPlus2Click"
      "click .dnf"   : "onDnfClick"
      "click .remove": "onRemoveClick"
      "click"        : "onClick"
    initialize: ->
      @listenTo @model, "change", @render
      @listenTo @model, "destroy", @remove
    render: ->
      @$el.html @template @model.toTemplateJSON()
      @
    onClick: (e) ->
      e.preventDefault()
    onPlus2Click: (e) ->
      e.preventDefault()
      e.stopPropagation()
      @model.togglePlus2()
    onDnfClick: (e) ->
      e.preventDefault()
      e.stopPropagation()
      @model.toggleDnf()
    onRemoveClick: (e) ->
      e.preventDefault()
      e.stopPropagation()
      @model.destroy()

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
      "mousedown  #pad": "onPadPress"
      "mouseup    #pad": "onPadRelease",
      "touchstart #pad": "onPadPress",
      "touchend   #pad": "onPadRelease",
      "touchmove  #pad": "onPadMove",
      "click      #puzzles .puzzle": "onClickPuzzle",
    initialize: ->
      @$pad      = @$("#pad")
      @$pad.attr('unselectable', 'on').css('user-select', 'none').on('selectstart', false)
      localStorage.currentPuzzle ||= "333"
      @$("#puzzles .puzzle").removeClass("selected")
      @$("#puzzles .puzzle[data-puzzle=#{localStorage.currentPuzzle}]").addClass("selected")
      @currentTime = new Time ms: 0
      new DisplayView model: @currentTime
      @listenTo Times, "add", @addTime
      @listenTo Times, "all", @render
      Times.fetch()
      @start()
      @generateScramble()
      $(document).keydown _.bind(@onPadPress, @)
      $(document).keyup   _.bind(@onPadRelease, @)
    render: ->
      @$("#session-average").text Times.sessionAverage().formattedTime()
      @$("#average-5").text Times.average5().formattedTime()
      @$("#average-12").text Times.average12().formattedTime()
      @$("#best-average-5").text Times.bestAverage5().formattedTime()
      @$("#best-average-12").text Times.bestAverage12().formattedTime()
      @$("#time-list-length").text Times.length
    addTime: (time) ->
      view = new TimeView model: time
      @$("#time-list li:first-child").after view.render().el
    onPadPress: (e) ->
      return if e.type == "keydown" && e.keyCode != 32
      if @state == "start"
        @state = "pressing"
        @pressingTo = setTimeout _.bind(@onPressingTimeout, this), 400
        @$pad.text "Wait..."
      else if @state == "running"
        @state = "finished"
        clearTimeout @runningTo
        @tick()
        @$pad.text "Finished"
        Times.create @currentTime.attributes
    onPadRelease: (e) ->
      return if e.type == "keydown" && e.keyCode != 32
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
        @generateScramble()
        @$pad.removeClass "success"
        $(".left-off-canvas-toggle").click()
    onPadMove: (e) ->
      if @state == "pressing"
        @start()
        clearTimeout @pressingTo
    onClickPuzzle: (e) ->
      e.preventDefault()
      $target = $(e.currentTarget)
      selectedPuzzle = $target.attr("data-puzzle")
      @$("#puzzles .puzzle").removeClass("selected")
      $target.addClass("selected")
      unless localStorage.currentPuzzle == selectedPuzzle
        localStorage.currentPuzzle = selectedPuzzle
        @restart()
      $(".right-off-canvas-toggle").click()
    onPressingTimeout: ->
      @state = "ready"
      @$pad.addClass("success").text "Release to start"
    onRunningTimeout: ->
      @tick()
      @runningTo = setTimeout _.bind(@onRunningTimeout, this), 50
    tick: ->
      elapsed = new Date().getTime() - @startTime
      @currentTime.set("ms", elapsed)
    generateScramble: ->
      @$("#scramble").text "Loading..."
      @initializedScramblers ||= {}
      if @initializedScramblers[localStorage.currentPuzzle]
        @$("#scramble").text scramblers[localStorage.currentPuzzle].getRandomScramble().scramble_string
      else
        self = this
        f = ->
          cb = ->
            self.initializedScramblers[localStorage.currentPuzzle] = true
            self.generateScramble()
          scramblers[localStorage.currentPuzzle].initialize cb, Math
        setTimeout(f, 50)
    start: ->
      @state = "start"
      @$pad.text "Press and hold to start"
    restart: ->
      _.chain(Times.models).clone().each (model) -> model.destroy()
      @start()
      @generateScramble()

  new AppView()
