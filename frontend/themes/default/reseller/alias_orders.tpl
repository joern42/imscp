
<script>
    $(function () {
        var $dataTable = $(".datatable").dataTable({
            language: imscp_i18n.core.dataTable,
            displayLength: 10,
            processing: true,
            serverSide: true,
            ajaxSource: "alias_orders.php",
            stateSave: true,
            pagingType: "simple",
            columnDefs: [
                { type: 'natural', targets: [0]},
                { sortable: false, searchable: false, targets: [4] }
            ],
            columns: [{ data: "alias_name" }, { data: "alias_mount" }, { data: "url_forward" }, { data: "admin_name" }, { data: "actions" }],
            fnServerData: function (source, data, callback) {
                $.ajax({
                    dataType: "json",
                    type: "GET",
                    url: source,
                    data: data,
                    success: callback,
                    timeout: 5000
                }).done(function () {
                    $dataTable.find("a").tooltip( { tooltipClass: "ui-tooltip-notice", track: true });
                });
            }
        });
    });

    function reject_alias_order(link, name) {
        return jQuery.imscp.confirmOnclick(link, sprintf(imscp_i18n.core.reject_domain_alias_order, name));
    }
</script>
<table class="datatable">
    <thead>
    <tr>
        <th>{TR_ALIAS_NAME}</th>
        <th>{TR_MOUNT_POINT}</th>
        <th>{TR_FORWARD_URL}</th>
        <th>{TR_CUSTOMER}</th>
        <th>{TR_ACTIONS}</th>
    </tr>
    </thead>
    <tbody>
    <tr>
        <td colspan="5" class="dataTables_empty">{TR_PROCESSING}</td>
    </tr>
    </tbody>
</table>
