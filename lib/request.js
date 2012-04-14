(function() {
  var AtArrayRequest, AtRequest, BetweenRequest, GuidedRequest, PreviousToCurrentRequest, Request, TimeInStateRequest, root;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  root = this;

  Request = (function() {

    function Request() {
      var a;
      a = 'test';
    }

    return Request;

  })();

  GuidedRequest = (function() {

    __extends(GuidedRequest, Request);

    function GuidedRequest() {
      GuidedRequest.__super__.constructor.apply(this, arguments);
    }

    return GuidedRequest;

  })();

  AtRequest = (function() {

    __extends(AtRequest, GuidedRequest);

    function AtRequest() {
      AtRequest.__super__.constructor.apply(this, arguments);
    }

    return AtRequest;

  })();

  AtArrayRequest = (function() {

    __extends(AtArrayRequest, GuidedRequest);

    function AtArrayRequest() {
      AtArrayRequest.__super__.constructor.apply(this, arguments);
    }

    return AtArrayRequest;

  })();

  BetweenRequest = (function() {

    __extends(BetweenRequest, GuidedRequest);

    function BetweenRequest() {
      BetweenRequest.__super__.constructor.apply(this, arguments);
    }

    return BetweenRequest;

  })();

  TimeInStateRequest = (function() {

    __extends(TimeInStateRequest, GuidedRequest);

    function TimeInStateRequest() {
      TimeInStateRequest.__super__.constructor.apply(this, arguments);
    }

    return TimeInStateRequest;

  })();

  PreviousToCurrentRequest = (function() {

    __extends(PreviousToCurrentRequest, GuidedRequest);

    function PreviousToCurrentRequest() {
      PreviousToCurrentRequest.__super__.constructor.apply(this, arguments);
    }

    return PreviousToCurrentRequest;

  })();

  root.Request = Request;

  root.GuidedRequest = GuidedRequest;

  root.AtRequest = AtRequest;

  root.AtArrayRequest = AtArrayRequest;

  root.BetweenRequest = BetweenRequest;

  root.TimeInStateRequest = TimeInStateRequest;

  root.PreviousToCurrentRequest = PreviousToCurrentRequest;

}).call(this);
