
<table class="firstColFixed">
    <thead>
    <tr>
        <th>{TR_USERNAME}</th>
        <th>{TR_USER_TYPE}</th>
        <th>{TR_IP_ADDRESS}</th>
        <th>{TR_LAST_ACCESS}</th>
        <th>{TR_ACTIONS}</th>
    </tr>
    </thead>
    <tbody>
    <!-- BDP: session_block -->
    <tr>
        <td>{USERNAME}</td>
        <td>{USER_TYPE}</td>
        <td>{IP_ADDRESS}</td>
        <td>{LAST_ACCESS}</td>
        <td>
            <!-- BDP: session_actions_block -->
            <a href="?action=signout&sid={SID}" class="icon i_close">{TR_ACT_SIGN_OUT}</a>
            <!-- EDP: session_actions_block -->
        </td>
    </tr>
    <!-- EDP: session_block -->
    </tbody>
</table>
