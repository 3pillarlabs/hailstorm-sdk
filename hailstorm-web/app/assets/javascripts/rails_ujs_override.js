/**
 * Created by sayantamd on 29/5/15.
 */

// Override default confirm dialog from Rails with modal from BS
$.rails.allowAction = function(element) {
    // "click.rails" handler invokes allowAction after it is triggered from $.rails.confirm
    if (element.data("confirm") == undefined || element.data("referrer") == '$.rails.confirm') {
        element.data("referrer", null);
        return true;
    }

    $.rails.confirm(element);
    return false;
};

/**
 * Data attributes:
 *   confirm - the message to show
 *   confirm-title - if provided, this is the modal header
 *   confirm-context - if provided, this is the modal header context (as per BS foreground contextual colors)
 *
 * @param element
 * @returns {boolean}
 */
$.rails.confirm = function(element) {
    var message = element.data("confirm");
    $("#application_modal .modal-body").html(message);
    var title = element.data("confirm-title") || "Warning";
    $("#application_modal .modal-header").html('<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button><h4 class="modal-title">' + title + '</h4>');
    var context = element.data("confirm-context") || "danger";
    $("#application_modal .modal-header h4.modal-title").addClass("text-" + context);
    $('#application_modal a[href="#yes"]').one("click", function(event) {
        event.stopPropagation();
        event.preventDefault();

        $("#application_modal").modal("hide");
        element.data("referrer", "$.rails.confirm"); // avoid infinite loop
        element.trigger("click.rails"); // let through desired behavior
    });
    $("#application_modal").one("hidden.bs.modal", function() {
        $("#application_modal .modal-body").html('');
        $("#application_modal .modal-header").html('');
        $('#application_modal a[href="#yes"]').unbind();
    });

    $("#application_modal").modal("show");
    return false;
};