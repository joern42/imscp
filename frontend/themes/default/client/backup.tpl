<script>
    $(function () {
        $("input[type=submit]").on("click", function () {
            var input = this;
            this.blur();
            return jQuery.imscp.confirm("{TR_CONFIRM_MESSAGE}", function (ret) {
                if(ret) {
                    $(input).closest("form").submit();
                }
            });
        });
    });
</script>
<h3 class="hdd"><span>{TR_DOWNLOAD_DIRECTION}</span></h3>
<ul>
    <li>{TR_FTP_LOG_ON}</li>
    <li>{TR_SWITCH_TO_BACKUP}</li>
    <li>{TR_DOWNLOAD_FILE}</li>
</ul>
<br/>
<h3 class="hdd"><span>{TR_RESTORE_BACKUP}</span></h3>
<p>{TR_RESTORE_DIRECTIONS}</p>
<form action="backup.php" method="post">
    <div class="buttons">
        <input type="hidden" name="uaction" value="bk_restore">
        <input type="submit" name="Submit" value="{TR_RESTORE}">
    </div>
</form>
