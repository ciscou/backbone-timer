(function() {
  $(function() {
    var AppView, DisplayView, Time, TimeList, TimeView, Times;
    Time = Backbone.Model.extend({
      formattedTime: function() {
        var m, ms, s, _ref, _ref1;
        ms = Math.floor(this.get("ms"));
        _ref = this.divmod(ms, 1000), s = _ref[0], ms = _ref[1];
        _ref1 = this.divmod(s, 60), m = _ref1[0], s = _ref1[1];
        return "" + m + ":" + (this.twoDigits(s)) + "." + (this.threeDigits(ms));
      },
      toTemplateJSON: function() {
        var json;
        json = this.toJSON();
        return _.extend(json, {
          formattedTime: this.formattedTime()
        });
      },
      divmod: function(x, y) {
        return [Math.floor(x / y), x % y];
      },
      twoDigits: function(x) {
        return this.nDigits(x, 2);
      },
      threeDigits: function(x) {
        return this.nDigits(x, 3);
      },
      nDigits: function(x, n) {
        var s;
        s = "00" + x;
        return s.slice(s.length - n, s.length);
      }
    });
    TimeList = Backbone.Collection.extend({
      localStorage: new Backbone.LocalStorage("TimeList"),
      model: Time,
      average5: function() {
        return this.average(5);
      },
      average12: function() {
        return this.average(12);
      },
      average: function(n) {
        var best, sum, times, worst;
        if (this.length >= n) {
          times = this.slice(0, n).map(function(e) {
            return e.get("ms");
          });
          sum = times.reduce((function(a, e) {
            return a + e;
          }), 0);
          best = _.min(times);
          worst = _.max(times);
          return (sum - best - worst) / (n - 2);
        }
      }
    });
    Times = new TimeList;
    TimeView = Backbone.View.extend({
      tagName: "li",
      template: _.template($("#time-template").html()),
      initialize: function() {
        this.listenTo(this.model, "change", this.render);
        return this.listenTo(this.model, "destroy", this.remove);
      },
      render: function() {
        this.$el.html(this.template(this.model.toTemplateJSON()));
        return this;
      }
    });
    DisplayView = Backbone.View.extend({
      el: $("#display"),
      template: _.template($("#display-template").html()),
      initialize: function() {
        this.listenTo(this.model, "change", this.render);
        return this.render();
      },
      render: function() {
        this.$el.html(this.template(this.model.toTemplateJSON()));
        return this;
      }
    });
    AppView = Backbone.View.extend({
      el: $("#stackmattimer"),
      events: {
        "mousedown   #pad": "onPadPress",
        "mouseup     #pad": "onPadRelease",
        "touchstart  #pad": "onPadPress",
        "touchend    #pad": "onPadRelease",
        "touchcancel #pad": "onPadRelease",
        "click      #puzzles .puzzle": "onClickPuzzle"
      },
      initialize: function() {
        this.$pad = this.$("#pad");
        localStorage.currentPuzzle || (localStorage.currentPuzzle = "333");
        this.$("#puzzles .puzzle").removeClass("selected");
        this.$("#puzzles .puzzle[data-puzzle=" + localStorage.currentPuzzle + "]").addClass("selected");
        this.currentTime = new Time({
          ms: 0
        });
        new DisplayView({
          model: this.currentTime
        });
        this.listenTo(Times, "add", this.addTime);
        this.listenTo(Times, "all", this.render);
        Times.fetch();
        this.start();
        return this.generateScramble();
      },
      render: function() {
        var average12, average5;
        average5 = Times.average5();
        average12 = Times.average12();
        this.$("#average-5").text(average5 != null ? new Time({
          ms: average5
        }).formattedTime() : "N/A");
        return this.$("#average-12").text(average12 != null ? new Time({
          ms: average12
        }).formattedTime() : "N/A");
      },
      addTime: function(time) {
        var view;
        view = new TimeView({
          model: time
        });
        return this.$("#time-list li:first-child").after(view.render().el);
      },
      onPadPress: function(e) {
        if (this.state === "start") {
          this.state = "pressing";
          this.pressingTo = setTimeout(_.bind(this.onPressingTimeout, this), 400);
          return this.$pad.text("Wait...");
        } else if (this.state === "running") {
          this.state = "finished";
          clearTimeout(this.runningTo);
          this.tick();
          this.$pad.text("Finished");
          return Times.create(this.currentTime.attributes, {
            at: 0
          });
        }
      },
      onPadRelease: function(e) {
        if (this.state === "pressing") {
          this.start();
          return clearTimeout(this.pressingTo);
        } else if (this.state === "ready") {
          this.startTime = new Date().getTime();
          this.currentTime.set("ms", 0);
          this.runningTo = setTimeout(_.bind(this.onRunningTimeout, this), 50);
          this.state = "running";
          return this.$pad.text("Press to stop");
        } else if (this.state === "finished") {
          this.start();
          this.generateScramble();
          this.$pad.removeClass("success");
          return $(".left-off-canvas-toggle").click();
        }
      },
      onClickPuzzle: function(e) {
        var $target, selectedPuzzle;
        e.preventDefault();
        $target = $(e.currentTarget);
        selectedPuzzle = $target.attr("data-puzzle");
        this.$("#puzzles .puzzle").removeClass("selected");
        $target.addClass("selected");
        if (localStorage.currentPuzzle !== selectedPuzzle) {
          localStorage.currentPuzzle = selectedPuzzle;
          this.restart();
        }
        return $(".right-off-canvas-toggle").click();
      },
      onPressingTimeout: function() {
        this.state = "ready";
        return this.$pad.addClass("success").text("Release to start");
      },
      onRunningTimeout: function() {
        this.tick();
        return this.runningTo = setTimeout(_.bind(this.onRunningTimeout, this), 50);
      },
      tick: function() {
        var elapsed;
        elapsed = new Date().getTime() - this.startTime;
        return this.currentTime.set("ms", elapsed);
      },
      generateScramble: function() {
        var scrambler;
        scrambler = window["scrambler_" + localStorage.currentPuzzle];
        return this.$("#scramble").text(scrambler != null ? scrambler() : "N/A");
      },
      start: function() {
        this.state = "start";
        return this.$pad.text("Press and hold to start");
      },
      restart: function() {
        _.chain(Times.models).clone().each(function(model) {
          return model.destroy();
        });
        this.start();
        return this.generateScramble();
      }
    });
    return new AppView();
  });

}).call(this);
