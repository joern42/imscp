# i-MSCP packages
<table>
    <tr>
        <th>Package</th>
        <th>Description</th>
        <th>Execution context(s)</th>
        <th>Priority</th>
    </tr>
        <tr>
            <td>System</td>
            <td>Setup the system (hostname, primary IP address, IPv6 support...).</td>
            <td>Installer only</td>
            <td>200</td>
        </tr>
    <tr>
        <td>ServicesSSL</td>
        <td>Setup SSL for the FTP, IMAP/POP and SMTP servers.</td>
        <td>Installer only</td>
        <td>150</td>
    </tr>
    <tr>
        <td>FrontEnd</td>
        <td>Setup the Nginx server, PHP and SSL for the control panel (UI).</td>
        <td>Installer only</td>
        <td>100</td>
    </tr>
    <tr>
        <td>ClamAV</td>
        <td>Setup the ClamAV antivirus (Postfix integration).</td>
        <td>Installer only</td>
        <td>7</td>
    </tr>
    <tr>
        <td>PostfixSRS</td>
        <td>Setup the Sender Rewriting Scheme (SRS) service for the Postfix MTA.</td>
        <td>Installer only</td>
        <td>7</td>
    </tr>
    <tr>
        <td>Rspamd</td>
        <td>Setup the Rspamd spam filtering system (Postfix integration).</td>
        <td>Installer only</td>
        <td>7</td>
    </tr>
    <tr>
        <td>AntiRootKits</td>
        <td>Handle the anti-rootkits packages (Chkrootkit, Rkhunter).</td>
        <td>Installer only</td>
        <td>0</td>
    </tr>
    <tr>
        <td>Backup</td>
        <td>Setup the i-MSCP core backup feature.</td>
        <td>Installer only</td>
        <td>0</td>
    </tr>
    <tr>
        <td>ClientWebsitesAltURLs</td>
        <td>Provide alternative URLs for client websites (domains).</td>
        <td>Installer, backend</td>
        <td>0</td>
    </tr>
    <tr>
        <td>FileManager</td>
        <td>Handle FileManager packages (Pydio, MonstaFTP).</td>
        <td>Installer, backend</td>
        <td>0</td>
    </tr>
    <tr>
        <td>PhpMyAdmin</td>
        <td>Setup the PhpMyAdmin SQL filemanager.</td>
        <td>Installer  only</td>
        <td>0</td>
    </tr>
    <tr>
        <td>Webmails</td>
        <td>Handle the Webmail packages (Roundcube, Rainloop).</td>
        <td>Installer, backend</td>
        <td>0</td>
    </tr>
    <tr>
        <td>Webstats</td>
        <td>Handle the Westats packages (AWStats).</td>
        <td>Installer, backend</td>
        <td>0</td>
    </tr>
</table>

###### Execution contexts:

- **Installer only**: Package providing routines and/or event listeners which
are called on installation or reconfiguration phases. Such a package is never
loaded outside of the installation or reconfiguration contexts.
- **Installer**: Package providing routines and/or event listeners which
are called on installation or reconfiguration phases.
- **Backend**: Package providing routines and/or event listeners which are
called while processing of backend requests.
