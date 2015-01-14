// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.


var intervalId = 0;
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
    }
}

jQuery(document).ready(clrInterval)
jQuery(document).on('page:load', clrInterval)

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

jQuery(document).ready(function(){
    jQuery("#checkUncheckAll").click(function(){
        jQuery('.testsCheck').prop('checked', jQuery('#checkUncheckAll').is(":checked"));
    });
});








