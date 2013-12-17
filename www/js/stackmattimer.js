(function() {
  $(function() {
    var AppView, DisplayView, Time, TimeList, TimeView, Times;
    Time = Backbone.Model.extend({
      defaults: {
        plus2: false,
        dnf: false
      },
      formattedTime: function() {
        var ft, m, ms, s, _ref, _ref1;
        ms = this.get("ms");
        if (this.get("dnf")) {
          return "DNF";
        }
        if (ms == null) {
          return "N/A";
        }
        ms = Math.round(ms);
        _ref = this.divmod(ms, 1000), s = _ref[0], ms = _ref[1];
        _ref1 = this.divmod(s, 60), m = _ref1[0], s = _ref1[1];
        ft = "" + m + ":" + (this.twoDigits(s)) + "." + (this.threeDigits(ms));
        if (this.get("plus2")) {
          ft += " +2";
        }
        return ft;
      },
      togglePlus2: function() {
        return this.save({
          plus2: !this.get("plus2")
        });
      },
      toggleDnf: function() {
        return this.save({
          dnf: !this.get("dnf")
        });
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
        var attrs, best, dnfs, slice, sum, times, worst;
        attrs = {};
        if (this.length >= n) {
          slice = this.slice(this.length - n, this.length);
          dnfs = _.filter(slice, function(e) {
            return e.get("dnf");
          }).length;
          if (dnfs > 1) {
            attrs.dnf = true;
          } else {
            times = _.reject(slice, function(e) {
              return e.get("dnf");
            }).map(function(e) {
              var ms;
              ms = e.get("ms");
              if (e.get("plus2")) {
                ms += 2000;
              }
              return ms;
            });
            sum = times.reduce((function(a, e) {
              return a + e;
            }), 0);
            best = _.min(times);
            worst = dnfs === 0 ? _.max(times) : 0;
            attrs.ms = (sum - best - worst) / (n - 2);
          }
        }
        return new Time(attrs);
      }
    });
    Times = new TimeList;
    TimeView = Backbone.View.extend({
      tagName: "li",
      template: _.template($("#time-template").html()),
      events: {
        "click .plus2": "onPlus2Click",
        "click .dnf": "onDnfClick",
        "click .remove": "onRemoveClick",
        "click": "onClick"
      },
      initialize: function() {
        this.listenTo(this.model, "change", this.render);
        return this.listenTo(this.model, "destroy", this.remove);
      },
      render: function() {
        this.$el.html(this.template(this.model.toTemplateJSON()));
        return this;
      },
      onClick: function(e) {
        e.preventDefault();
        this.$el.siblings().removeClass("selected");
        return this.$el.toggleClass("selected");
      },
      onPlus2Click: function(e) {
        e.preventDefault();
        e.stopPropagation();
        this.model.togglePlus2();
        return this.$el.removeClass("selected");
      },
      onDnfClick: function(e) {
        e.preventDefault();
        e.stopPropagation();
        this.model.toggleDnf();
        return this.$el.removeClass("selected");
      },
      onRemoveClick: function(e) {
        e.preventDefault();
        e.stopPropagation();
        return this.model.destroy();
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
        "mousedown  #pad": "onPadPress",
        "mouseup    #pad": "onPadRelease",
        "touchstart #pad": "onPadPress",
        "touchend   #pad": "onPadRelease",
        "touchmove  #pad": "onPadMove",
        "click      #puzzles .puzzle": "onClickPuzzle"
      },
      initialize: function() {
        this.$pad = this.$("#pad");
        this.$pad.attr('unselectable', 'on').css('user-select', 'none').on('selectstart', false);
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
        this.generateScramble();
        $(document).keydown(_.bind(this.onPadPress, this));
        return $(document).keyup(_.bind(this.onPadRelease, this));
      },
      render: function() {
        this.$("#average-5").text(Times.average5().formattedTime());
        return this.$("#average-12").text(Times.average12().formattedTime());
      },
      addTime: function(time) {
        var view;
        view = new TimeView({
          model: time
        });
        return this.$("#time-list li:first-child").after(view.render().el);
      },
      onPadPress: function(e) {
        if (e.type === "keydown" && e.keyCode !== 32) {
          return;
        }
        if (this.state === "start") {
          this.state = "pressing";
          this.pressingTo = setTimeout(_.bind(this.onPressingTimeout, this), 400);
          return this.$pad.text("Wait...");
        } else if (this.state === "running") {
          this.state = "finished";
          clearTimeout(this.runningTo);
          this.tick();
          this.$pad.text("Finished");
          return Times.create(this.currentTime.attributes);
        }
      },
      onPadRelease: function(e) {
        if (e.type === "keydown" && e.keyCode !== 32) {
          return;
        }
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
      onPadMove: function(e) {
        if (this.state === "pressing") {
          this.start();
          return clearTimeout(this.pressingTo);
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
        var f, self;
        this.$("#scramble").text("Loading...");
        this.initializedScramblers || (this.initializedScramblers = {});
        if (this.initializedScramblers[localStorage.currentPuzzle]) {
          return this.$("#scramble").text(scramblers[localStorage.currentPuzzle].getRandomScramble().scramble_string);
        } else {
          self = this;
          f = function() {
            var cb;
            cb = function() {
              self.initializedScramblers[localStorage.currentPuzzle] = true;
              return self.generateScramble();
            };
            return scramblers[localStorage.currentPuzzle].initialize(cb, Math);
          };
          return setTimeout(f, 50);
        }
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
