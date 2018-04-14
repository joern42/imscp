
<form method="post">
    <label for="ip_address">{TR_DROPDOWN_LABEL}</label>
    <select id="ip_address" name="ip_address" onchange="this.form.submit()">
        <!-- BDP: ip_entry -->
        <option value="{IP_VALUE}"{IP_SELECTED}>{IP_NUM}</option>
        <!-- EDP: ip_entry -->
    </select>
</form>
<!-- BDP: no_assignments_msg -->
<div class="static_info">{TR_IP_NOT_ASSIGNED_YET}</div>
<!-- EDP: no_assignments_msg -->
<!-- BDP: assignment_rows -->
<table class="firstColFixed">
    <thead>
    <tr>
        <th>{TR_CUSTOMER_NAMES}</th>
    </tr>
    </thead>
    <tbody>
    <!-- BDP: assignment_row -->
    <tr>
        <td>{CUSTOMER_NAMES}</td>
    </tr>
    <!-- EDP: assignment_row -->
    </tbody>
</table>
<!-- EDP: assignment_rows -->
