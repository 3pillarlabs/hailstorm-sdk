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