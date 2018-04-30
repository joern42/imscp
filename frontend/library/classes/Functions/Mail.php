<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

namespace iMSCP\Functions;

use iMSCP\Application;
use iMSCP\Events;

/**
 * Class Email
 * @package iMSCP\Functions
 */
class Mail
{
    const
        MT_NORMAL_MAIL = 'normal_mail',
        MT_NORMAL_FORWARD = 'normal_forward',
        MT_ALIAS_MAIL = 'alias_mail',
        MT_ALIAS_FORWARD = 'alias_forward',
        MT_SUBDOM_MAIL = 'subdom_mail',
        MT_SUBDOM_FORWARD = 'subdom_forward',
        MT_ALSSUB_MAIL = 'alssub_mail',
        MT_ALSSUB_FORWARD = 'alssub_forward',
        MT_NORMAL_CATCHALL = 'normal_catchall',
        MT_SUBDOM_CATCHALL = 'subdom_catchall',
        MT_ALIAS_CATCHALL = 'alias_catchall',
        MT_ALSSUB_CATCHALL = 'alssub_catchall';

    /**
     * Gets data for the given email template and the given user
     *
     * @param int $userId User unique identifier
     * @param string $tplName Template name
     * @return array An associative array containing mail data:
     *                - sender_name:  Sender name
     *                - sender_email: Sender email
     *                - subject:      Subject
     *                - message:      Message
     */
    public static function getEmailTplData(int $userId, string $tplName): array
    {
        $stmt = execQuery(
            "
                SELECT admin_name, fname, lname, email, IFNULL(subject, '') AS subject, IFNULL(message, '') AS message
                FROM admin AS t1
                LEFT JOIN email_tpls AS t2 ON(owner_id = IF(admin_type = 'admin', 0, admin_id) AND name = ?)
                WHERE admin_id = ?
            ",
            [$tplName, $userId]
        );

        if (!$stmt->rowCount()) {
            throw new \Exception("Couldn't find user data");
        }

        $row = $stmt->fetch();

        if ($row['fname'] != '' && $row['lname'] != '') {
            $data['sender_name'] = $row['fname'] . ' ' . $row['lname'];
        } else if ($row['fname'] != '') {
            $data['sender_name'] = $row['fname'];
        } else if ($row['lname'] != '') {
            $data['sender_name'] = $row['lname'];
        } else {
            $data['sender_name'] = $row['admin_name'];
        }

        $data['sender_email'] = $row['email'];
        $data['subject'] = $row['subject'];
        $data['message'] = $row['message'];
        return $data;
    }

    /**
     * Sets data for the given email template and the given user using the given data
     *
     * @param int $userId User unique identifier
     * @param string $tplName Template name
     * @param array $data An associative array containing mail data:
     *                     - subject: Subject
     *                     - message: Message
     * @return void
     */
    public static function setEmailTplData(int $userId, string $tplName, array $data): void
    {
        $stmt = execQuery('SELECT subject, message FROM email_tpls WHERE owner_id = ? AND name = ?', [$userId, $tplName]);

        if ($stmt->rowCount()) {
            $query = 'UPDATE email_tpls SET subject = ?, message = ? WHERE owner_id = ? AND name = ?';
        } else {
            $query = 'INSERT INTO email_tpls (subject, message, owner_id, name) VALUES (?, ?, ?, ?)';
        }

        execQuery($query, [$data['subject'], $data['message'], $userId, $tplName]);
    }

