function add_property_fields()
{
    var propertiesHTML = '<tr>'+
        '<td>'+
        '<input type="text" name="test_plan[property_name][]">'+
        '</td>'+
        '<td>'+
        '<input type="text" name="test_plan[property_value][]">'+
        '</td>'+
        '</tr>';
    jQuery("#test_plan_properties_body").append(propertiesHTML);
}