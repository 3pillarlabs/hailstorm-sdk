function add_machines_fields(cluster_type)
{
    var propertiesHTML = '<div class="panel"><input type="text" name="'+cluster_type+'[machines][]" class = "form-control" placeholder="Enter IP address of machine"></div>';
    jQuery("#cluster_machines").append(propertiesHTML);
}

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