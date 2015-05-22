// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

var Hailstorm = Hailstorm || {};
Hailstorm.Project = {};

Hailstorm.Project.Tracker = function(options) {
    this.readLogsPath = options.readLogsPath;
    this.projectStatusPath = options.projectStatusPath;
    this.downloadStatusPath = options.downloadStatusPath;
    this.anythingInProgress = options.anythingInProgress;
    this.logOffset = options.logOffset;
    this.updateResultsPath = options.updateResultsPath;
    this.generatedReportsPath = options.generatedReportsPath;

    this.projectStatusIntervalId = 0;
    this.downloadStatusIntervalId = 0;
    this.refreshLogsIntervalId = 0;

    this.alertCloseBtnMarkup = '<button type="button" data-dismiss="alert" class="close" aria-label="Close"><span aria-hidden="true" class="small">&times;</span></button>';
};

Hailstorm.Project.Tracker.prototype.start = function() {

    var self = this;
    this.clrInterval();
    jQuery(document).ready(this.clrInterval.apply(this));
    jQuery(document).on('page:load', this.clrInterval.apply(this));

    // check/uncheck all for test results
    $("#checkUncheckAll").on("click", function() {
        $(".testsCheck").prop("checked", $(this).prop("checked"));
    });

    // set up handlers for triggers
    $(".worker_task").on("click", function(event) {
        self.handleTaskTriggers(this);
        event.preventDefault();
        event.stopPropagation();
    });

    $("#download-reports").click(function(event) {
        var url = jQuery(this).attr('href');
        self.getTestResults(url, 'download');
        event.preventDefault();
        event.stopPropagation();
    });

    $("#export-reports").click(function(event) {
        var url = jQuery(this).attr('href');
        self.getTestResults(url, 'export');
        event.preventDefault();
        event.stopPropagation();
    });

    if (this.anythingInProgress) {
        this.projectStatusIntervalId = window.setInterval(this.periodicProjectSync.bind(this), 60000);
        this.refreshLogsIntervalId = window.setInterval(this.refreshLogs.bind(this), 10000);
    }

    // listen for closed alerts and replace with original content
    $(document).on("close.bs.alert", function() {
       $("#project_fm").html('<br/><br/><br/>');
    });

    $('a[data-toggle="tab"]').on("show.bs.tab", function(event) {
        var tabContentId = $(event.target).attr("aria-controls");
        if (tabContentId == "gen_reports") {
            self.showGeneratedReports();
        }
    });
};

Hailstorm.Project.Tracker.prototype.showError = function(message) {
    var messageText = '<div class="alert alert-danger fade in">' +
        this.alertCloseBtnMarkup + ' An error occurred';
    if (message) {
        messageText += ': ' + message;
    }
    messageText += '. Please try again.</div>';
    $("#project_fm").html(messageText);
};

Hailstorm.Project.Tracker.prototype.showSuccess = function(message) {
    var messageText = '<div class="alert alert-success fade in">' + this.alertCloseBtnMarkup + ' ' + message + '</div>';
    $("#project_fm").html(messageText);
};

Hailstorm.Project.Tracker.prototype.showInfo = function(message) {
    var messageText = '<div class="alert alert-info fade in">' + this.alertCloseBtnMarkup + ' ' + message + '</div>';
    $("#project_fm").html(messageText);
};

Hailstorm.Project.Tracker.prototype.showWarn = function(message) {
    var messageText = '<div class="alert alert-warning fade in">' + this.alertCloseBtnMarkup + ' ' + message + '</div>';
    $("#project_fm").html(messageText);
};

Hailstorm.Project.Tracker.prototype.clrInterval = function() {

    if (this.projectStatusIntervalId > 0) {
        window.clearInterval(this.projectStatusIntervalId);
        this.projectStatusIntervalId = 0;
    }

    if (this.downloadStatusIntervalId > 0) {
        window.clearInterval(this.downloadStatusIntervalId);
        this.downloadStatusIntervalId = 0;
    }

    if (this.refreshLogsIntervalId > 0) {
        window.clearInterval(this.refreshLogsIntervalId);
        this.refreshLogsIntervalId = 0;
    }
};

