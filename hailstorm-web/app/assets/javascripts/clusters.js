var Hailstorm = Hailstorm || {};
Hailstorm.Cluster = {};

/**
 * Adds text-boxes for adding additional hosts when defining a data center cluster
 */
Hailstorm.Cluster.addMachinesFields = function() {
    var cluster_type = arguments.length > 0 ? arguments[0] : 'data_center';
    var selector = arguments.length > 1 ? $(arguments[1]) : $("#cluster_machines");
    var countAddedInputs = selector.find('span[data-clusterMachine="true"]').length;
    var propertiesHTML =
        '<span data-clusterMachine="true" data-cmIndex="' + countAddedInputs + '">' +
            '<br/>' +
            '<div class="row">' +
                '<div class="col-sm-11">' +
                    '<input type="text" name="' + cluster_type + '[machines][]" class="form-control" placeholder="IP address or host name" />' +
                '</div>' +
                '<div class="col-sm-1">' +
                    '<button type="button" tabindex="-1" class="close" data-cmRemove="cm-' + countAddedInputs + '" aria-label="Close">' +
                        '<span aria-hidden="true">&times;</span>' +
                    '</button>' +
                '</div>' +
            '</div>' +
        '</span>';
    selector.append(propertiesHTML);
    $('button.close[data-cmRemove="cm-' + countAddedInputs + '"]').click(function(event) {
        event.preventDefault();
        event.stopPropagation();
        $('span[data-clusterMachine="true"][data-cmIndex="' + countAddedInputs + '"]').remove();
    });
};

Hailstorm.Cluster.removeHostRow = function(index) {
    $('span[data-clusterMachine="true"][data-cmIndex="' + index + '"]').remove();
};

Hailstorm.Cluster.instanceTypeChooser = function(tpaMatrix) {
    // 'this' refers to the element
    var htmlOpts = this.options;
    var selectedValue = htmlOpts[htmlOpts.selectedIndex].value;
    if (!selectedValue) {
        var id = $(this).attr("id");
        $(this).attr("disabled", true).addClass("hidden");
        $("input#" + id).attr("disabled", false).removeClass("hidden");
    } else {
        $("#amazon_cloud_max_threads_per_agent").val(tpaMatrix[selectedValue]);
    }
};

Hailstorm.Cluster.changeKeysHandler = function(event) {
    event.stopPropagation();
    event.preventDefault();
    $("div.keys-form-group").removeClass("hidden");
    $("div.keys-form-group input").val("").attr("disabled", false);
};