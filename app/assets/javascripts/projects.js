// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

var intervalId = 0;
var projectStatusIntervalId = 0;
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

                if(project_status_val == "ready to start")
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
                }

        }});
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
            status_str = "ready to start";
            break;
        case 4:
            status_str = "Started";
            break;
        case 5:
            status_str = "Stopped";
            break;
        case 6:
            status_str = "Aborted";
            break;
        default:
            status_str = "Empty";
    }

    return status_str;
}

var do_on_load = function() {
    // do some things
    //alert('here the code');

    $("#checkUncheckAll").on("click", function() {
        $(".testsCheck").prop("checked", $(this).prop("checked"));
    });

    $(".worker_task").on("click", function() {
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
        return false;
    });

}
//$(document).ready(do_on_load)
$(window).bind('page:change', do_on_load)