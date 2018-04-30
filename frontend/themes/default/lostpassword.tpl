
<script>
    $(function() {
        $('#captcha').click(function() {
            $(this).attr('src', $(this).attr('src'))
        });
    })
</script>
<div id="login">
    <form name="lostpasswordFrm" action="lostpassword.php" method="post" id="fmr1">
        <table>
            <tr>
                <td colspan="2" class="center">
                    <img id="captcha" src="?captcha=1" width="{CAPTCHA_WIDTH}" height="{CAPTCHA_HEIGHT}" title="{GET_NEW_CAPTCHA}">
                </td>
            </tr>
            <tr>
                <td class="left"><label for="capcode">{TR_CAPCODE}</label></td>
                <td class="right"><input type="text" name="capcode" id="capcode" tabindex="1"></td>
            </tr>
            <tr>
                <td class="left"><label for="uname">{TR_USERNAME}</label></td>
                <td class="right"><input type="text" name="uname" id="uname" tabindex="2" value="{UNAME}"></td>
            </tr>
            <tr>
                <td colspan="2" class="right">
                    <button name="Submit" type="submit" tabindex="3">{TR_SEND}</button>
                    <button formaction="/" formmethod="get">{TR_CANCEL}</button>
                </td>
            </tr>
        </table>
    </form>
</div>