    /**
     * Gets welcome email data for the given user
     *
     * @param int $userId User unique identifier - Template owner
     * @return array An associative array containing mail data:
     *                - sender_name:  Sender name
     *                - sender_email: Sender email
     *                - subject:      Subject
     *                - message:      Message
     */
    public static function getWelcomeEmail(int $userId): array
    {
        $data = static::getEmailTplData($userId, 'add-user-auto-msg');

        if ($data['subject'] == '') {
            $data['subject'] = tr('Welcome {USERNAME} to i-MSCP');
        }
        if ($data['message'] == '') {
            $data['message'] = tr('Dear {NAME},

A new account has been created for you.

Your account information:

Account type: {USERTYPE}
User name: {USERNAME}
Password: {PASSWORD}

Remember to change your password often and the first time you login.

You can login at {BASE_SERVER_VHOST_PREFIX}{BASE_SERVER_VHOST}{BASE_SERVER_VHOST_PORT}

Please do not reply to this email.

___________________________
i-MSCP Mailer');
        }

        return $data;
    }

    /**
     * Sets welcome email data for the given user using the given data
     *
     * @param  int $userId Template owner unique identifier (0 for administrators)
     * @param array $data An associative array containing mail data:
     *                     - subject: Subject
     *                     - message: Message
     * @return void
     */
    public static function setWelcomeEmail(int $userId, array $data): void
    {
        static::setEmailTplData($userId, 'add-user-auto-msg', $data);
    }

    /**
     * Gets lostpassword activation email data for the given user
     *
     * @param int $userId User unique identifier - Template owner
     * @return array An associative array containing mail data:
     *                - sender_name:  Sender name
     *                - sender_email: Sender email
     *                - subject:      Subject
     *                - message:      Message
     */
    public static function getLostpasswordActivationEmail(int $userId): array
    {
        $data = static::getEmailTplData($userId, 'lostpw-msg-1');

        if ($data['subject'] == '') {
            $data['subject'] = tr('Please activate your new i-MSCP password');
        }

        if ($data['message'] == '') {
            $data['message'] = tr('Dear {NAME},

Please click on the link below to renew your password:

{LINK}

Note: If you do not have requested the renewal of your password, you can ignore this email.

Please do not reply to this email.

___________________________
i-MSCP Mailer');
        }

        return $data;
    }

    /**
     * Sets lostpassword activation email template data for the given user, using given data
     *
     * @param int $adminId User unique identifier
     * @param array $data An associative array containing mail data:
     *                     - subject: Subject
     *                     - message: Message
     * @return void
     */
    public static function setLostpasswordActivationEmail(int $adminId, array $data): void
    {
        static::setEmailTplData($adminId, 'lostpw-msg-1', $data);
    }

    /**
     * Get lostpassword password email for the given user
     *
     * @param int $userId User uniqaue identifier - Template owner
     * @return array An associative array containing mail data:
     *                - sender_name:  Sender name
     *                - sender_email: Sender email
     *                - subject:      Subject
     *                - message:      Message
     */
    public static function getLostpasswordEmail(int $userId): array
    {
        $data = static::getEmailTplData($userId, 'lostpw-msg-2');

        if ($data['subject'] == '') {
            $data['subject'] = tr('Your new i-MSCP login');
        }

        if ($data['message'] == '') {
            $data['message'] = tr('Dear {NAME},

Your password has been successfully renewed.

Your new password is: {PASSWORD}

You can login at {BASE_SERVER_VHOST_PREFIX}{BASE_SERVER_VHOST}{BASE_SERVER_VHOST_PORT}

Please do not reply to this email.

___________________________
i-MSCP Mailer');
        }

        return $data;
    }

    /**
     * Sets lostpassword password email template data for the given user, usinggiven data
     *
     * @param int $userId User unique identifier - Template owner
     * @param array $data An associative array containing mail data:
     *                     - subject: Subject
     *                     - message: Message
     * @return void
     */
    public static function setLostpasswordEmail(int $userId, array $data): void
    {
        static::setEmailTplData($userId, 'lostpw-msg-2', $data);
    }

    /**
     * Get alias order email for the given reseller
     *
     * @param int $resellerId Reseller User unique identifier
     * @return array An associative array containing mail data:
     *                - sender_name:  Sender name
     *                - sender_email: Sender email
     *                - subject:      Subject
     *                - message:      Message
     */
    public static function getDomainAliasOrderEmail(int $resellerId): array
    {
        $data = static::getEmailTplData($resellerId, 'alias-order-msg');

        if ($data['subject'] == '') {
            $data['subject'] = tr('New alias order for {CUSTOMER}');
        }

        if ($data['message'] == '') {
            $data['message'] = tr('Dear {NAME},

Your customer {CUSTOMER} is awaiting for approval of a new domain alias:

{ALIAS}

Login at {BASE_SERVER_VHOST_PREFIX}{BASE_SERVER_VHOST}{BASE_SERVER_VHOST_PORT}/reseller/alias.php to activate
this domain alias.

Please do not reply to this email.

___________________________
i-MSCP Mailer');
        }

        return $data;
    }

    /**
     * Encode a string to be valid as mail header
     *
     * @source php.net/manual/en/function.mail.php
     * @param string $string String to be encoded [should be in the $charset charset]
     * @param string $charset OPTIONAL charset in that string will be encoded
     * @return string encoded string
     */
    public static function encodeMimeHeader(string $string, string $charset = 'UTF-8'): string
    {
        if (!$string || !$charset) {
            return $string;
        }

        if (function_exists('mb_encode_mimeheader')) {
            return mb_encode_mimeheader($string, $charset, 'Q', "\r\n", 8);
        }

        // define start delimiter, end delimiter and spacer
        $end = '?=';
        $start = '=?' . $charset . '?B?';
        $spacer = $end . "\r\n " . $start;

        // Determine length of encoded text withing chunks and ensure length is even
        $length = 75 - strlen($start) - strlen($end);
        $length = floor($length / 4) * 4;

        // Encode the string and split it into chunks with spacers after each chunk
        $string = base64_encode($string);
        $string = chunk_split($string, $length, $spacer);

        // Remove trailing spacer and add start and end delimiters
        $spacer = preg_quote($spacer);
        $string = preg_replace('/' . $spacer . '$/', '', $string);

        return $start . $string . $end;
    }

    /**
     * Send a mail using given data
     *
     * @param array $data An associative array containing mail data:
     *  - mail_id      : Email identifier
     *  - fname        : OPTIONAL Receiver firstname
     *  - lname        : OPTIONAL Receiver lastname
     *  - username     : Receiver username
     *  - email        : Receiver email
     *  - sender_name  : OPTIONAL sender name (if present, passed through `Reply-To' header)
     *  - sender_email : OPTIONAL Sender email (if present, passed through `Reply-To' header)
     *  - subject      : Subject of the email to be sent
     *  - message      : Message to be sent
     *  - placeholders : OPTIONAL An array where keys are placeholders to replace and values, the replacement values. Those placeholders take
     *                            precedence on the default placeholders.
     * @return bool TRUE on success, FALSE on failure
     */
    public static function sendMail(array $data): bool
    {
        $data = new \ArrayObject($data);
        $responses = Application::getInstance()->getEventManager()->trigger(Events::onSendMail, NULL, ['mail_data' => new \ArrayObject($data)]);

        if ($responses->stopped()) { // Allow third-party components to short-circuit this event.
            return true;
        }

        foreach (['mail_id', 'username', 'email', 'subject', 'message'] as $parameter) {
            if (!isset($data[$parameter]) || !is_string($data[$parameter])) {
                throw new  \Exception(sprintf("%s parameter is not defined or not a string", $parameter));
            }
        }

        if (isset($data['placeholders']) && !is_array($data['placeholders'])) {
            throw new \Exception("`placeholders' parameter must be an array of placeholders/replacements");
        }

        $username = decodeIdna($data['username']);

        if (isset($data['fname']) && $data['fname'] != '' && isset($data['lname']) && $data['lname'] != '') {
            $name = $data['fname'] . ' ' . $data['lname'];
        } else if (isset($data['fname']) && $data['fname'] != '') {
            $name = $data['fname'];
        } else if (isset($data['lname']) && $data['lname'] != '') {
            $name = $data['lname'];
        } else {
            $name = $username;
        }

        $cfg = Application::getInstance()->getConfig();
        $scheme = $cfg['BASE_SERVER_VHOST_PREFIX'];
        $host = $cfg['BASE_SERVER_VHOST'];
        $port = $scheme == 'http://' ? $cfg['BASE_SERVER_VHOST_HTTP_PORT'] : $cfg['BASE_SERVER_VHOST_HTTPS_PORT'];

        # Prepare default replacements
        $replacements = [
            '{NAME}'                     => $name,
            '{USERNAME}'                 => $username,
            '{BASE_SERVER_VHOST_PREFIX}' => $scheme,
            '{BASE_SERVER_VHOST}'        => $host,
            '{BASE_SERVER_VHOST_PORT}'   => ":$port"
        ];

        if (isset($data['placeholders'])) {
            # Merge user defined replacements if any (those replacements take precedence on default replacements)
            $replacements = array_merge($replacements, $data['placeholders']);
        }

        $replacements["\n"] = "\r\n";
        $search = array_keys($replacements);
        $replace = array_values($replacements);
        unset($replacements);

        # Process replacements in placeholder replacement values
        foreach ($replace as &$value) {
            $value = str_replace($search, $replace, $value);
        }

        # Prepare sender
        $from = "noreply@$host";
        # Prepare recipient
        $to = static::encodeMimeHeader($name) . ' <' . $data['email'] . '>';
        # Prepare subject
        $subject = static::encodeMimeHeader(str_replace($search, $replace, $data['subject']));
        # Prepare message
        $message = wordwrap(str_replace($search, $replace, $data['message']), 75, "\r\n");
        # Prepare headers
        $headers[] = 'From: ' . static::encodeMimeHeader("i-MSCP ($host)") . " <$from>";
        if (isset($data['sender_email'])) {
            # Note: We cannot use the real sender email address in the FROM header because the email's domain could be
            # hosted on external server, meaning that if the domain implements SPF, the mail could be rejected. However we
            # pass the real sender email through the `Reply-To' header
            if (isset($data['sender_name'])) {
                $headers[] = 'Reply-To: ' . static::encodeMimeHeader($data['sender_name']) . ' <' . $data['sender_email'] . '>';
            } else {
                $headers[] = 'Reply-To: ' . $data['sender_email'];
            }
        } else {
            $headers[] = 'Reply-To: ' . $cfg['DEFAULT_ADMIN_ADDRESS'];
        }

        $headers[] = 'MIME-Version: 1.0';
        $headers[] = 'Content-Type: text/plain; charset=utf-8';
        $headers[] = 'Content-Transfer-Encoding: 8bit';
        $headers[] = 'X-Mailer: i-MSCP Mailer (frontEnd)';

        return mail($to, $subject, $message, implode("\r\n", $headers), "-f $from");
    }

    // In progress...

    /**
     * Send add user email
     *
     * @param int $adminId Administrator or reseller unique identifier
     * @param string $uname Username
     * @param string $upass User password
     * @param string $uemail User email
     * @param string $ufname User firstname
     * @param string $ulname User lastname
     * @param string $utype User type
     * @return bool TRUE on success, FALSE on failure
     */
    public static function sendWelcomeMail(int $adminId, string $uname, string $upass, string $uemail, string $ufname, string $ulname, string $utype): bool
    {
        $data = static::getWelcomeEmail($adminId);
        $ret = static::sendMail([
            'mail_id'      => 'add-user-auto-msg',
            'fname'        => $ufname,
            'lname'        => $ulname,
            'username'     => $uname,
            'email'        => decodeIdna($uemail),
            'subject'      => $data['subject'],
            'message'      => $data['message'],
            'placeholders' => [
                '{USERTYPE}' => $utype,
                '{PASSWORD}' => $upass
            ]
        ]);

        if (!$ret) {
            writeLog(sprintf("Lost Password: Couldn't send welcome email to %s", $uname), E_USER_ERROR);
            return false;
        }

        return true;
    }

    /**
     * Create default mails accounts
     *
     * @param int $mainDmnId Customer primary domain unique identifier
     * @param string $userEmail Customer email address
     * @param string $dmnName Domain name
     * @param string $forwardType Forward type(MT_NORMAL_FORWARD|MT_ALIAS_FORWARD|MT_SUBDOM_FORWARD|MT_ALSSUB_FORWARD)
     * @param int $subId OPTIONAL Sub-ID if default mail accounts are being created for a domain alias or subdomain
     * @return void
     */
    public static function createDefaultMailAccounts(int $mainDmnId, string $userEmail, string $dmnName, string $forwardType = Mail::MT_NORMAL_FORWARD, int $subId = 0): void
    {
        $em = Application::getInstance()->getEventManager();
        $db = Application::getInstance()->getDb();

        try {
            if ($subId == 0 && $forwardType != Mail::MT_NORMAL_FORWARD) {
                throw new \DomainException("Mail account forward type doesn't match with provided child domain ID");
            }

            if (empty($userEmail) || !ValidateEmail($userEmail)) {
                writeLog(
                    sprintf("Couldn't create default mail accounts for the %s domain. Customer email address is not set or invalid.", $dmnName),
                    E_USER_WARNING
                );
                return;
            }

            $userEmail = encodeIdna($userEmail);

            if (in_array($forwardType, [Mail::MT_NORMAL_FORWARD, Mail::MT_ALIAS_FORWARD])) {
                $mailAccounts = ['abuse', 'hostmaster', 'postmaster', 'webmaster'];
            } else {
                $mailAccounts = ['webmaster'];
            }

            $db->getDriver()->getConnection()->beginTransaction();

            $stmt = $db->createStatement(
                "
                INSERT INTO mail_users (mail_acc, mail_forward, domain_id, mail_type, sub_id, status, po_active, mail_addr)
                VALUES (?, ?, ?, ? ,?, 'toadd', 'no', CONCAT(?, '@', ?))
            "
            );
            $stmt->prepare();

            /** @var \PDOStatement $resource */
            $resource = $stmt->getResource();
            $resource->bindParam(1, $mailAccount, \PDO::PARAM_STR);
            $resource->bindParam(2, $userEmail, \PDO::PARAM_STR);
            $resource->bindParam(3, $mainDmnId, \PDO::PARAM_STR);
            $resource->bindParam(4, $forwardType, \PDO::PARAM_STR);
            $resource->bindParam(5, $subId, \PDO::PARAM_STR);
            $resource->bindParam(6, $mailAccount, \PDO::PARAM_STR);
            $resource->bindParam(7, $dmnName, \PDO::PARAM_STR);
            unset($resource);

            foreach ($mailAccounts as $mailAccount) {
                $em->trigger(Events::onBeforeAddMail, NULL, [
                    'mailType'     => 'forward',
                    'mailUsername' => $mailAccount,
                    'forwardList'  => $userEmail,
                    'mailAddress'  => "$mailAccount@$dmnName"
                ]);
                $stmt->execute();
                $em->trigger(Events::onAfterAddMail, NULL, [
                    'mailId'       => $db->getDriver()->getLastGeneratedValue(),
                    'mailType'     => 'forward',
                    'mailUsername' => $mailAccount,
                    'forwardList'  => $userEmail,
                    'mailAddress'  => "$mailAccount@$dmnName"
                ]);
            }

            $db->getDriver()->getConnection()->commit();
        } catch (\PDOException $e) {
            $db->getDriver()->getConnection()->rollback();
            throw $e;
        }
    }

    /**
     * Delete all autoreplies log for which no mail address is found in the mail_users database table
     *
     * @return void
     */
    public static function deleteAutorepliesLogs(): void
    {
        execQuery("DELETE FROM autoreplies_log WHERE `from` NOT IN (SELECT mail_addr FROM mail_users WHERE status <> 'todelete')");
    }

    /**
     * Synchronizes mailboxes quota that belong to the given domain using the given quota limit
     *
     * Algorythm:
     *
     * 1. In case the new quota limit is 0 (unlimited), equal or bigger than the sum of current quotas, we do nothing
     * 2. We have a running total, which start at zero
     * 3. We divide the quota of each mailbox by the sum of current quotas, then we multiply the result by the new quota limit
     * 4. We store the original value of the running total elsewhere, then we add the amount we have just calculated in #3
     * 5. We ensure that new quota is a least 1 MiB (each mailbox must have 1 MiB minimum quota)
     * 5. We round both old value and new value of the running total to integers, and take the difference
     * 6. We update the mailbox quota result calculated in step 5
     * 7. We repeat steps 3-6 for each quota
     *
     * This algorythm guarantees to have the total amount prorated equal to the sum of all quota after update. It also
     * ensure that each mailboxes has 1 MiB quota minimum.
     *
     * Note:  For the sum calculation of current quotas, we consider that a mailbox with a value equal to 0 (unlimited) is
     * equal to the new quota limit.
     *
     * @param int $domainId Customer primary domain unique identifier
     * @param int $newQuota New quota limit in bytes
     * @return void
     */
    public static function syncMailboxesQuota(int $domainId, int $newQuota): void
    {
        ignore_user_abort(true);
        set_time_limit(0);

        if ($newQuota == 0) {
            return;
        }

        $cfg = Application::getInstance()->getConfig();
        $stmt = execQuery('SELECT mail_id, quota FROM mail_users WHERE domain_id = ? AND quota IS NOT NULL', [$domainId]);

        if (!$stmt->rowCount()) {
            return;
        }

        $mailboxes = $stmt->fetchAll();
        $totalQuota = 0;

        foreach ($mailboxes as $mailbox) {
            $totalQuota += ($mailbox['quota'] == 0) ? $newQuota : $mailbox['quota'];
        }

        $totalQuota /= 1048576;
        $newQuota /= 1048576;

        if ($newQuota < $totalQuota || (isset($cfg['EMAIL_QUOTA_SYNC_MODE']) && $cfg['EMAIL_QUOTA_SYNC_MODE']) || $totalQuota == 0) {
            $db = Application::getInstance()->getDb();
            $stmt = $db->createStatement('UPDATE mail_users SET quota = ? WHERE mail_id = ?');
            $stmt->prepare();
            $result = 0;

            foreach ($mailboxes as $mailbox) {
                $oldResult = $result;
                $mailboxQuota = ($mailbox['quota'] ? $mailbox['quota'] / 1048576 : $newQuota);
                $result += $newQuota * $mailboxQuota / $totalQuota;

                if ($result < 1) {
                    $result = 1;
                }

                $stmt->execute([((int)$result - (int)$oldResult) * 1048576, $mailbox['mail_id']]);
            }
        }
    }

    /**
     * Get list of available webmail
     *
     * @return array
     */
    public static function getWebmailList(): array
    {
        $config = $db = Application::getInstance()->getConfig();
        if (isset($config['WEBMAILS']) && strtolower($config['WEBMAILS']) != 'no') {
            return explode(',', $config['WEBMAILS']);
        }

        return [];
    }

    /**
     * Humanize the given mail type
     *
     * @param string $mailAcc Mail account name
     * @param  string $mailType Mail account type
     * @return string Translated mail account type
     */
    public static function humanizeMailType($mailAcc, $mailType)
    {
        switch ($mailType) {
            case static::MT_NORMAL_MAIL:
            case static::MT_ALIAS_MAIL:
            case static::MT_SUBDOM_MAIL:
            case static::MT_ALSSUB_MAIL:
                return tr('Normal account');
            case static::MT_NORMAL_FORWARD:
            case static::MT_ALIAS_FORWARD:
                return tr('Forward account') . (in_array($mailAcc, ['abuse', 'hostmaster', 'postmaster', 'webmaster']) ? ' ' . tr('(default)') : '');
            case static::MT_SUBDOM_FORWARD:
            case static::MT_ALSSUB_FORWARD:
                return tr('Forward account') . ($mailAcc == 'webmaster' ? ' ' . tr('(default)') : '');
            case static::MT_NORMAL_MAIL . ',' . static::MT_NORMAL_FORWARD:
            case static::MT_ALIAS_MAIL . ',' . static::MT_ALIAS_FORWARD:
            case static::MT_SUBDOM_MAIL . ',' . static::MT_SUBDOM_FORWARD:
            case static::MT_ALSSUB_MAIL . ',' . static::MT_ALSSUB_FORWARD:
                return tr('Normal & forward account');
                break;
            case static::MT_NORMAL_CATCHALL:
            case static::MT_ALIAS_CATCHALL:
            case static::MT_SUBDOM_CATCHALL:
            case static::MT_ALSSUB_CATCHALL:
                return tr('Catch-all account');
            default:
                return tr('Unknown type.');
        }
    }

    /**
     * Parse data from the given maildirsize file
     *
     * Because processing several maildirsize files can be time consuming, the data are stored in session for next 5 minutes.
     * It is possible to refresh data by changing the $refreshData flag value to TRUE
     *
     * @see http://www.courier-mta.org/imap/README.maildirquota.html
     * @param string $maildirsizeFilePath
     * @param bool $refreshData Flag indicating if data must be refreshed
     * @return array|bool Array containing maildirsize data, FALSE on failure
     */
    public static function parseMaildirsize(string $maildirsizeFilePath, bool $refreshData = false)
    {
        $session = Application::getInstance()->getSession();

        if (!$refreshData && !empty($session['maildirsize'][$maildirsizeFilePath])
            && $session['maildirsize'][$maildirsizeFilePath]['timestamp'] < (time() + 300)
        ) {
            return $session['maildirsize'][$maildirsizeFilePath];
        }

        unset($session['maildirsize'][$maildirsizeFilePath]);

        $fh = @fopen($maildirsizeFilePath, 'r');
        if (!$fh) {
            return false;
        }

        $maildirsize = [
            'quota_bytes'    => 0,
            'quota_messages' => 0,
            'byte_count'     => 0,
            'file_count'     => 0,
            'timestamp'      => time()
        ];

        // Parse quota definition

        if (($line = fgets($fh)) === false) {
            fclose($fh);
            return false;
        }

        $quotaDefinition = explode(',', $line, 2);

        if (!isset($quotaDefinition[0]) || !preg_match('/(\d+)S/i', $quotaDefinition[0], $m)) {
            // No quota definition. Skip processing...
            fclose($fh);
            return false;
        }

        $maildirsize['quota_bytes'] = $m[1];

        if (isset($quotaDefinition[1]) && preg_match('/(\d+)C/i', $quotaDefinition[1], $m)) {
            $maildirsize['quota_messages'] = $m[1];
        }

        // Parse byte and file counts

        while (($line = fgets($fh)) !== false) {
            if (preg_match('/^\s*(-?\d+)\s+(-?\d+)\s*$/', $line, $m)) {
                $maildirsize['byte_count'] += $m[1];
                $maildirsize['file_count'] += $m[2];
            }
        }

        fclose($fh);
        Application::getInstance()->getSession()['maildirsize'][$maildirsizeFilePath] = $maildirsize;
        return $maildirsize;
    }
}
