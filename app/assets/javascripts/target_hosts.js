// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

function add_host_fields(role_key)
{
    //alert("host  "+role_key);
    var propertiesHTML = '<div class="col-md-offset-1 col-md-12">'+
        '<label for="target_host_host_name">Host name</label>'+
        '</div>'+
        '<div class="col-md-offset-1 col-md-9">'+
        '<input type="text" placeholder="Enter host name" class="form-control" name="target_host[host_name]['+role_key+'][]">'+
        '</div>';
    jQuery("#host_name_placeholder"+role_key).append(propertiesHTML);
}

function add_role_host_fields()
{
    var roles_count = jQuery("#role_count").val();
    roles_count = parseInt(roles_count)+1;
    //alert("roles  "+roles_count);
    var htmlProperties = '<div class="row">'+
        '<div class="col-md-12">'+
        '<div class="col-md-11">'+
        '<label for="target_host_role_name">Role name</label>'+
        '</div>'+
        '<div class="col-md-1">&nbsp;</div>'+
        '</div>'+
        '<div class="col-md-12">'+
        '<div class="col-md-11">'+
        '<input type="text" placeholder="Enter role name" class="form-control" name="target_host[role_name]['+roles_count+']">'+
        '</div>'+
        '<div class="col-md-1">&nbsp;</div>'+
        '</div>'+
        '</div>'+
        '<div class="row" id="host_name_placeholder'+roles_count+'">'+
        '<div class="col-md-offset-1 col-md-12">'+
        '<label for="target_host_host_name">Host name</label>'+
        '</div>'+
        '<div class="col-md-offset-1 col-md-9">'+
        '<input type="text" placeholder="Enter host name" class="form-control" name="target_host[host_name]['+roles_count+'][]">'+
        '</div>'+
        '<div class="col-md-2">'+
        '<a onclick="add_host_fields('+roles_count+');" href="javascript:void(0);" class="btn btn-info btn-xs"><span aria-hidden="true" class="glyphicon glyphicon-plus"></span></a>'+
        '</div>'+
        '</div>';

    jQuery("#role_host_group_placeholder").append(htmlProperties);
    jQuery("#role_count").val(roles_count);
}

