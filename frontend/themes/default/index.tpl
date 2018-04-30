
<div id="login">
    <form name="login" action="index.php" method="post">
        <table>
            <tr>
                <td class="left"><label for="admin_name">{TR_USERNAME}</label></td>
                <td class="right"><input type="text" name="admin_name" id="admin_name" value="{UNAME}"></td>
            </tr>
            <tr>
                <td class="left"><label for="admin_pass">{TR_PASSWORD}</label></td>
                <td class="right"><input type="password" name="admin_pass" id="admin_pass" value=""></td>
            </tr>
            <tr>
                <td colspan="2" class="right">
                    <button type="submit" name="Submit" tabindex="3">{TR_SIGN_IN}</button>
                </td>
            </tr>
            <!-- BDP: ssl_block -->
            <tr>
                <td colspan="2" class="center">
                    <br>
                    <a class="icon {SSL_IMAGE_CLASS}" href="{SSL_LINK}" title="{TR_SSL_DESCRIPTION}">{TR_SSL}</a>
                </td>
            </tr>
            <!-- EDP: ssl_block -->
        </table>
    </form>
</div>
