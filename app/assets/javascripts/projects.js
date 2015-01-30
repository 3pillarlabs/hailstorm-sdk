// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

var intervalId = 0;
var projectStatusIntervalId = 0;
var projectDownloadIntervalId = 0;
var continueLogs = false;

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

jQuery(document).ready(clrInterval)
jQuery(document).on('page:load', clrInterval);

function refreshLogs(logsUri)
{
    continueLogs = true;
    intervalId = setInterval(function(){
        if(continueLogs)
        {
            continueLogs = false;
        }
        jQuery.ajax({url:logsUri,success:function(result){
            jQuery("#logsResults").html(result);
        }});
    }, 5000);
}

function updateProject(project_status_uri, project_status)
{
    continueLogs = true;
    projectStatusIntervalId = setInterval(function(){
        if(continueLogs)
        {
            continueLogs = false;
        }
        jQuery.ajax({
            url:project_status_uri,
            success:function(result){
                result = parseInt(result);

                project_status_val = project_status_str(result);

                jQuery("#project_status").html(project_status_val);

                if(project_status_val == "Configured")
                {
                    jQuery("#project_setup").removeClass( "disabled" );
                }

                if(project_status_val == "Ready to start")
                {
                    jQuery("#project_start").removeClass( "disabled" );
                    jQuery("#project_terminate").removeClass( "disabled" );
                }

                if(project_status_val == "Started")
                {
                    jQuery("#project_abort").removeClass( "disabled" );
                    jQuery("#project_terminate").removeClass( "disabled" );
                }

                if(project_status_val == "Stopped" || project_status_val == "Aborted")
                {
                    jQuery("#project_start").removeClass( "disabled" );
                    jQuery("#project_terminate").removeClass( "disabled" );
                }

                if(project_status_val == "Stopped")
                {
                    $("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>Please check results.</div>');

                    //send ajax call to update results
                    last_result_id = $("#last_result_id").html();
                    update_results_uri = $("#update_results_data_uri").html();
                    update_results_uri = update_results_uri+"?resultid="+last_result_id;

                    jQuery.ajax({url:update_results_uri, dataType : 'json', success:function(result){

                        if(result.length != 0)
                        {
                            var result_str = '';
                            var last_resultid = '';
                            $.each(result, function(index, element) {
                                last_resultid = element.id;

                                result_str += '<tr>'+
                                    '<td><input type="checkbox" class="testsCheck" name="load_test[]" value="'+element.execution_cycle_id+'"></td>'+
                                    '<td>'+element.total_threads_count+'</td>'+
                                    '<td>'+element.avg_90_percentile.toFixed(1)+'</td>'+
                                    '<td>'+element.avg_tps+'</td>'+
                                    '<td>'+element.started_at+'</td>'+
                                    '<td>'+element.stopped_at+'</td>';

                            });

                            $("#project_results_div").append(result_str);
                            $("#last_result_id").html(last_resultid);
                        }

                    }});
                }

        }});
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

        request_id = $("#download_request_id").html();
        if(request_id!="")
        {
            check_download_status_uri = check_download_status_uri+"?request_id="+request_id;

            jQuery.ajax({
                url:check_download_status_uri,
                success:function(result){
                    result = parseInt(result);

                    if(result==1)
                    {
                        $("#download_request_id").html("");
                        download_link_uri = $("#download_result_uri").html()+"?request_id="+request_id;
                        download_status_str = '<a href="'+download_link_uri+'" class="btn btn-success"><span aria-hidden="true" class="glyphicon glyphicon-save"></span> Download</a>';

                        $("#project_download_status").html(download_status_str);

                        $("#download-reports").removeClass( "disabled" );
                        $("#export-reports").removeClass( "disabled" );
                    }

                }});
        }

    }, 60000);
}

function project_status_str(status)
{
    status_str = "";
    switch(status) {
        case 1:
            status_str = "Partial Configured";
            break;
        case 2:
            status_str = "Configured";
            break;
        case 3:
            status_str = "Setup in progress";
            break;
        case 4:
            status_str = "Ready to start";
            break;
        case 5:
            status_str = "Started";
            break;
        case 6:
            status_str = "Stopped";
            break;
        case 7:
            status_str = "Aborted";
            break;
        default:
            status_str = "Empty";
    }

    return status_str;
}

var do_on_load = function() {
    // do some things

    $("#checkUncheckAll").on("click", function() {
        $(".testsCheck").prop("checked", $(this).prop("checked"));
    });

    $(".worker_task").on("click", function(event) {
        var action_id_str = $(this).attr('id');
        if(action_id_str=="project_abort" || action_id_str=="project_terminate")
        {
            if(confirm("Are you sure! you want to "+action_str))
            {
                alert(action_str);
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
                    $(".worker_task").addClass( "disabled" );
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
                    $("#project_download_status").html('Preparing Download... <img src="/assets/roller.gif" />');

                    jQuery("#flash_messages").html('<div class="alert alert-info fade in"><button data-dismiss="alert" class="close">x</button>'+message+'</div>');
                },
                error: function() {
                    jQuery("#flash_messages").html('<div class="alert alert-danger fade in"><button data-dismiss="alert" class="close">x</button>An error occurred! please try again.</div>');
                }
            });
        }

    }


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

