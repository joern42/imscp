
<script>
    $(function () {
        $("#lostpassword,#passwd_strong,#bruteforce").change(function () {
            if ($(this).val() == '1') {
                $(this).parents().nextAll(".display").show();
            } else {
                $(this).parents().nextAll(".display").hide();
            }
        }).trigger('change');
    });
</script>
<table class="firstColFixed">
    <thead>
    <tr>
        <th colspan="2">{TR_ACCOUNT}</th>
    </tr>
    </thead>
    <tbody>
    <tr>
        <td>{TR_ACCOUNT_NAME}</td>
        <td>{VL_ACCOUNT_NAME}</td>
    </tr>
    <tr>
        <td>{TR_ACCOUNT_EXPIRY_DATE}</td>
        <td>{VL_ACCOUNT_EXPIRY_DATE}</td>
    </tr>
    <tr>
        <td>{TR_PRIMARY_DOMAIN_NAME}</td>
        <td>{VL_PRIMARY_DOMAIN_NAME}</td>
    </tr>
    <tr>
        <td>{TR_CLIENT_IPS}</td>
        <td>{VL_CLIENT_IPS}</td>
    </tr>
    <tr>
        <td>{TR_STATUS}</td>
        <td>{VL_STATUS}</td>
    </tr>
    </tbody>
</table>
<table class="firstColFixed">
    <thead>
    <tr>
        <th colspan="2">{TR_FEATURES}</th>
    </tr>
    </thead>
    <tbody>
    <tr>
        <td>{TR_PHP_SUPP}</td>
        <td>{VL_PHP_SUPP}</td>
    </tr>
    <tr>
        <td>{TR_PHP_EDITOR_SUPP}</td>
        <td>{VL_PHP_EDITOR_SUPP}</td>
    </tr>
    <tr>
        <td>{TR_CGI_SUPP}</td>
        <td>{VL_CGI_SUPP}</td>
    </tr>
    <tr>
        <td>{TR_DNS_SUPP}</td>
        <td>{VL_DNS_SUPP}</td>
    </tr>
    <tr>
        <td>{TR_EXT_MAIL_SUPP}</td>
        <td>{VL_EXT_MAIL_SUPP}</td>
    </tr>
    <tr>
        <td>{TR_SOFTWARE_SUPP}</td>
        <td>{VL_SOFTWARE_SUPP}</td>
    </tr>
    <tr>
        <td>{TR_BACKUP_SUPP}</td>
        <td>{VL_BACKUP_SUPP}</td>
    </tr>
    <tr>
        <td>{TR_WEB_FOLDER_PROTECTION}</td>
        <td>{VL_WEB_FOLDER_PROTECTION}</td>
    </tr>
    </tbody>
</table>
<table class="firstColFixed">
    <thead>
    <tr>
        <th colspan="2">{TR_LIMITS}</th>
    </tr>
    </thead>
    <tbody>
    <tr>
        <td>{TR_SUBDOM_ACCOUNTS}</td>
        <td>{VL_SUBDOM_ACCOUNTS_USED} / {VL_SUBDOM_ACCOUNTS_LIMIT} </td>
    </tr>
    <tr>
        <td>{TR_DOMALIAS_ACCOUNTS}</td>
        <td>{VL_DOMALIAS_ACCOUNTS_USED} / {VL_DOMALIAS_ACCOUNTS_LIMIT}</td>
    </tr>
    <tr>
        <td>{TR_FTP_ACCOUNTS}</td>
        <td>{VL_FTP_ACCOUNTS_USED} / {VL_FTP_ACCOUNTS_LIMIT}</td>
    </tr>
    <tr>
        <td>{TR_SQL_DB_ACCOUNTS}</td>
        <td>{VL_SQL_DB_ACCOUNTS_USED} / {VL_SQL_DB_ACCOUNTS_LIMIT}</td>
    </tr>
    <tr>
        <td>{TR_SQL_USER_ACCOUNTS}</td>
        <td>{VL_SQL_USER_ACCOUNTS_USED} / {VL_SQL_USER_ACCOUNTS_LIMIT}</td>
    </tr>
    <tr>
        <td>{TR_MAIL_ACCOUNTS}</td>
        <td>{VL_MAIL_ACCOUNTS_USED} / {VL_MAIL_ACCOUNTS_LIMIT}</td>
    </tr>
    <tr>
        <td>{TR_MAIL_QUOTA}</td>
        <td>{VL_MAIL_QUOTA_USED} / {VL_MAIL_QUOTA_LIMIT}</td>
    </tr>
    </tbody>
</table>

<h2 class="traffic"><span>{TR_TRAFFIC_USAGE}</span></h2>
<div class="graph">
    <span style="width:{VL_TRAFFIC_PERCENT}%">&nbsp;</span>
    <strong>{VL_TRAFFIC_PERCENT}%</strong>
</div>
<p>{VL_TRAFFIC_USED} / {VL_TRAFFIC_LIMIT}</p>

<h2 class="diskusage"><span>{TR_DISK_USAGE}</span></h2>
<div class="graph">
    <span style="width:{VL_DISK_PERCENT}%">&nbsp;</span>
    <strong>{VL_DISK_PERCENT}%</strong>
</div>
<p>{VL_DISK_USED} / {VL_DISK_LIMIT}</p>

<table class="firstColFixed">
    <thead>
    <tr>
        <th colspan="2">{TR_DISK_USAGE_DETAILS}</th>
    </tr>
    </thead>
    <tbody>
    <tr>
        <td>{TR_DISK_WEB_USAGE}</td>
        <td>{VL_WEB_DATA}</td>
    </tr>
    <tr>
        <td>{TR_DISK_SQL_USAGE}</td>
        <td>{VL_SQL_DATA}</td>
    </tr>
    <tr>
        <td>{TR_DISK_MAIL_USAGE}</td>
        <td>{VL_MAIL_DATA}</td>
    </tr>
    </tbody>
</table>
