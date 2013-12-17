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
    average5: ->
      @average(5)
    average12: ->
      @average(12)
    average: (n) ->
      attrs = {}
      if @length >= n
        slice = @slice(@length-n, @length)
        dnfs  = _.filter(slice, (e) -> e.get("dnf")).length
        if dnfs > 1
          attrs.dnf = true
        else
          times = _.reject(slice, (e) -> e.get("dnf")).map (e) ->
            ms = e.get("ms")
            ms += 2000 if e.get("plus2")
            ms
          sum   = times.reduce ((a, e) -> a + e), 0
          best  = _.min times
          worst = if dnfs == 0
                    _.max times
                  else
                    0
          attrs.ms = (sum - best - worst) / (n - 2)
      new Time attrs
  Times = new TimeList

  TimeView = Backbone.View.extend
    tagName: "li"
    template: _.template $("#time-template").html()
    events:
      "click .plus2" : "onPlus2Click"
      "click .dnf"   : "onDnfClick"
      "click .remove": "onRemoveClick"
      "click .time"  : "onTimeClick"
      "click"        : "onClick"
    initialize: ->
      @listenTo @model, "change", @render
      @listenTo @model, "destroy", @remove
    render: ->
      @$el.html @template @model.toTemplateJSON()
      @
    onClick: (e) ->
      e.preventDefault()
    onTimeClick: (e) ->
      e.preventDefault()
      @$el.toggleClass("selected")
    onPlus2Click: (e) ->
      e.preventDefault()
      @model.togglePlus2()
      @$el.removeClass("selected")
    onDnfClick: (e) ->
      e.preventDefault()
      @model.toggleDnf()
      @$el.removeClass("selected")
    onRemoveClick: (e) ->
      e.preventDefault()
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
      "mousedown   #pad": "onPadPress"
      "mouseup     #pad": "onPadRelease",
      "touchstart  #pad": "onPadPress",
      "touchend    #pad": "onPadRelease",
      "touchcancel #pad": "onPadRelease",
      "click      #puzzles .puzzle": "onClickPuzzle",
    initialize: ->
      @$pad      = @$("#pad")
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
      @$("#average-5").text Times.average5().formattedTime()
      @$("#average-12").text Times.average12().formattedTime()
    addTime: (time) ->
      view = new TimeView model: time
      @$("#time-list li:first-child").after view.render().el
    onPadPress: (e) ->
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
      @generatedScramblers ||= {}
      if @generatedScramblers[localStorage.currentPuzzle]
        @$("#scramble").text scramblers[localStorage.currentPuzzle].getRandomScramble().scramble_string
      else
        self = this
        cb = ->
          self.generatedScramblers[localStorage.currentPuzzle] = true
          self.generateScramble()
        scramblers[localStorage.currentPuzzle].initialize cb, Math
    start: ->
      @state = "start"
      @$pad.text "Press and hold to start"
    restart: ->
      _.chain(Times.models).clone().each (model) -> model.destroy()
      @start()
      @generateScramble()

  new AppView()
