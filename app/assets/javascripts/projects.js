// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

if (window.Hailstorm === undefined) {
    window.Hailstorm = {};
}

Hailstorm.Project = {
    appendLog: function(data) {
        var contentLen = data.trim().length;
        if (contentLen > 0) {
            logOffset += data.length;
            // auto-scroll
            var appender = jQuery("#logsResults");
            appender.append(data.replace(/\n/g, '<br/>'));
            var sch = appender.prop("scrollHeight");
            var h = appender.height();
            if (sch > h) {
                appender.animate({scrollTop: sch});
            }
        }
    },

    synchProjectState: function(result) {
        jQuery("#project_status").html(result.state_title);
        var state_code = result.state_code;
        var triggers = result.state_triggers;
        anythingInProgress = result.any_op_in_progress;

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

        if (state_code == "ready_start")
        {
            $("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>Please check results.</div>');

            //send ajax call to update results
            var last_result_id = $("#last_result_id").html();
            var update_results_uri = $("#update_results_data_uri").html();
            var update_results_uri = update_results_uri+"?resultid="+last_result_id;

            jQuery.ajax({url:update_results_uri, dataType : 'json', success:function(result){

                if(result.length != 0)
                {
                    var result_str = '';
                    var last_resultid = '';
                    jQuery.each(result, function(index, element) {
                        last_resultid = element.id;

                        result_str += '<div class="row">'+
                        '<div class="col-md-1"><input type="checkbox" class="testsCheck" name="load_test[]" value="'+element.execution_cycle_id+'"></div>'+
                        '<div class="col-md-11">'+
                        '<div class="row">'+
                        '<div class="col-md-7">'+element.total_threads_count+' Threads</div>'+
                        '<div class="col-md-5">'+
                        '<div class="row">'+
                        '<div class="col-md-5">'+element.started_at_date+'<br/>'+element.started_at_time+'</div>'+
                        '<div class="col-md-2">-</div>'+
                        '<div class="col-md-5">'+element.stopped_at_date+'<br/>'+element.stopped_at_time+'</div>'+
                        '</div>'+
                        '</div>'+
                        '</div>'+
                        '<div class="row">'+
                        '<div class="col-md-7">'+element.avg_90_percentile.toFixed(1)+' ms Response Time</div>'+
                        '<div class="col-md-5">'+element.avg_tps+' TPS</div>'+
                        '</div>'+
                        '</div>'+
                        '</div>'+
                        '<hr>';
                    });

                    jQuery("#project_results_div").append(result_str);
                    jQuery("#last_result_id").html(last_resultid);
                }

            }});
        }

        if (result.state_reason) {
            jQuery("#flash_messages").html('<div class="danger alert-danger fade in"><button data-dismiss="danger" class="close">x</button>An error occurred - ' + result.state_reason + '</div>');
        }
    },

    updateTestResults: function(result, request_id) {
        result = parseInt(result);
        console.debug("result: " + result);
        if (result == 1)
        {
            $("#download_request_id").html("");
            download_link_uri = $("#download_result_uri").html()+"?request_id="+request_id;
            download_status_str = '<a href="'+download_link_uri+'" class="btn btn-success"><span aria-hidden="true" class="glyphicon glyphicon-save"></span> Download</a>';

            $("#project_download_status").html(download_status_str);

            $("#download-reports").removeClass( "disabled" );
            $("#export-reports").removeClass( "disabled" );
        }
    }
};



var intervalId = 0;
var projectStatusIntervalId = 0;
var projectDownloadIntervalId = 0;
var continueLogs = false;
var logOffset = 0;
var anythingInProgress = false;

function clrInterval()
{
    if(continueLogs == false)
    {
        if(intervalId > 0)
        {
            clearInterval(intervalId);
            intervalId = 0;
        }

        if(projectStatusIntervalId > 0)
        {
            clearInterval(projectStatusIntervalId);
            projectStatusIntervalId = 0;
        }

        if(projectDownloadIntervalId > 0)
        {
            clearInterval(projectDownloadIntervalId);
            projectDownloadIntervalId = 0;
        }
    }
}

jQuery(document).ready(clrInterval);
jQuery(document).on('page:load', clrInterval);

function refreshLogs(logsUri) {
    continueLogs = true;
    intervalId = setInterval(function(){
        if(continueLogs)
        {
            continueLogs = false;
        }

        if (anythingInProgress) {
            jQuery.ajax(logsUri, {
                data: {offset: logOffset},
                success: Hailstorm.Project.appendLog
            });
        }
    }, 30000);
}

function updateProject(project_status_uri)
{
    continueLogs = true;
    projectStatusIntervalId = setInterval(function(){
        if(continueLogs)
        {
            continueLogs = false;
        }
        if (anythingInProgress) {
            jQuery.getJSON(project_status_uri, Hailstorm.Project.synchProjectState);
        }
    }, 60000);
}

function checkDownloadStatus(check_download_status_uri)
{

    continueLogs = true;
    projectDownloadIntervalId = setInterval(function(){
        if(continueLogs)
        {
            continueLogs = false;
        }

        var request_id = $("#download_request_id").html();
        if (request_id != "")
        {
            check_download_status_uri = check_download_status_uri+"?request_id="+request_id;

            jQuery.ajax({
                url: check_download_status_uri,
                success: function(data) {
                    Hailstorm.Project.updateTestResults(data, request_id)
                }
            });
        }

    }, 60000);
}

var do_on_load = function() {
    // do some things

    $("#checkUncheckAll").on("click", function() {
        $(".testsCheck").prop("checked", $(this).prop("checked"));
    });

    $(".worker_task").on("click", function(event) {
        var action_id_str = $(this).attr('id');

        if (action_id_str == "project_abort" || action_id_str == "project_terminate" || action_id_str == "project_stop")
        {
            var action_str = $(this).text().trim().toLowerCase();
            if(confirm("Are you sure! you want to " + action_str))
            {
                $.ajax({
                    url : $(this).attr('href'),
                    dataType : 'json',
                    success:function(result){
                        $("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>'+result['data']+'</div>');
                        $(".worker_task").addClass( "disabled" );
                    },
                    error: function() {
                        $("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>An error occurred! please try again.</div>');
                    }
                });
            }
        }
        else
        {
            $.ajax({
                url : $(this).attr('href'),
                dataType : 'json',
                success:function(result){
                    $("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>'+result['data']+'</div>');
                    Hailstorm.Project.synchProjectState(result);
                },
                error: function() {
                    $("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>An error occurred! please try again.</div>');
                }
            });
        }

        return false;
    });

    function getCheckedResultsIds()
    {
        var checkedValues = $('.testsCheck:checked').map(function() {
            return this.value;
        }).get();
        return checkedValues;
    }

    function getTestResults(url, type)
    {
        ids = getCheckedResultsIds();

        if(ids.length == 0 )
        {
            jQuery("#flash_messages").html('<div class="alert alert-danger fade in"><button data-dismiss="alert" class="close">x</button>Please select results to '+type+'.</div>');
        }
        else
        {
            $("#download-reports").addClass( "disabled" );
            $("#export-reports").addClass( "disabled" );
            var message = "Request for report "+type+" has been submitted, please wait while the request is processing."
            jQuery.ajax({
                url : url+"&ids="+ids,
                dataType : 'json',
                success:function(result){
                    $("#download_request_id").html(result['request_id']);
                    $("#project_download_status").html('<img src="/assets/roller.gif" />');

                    jQuery("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>'+message+'</div>');
                },
                error: function() {
                    jQuery("#flash_messages").html('<div class="alert alert-danger fade in"><button data-dismiss="alert" class="close">x</button>An error occurred! please try again.</div>');
                }
            });
        }

    };


    jQuery("#download-reports").click(function(event){
        var url = jQuery(this).attr('href');
        getTestResults(url, 'download');
        event.preventDefault();
    });



    jQuery("#export-reports").click(function(event){
        var url = jQuery(this).attr('href');
        getTestResults(url, 'export');
        event.preventDefault();
    });

}
//$(document).ready(do_on_load)
$(window).bind('page:change', do_on_load);

