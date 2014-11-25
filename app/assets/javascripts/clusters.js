function add_machines_fields()
{
    var propertiesHTML = '<div class="panel"><input type="text" name="cluster[machines][]" class = "form-control" placeholder="Enter IP address of machine"></div>';
    jQuery("#cluster_machines").append(propertiesHTML);
}

//jQuery( document ).ready(function() {
//    jQuery("#cluster_name_amazon_cloud").click(function(){ jQuery("#datacenter-form").hide(); jQuery("#amazon-form").show(); });
//    jQuery("#cluster_name_data_center").click(function(){ jQuery("#datacenter-form").show(); jQuery("#amazon-form").hide(); });
//});


function changeClusterType(clusterType)
{
    if(clusterType == "amazon_cloud")
    {
        jQuery("#datacenter-form").hide(); jQuery("#amazon-form").show();
    }
    else if(clusterType == "data_center")
    {
        jQuery("#datacenter-form").show(); jQuery("#amazon-form").hide();
    }
}