Hailstorm.Project.Tracker.prototype.refreshLogs = function() {

    jQuery.ajax(this.readLogsPath, {
        data: {offset: this.logOffset},
        success: this.appendLog.bind(this)
    });
};

Hailstorm.Project.Tracker.prototype.periodicProjectSync = function() {

    var self = this;
    jQuery.getJSON(this.projectStatusPath, function(data) {
        self.synchProjectState(data);
    });
};

Hailstorm.Project.Tracker.prototype.checkDownloadStatus = function() {

    var self = this;
    if (this.downloadRequestId) {
        jQuery.ajax({
            url: this.downloadStatusPath,
            data: {request_id: this.downloadRequestId},
            success: function(data) {
                self.updateTestResults(data);
            }
        });
    }
};

Hailstorm.Project.Tracker.prototype.handleTaskTriggers = function(trigger) {

    var self = this;
    var actionCode = $(trigger).attr('id');
    this.lastActionCode = actionCode;
    if (actionCode == "project_abort" || actionCode == "project_terminate" || actionCode == "project_stop") {

        var modalSelector = "#" + actionCode + "-confirm-modal";
        $(modalSelector).modal("show");
        var modalOkSelector = modalSelector + " a.btn-danger";
        var yesFn = function(event) {
            event.preventDefault();
            event.stopPropagation();
            $(modalSelector).modal("hide");
            $.ajax({
                url : $(trigger).attr("href"),
                dataType : "json",
                success: function(result){
                    self.synchProjectState(result);
                    self.showInfo("Proceeding with " + actionCode.split("_")[1] + "...");
                },
                error: self.showError.apply(self)
            });
        };

        $(modalOkSelector).one("click", yesFn);
    } else {
        $.ajax({
            url : $(trigger).attr("href"),
            dataType : "json",
            success:function(result){
                self.synchProjectState(result);
                var msg = (actionCode == "project_setup" ? "The load testing environment is being setup and make take a long time. Once setup completes, this page will be auto-updated." : "Your tests will start in a short while.");
                self.showInfo(msg);
            },
            error: self.showError.apply(self)
        });
    }

    return false;
};

Hailstorm.Project.Tracker.prototype.getCheckedResultsIds = function() {
    return $('.testsCheck:checked').map(function() {
        return this.value;
    }).get();
};

Hailstorm.Project.Tracker.prototype.getTestResults = function(url, type) {

    var self = this;
    var ids = this.getCheckedResultsIds();
    if (ids.length > 0 ) {
        $("#download-reports").addClass( "disabled" );
        $("#export-reports").addClass( "disabled" );
        var message = "Request for report "+type+" has been submitted, please wait while the request is processing.";
        jQuery.ajax({
            url : url,
            data: {ids: ids},
            dataType : 'json',
            success: function(result) {
                self.downloadRequestId = result['request_id'];
                // when the gen_reports tab is shown, self.showGeneratedReports will
                // trigger an event after showing existing reports. Add a one time
                // listener for this event to add in progress message.
                $(document).one("hailstorm:event:gen_reports_showed", function() {
                    $("#generated_reports").prepend('<div id="gen_report_progress"><span class="fa fa-cog fa-spin"></span> Generating report...</div><br/>');
                });

                $('a[href="#gen_reports"]').tab('show');
                self.showInfo(message);
                $(".testsCheck").prop("checked", false);
                $("#checkUncheckAll").prop("checked", false);
                self.downloadStatusIntervalId = window.setInterval(self.checkDownloadStatus.bind(self), 5000);
                self.refreshLogsIntervalId = window.setInterval(self.refreshLogs.bind(self), 1000);
            },
            error: self.showError.apply(self)
        });
    } else {
        this.showWarn("Please select results to " + type + ".");
    }
};

Hailstorm.Project.Tracker.prototype.appendLog = function(data) {

    var contentLen = data.trim().length;
    if (contentLen > 0) {
        this.logOffset += data.length;
        // auto-scroll
        var appender = jQuery("#logsResults");
        appender.append(data.replace(/\n/g, "<br/>"));
        var sch = appender.prop("scrollHeight");
        var h = appender.height();
        if (sch > h) {
            appender.animate({scrollTop: sch});
        }
    }
};

Hailstorm.Project.Tracker.prototype.synchProjectState = function(result) {

    var stateCode = result.state_code;
    var triggers = result.state_triggers;
    var shaking = result.any_op_in_progress;

    // start all kinds of refreshers if it shaking or clear them
    if (shaking) {
        if (this.projectStatusIntervalId == 0) {
            this.projectStatusIntervalId = window.setInterval(this.periodicProjectSync.bind(this), 60000);
        }

        if (this.refreshLogsIntervalId == 0) {
            this.refreshLogsIntervalId = window.setInterval(this.refreshLogs.bind(this), 10000);
        }
    } else {
        window.clearInterval(this.projectStatusIntervalId);
        this.projectStatusIntervalId = 0;
        window.clearInterval(this.refreshLogsIntervalId);
        this.refreshLogsIntervalId = 0;
    }

    var statusHtml = null;
    var stateIcon = null;
    if (stateCode == "empty") {
        stateIcon = "glyphicon glyphicon-unchecked";
    } else if (stateCode == "partial_configured") {
        stateIcon = "glyphicon glyphicon-edit";
    } else if (stateCode == "configured") {
        stateIcon = "glyphicon glyphicon-check";
    } else if (stateCode == "ready_start") {
        stateIcon = "glyphicon glyphicon-send";
    } else {
        statusHtml = '<i class="fa fa-cog fa-spin"></i> ' + result.state_title;
    }

    if (stateIcon) {
        statusHtml = '<span class="' + stateIcon + '"></span> ' + result.state_title;
    }

    jQuery("#project_status").html(statusHtml);

    if (triggers.setup) {
        jQuery("#project_setup").removeClass( "disabled" );
    } else {
        jQuery("#project_setup").addClass( "disabled" );
    }

    if (triggers.start) {
        jQuery("#project_start").removeClass( "disabled" );
    } else {
        jQuery("#project_start").addClass( "disabled" );
    }

    if (triggers.stop) {
        jQuery("#project_stop").removeClass( "disabled" );
    } else {
        jQuery("#project_stop").addClass( "disabled" );
    }

    if (triggers.abort) {
        jQuery("#project_abort").removeClass( "disabled" );
    } else {
        jQuery("#project_abort").addClass( "disabled" );
    }

    if (triggers.term) {
        jQuery("#project_terminate").removeClass( "disabled" );
    } else {
        jQuery("#project_terminate").addClass( "disabled" );
    }

    if (this.lastActionCode == "project_start") {
        if (stateCode == "ready_start") {
            var self = this;
            // send ajax call to update results
            jQuery.ajax({url: this.updateResultsPath, success: function(result) {
                $("#project_results").html(result);
                $('#result_options a[href="#test_results"]').tab('show');
                self.showSuccess("Test results for run added.");
            }});
        } else if (stateCode == "started") {
            this.showSuccess("Tests have been started.");
        } else if (stateCode == "stop_progress") {
            this.showInfo("Tests have concluded, fetching test results...");
        }
    }

    if (result.state_reason) {
        this.showError(result.state_reason);
    }
};

Hailstorm.Project.Tracker.prototype.updateTestResults = function(result) {

    var self = this;
    result = parseInt(result);
    if (result == 1) {
        this.downloadRequestId = null;
        this.showGeneratedReports(function() {
            $("#download-reports").removeClass( "disabled" );
            $("#export-reports").removeClass( "disabled" );
            self.showSuccess("Report generation completed.");
            self.clrInterval();
        });
    }
};

// optional argument - a function pointer to apply on success
Hailstorm.Project.Tracker.prototype.showGeneratedReports = function() {
    var onSuccess = arguments.length > 0 ? arguments[0] : null;
    $.get(this.generatedReportsPath)
        .done(function(data) {
            $("#generated_reports").html(data);
            if (onSuccess) {
                onSuccess();
            }

            $(document).trigger("hailstorm:event:gen_reports_showed");
        });
};
