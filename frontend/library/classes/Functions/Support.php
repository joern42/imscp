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
use iMSCP\TemplateEngine;

/**
 * Class Support
 * @package iMSCP\Functions
 */
class Support
{
    /**
     * Creates a ticket and informs the recipient
     *
     * @param int $userId User unique identifier
     * @param int $adminId Creator unique identifier
     * @param int $urgency The ticket's urgency
     * @param String $subject Ticket's subject
     * @param String $message Ticket's message
     * @param int $userLevel User's level (client = 1; reseller = 2)
     * @return bool TRUE on success, FALSE otherwise
     */
    public static function createTicket(int $userId, int $adminId, int $urgency, string $subject, string $message, int $userLevel): bool
    {
        if ($userLevel < 1 || $userLevel > 2) {
            setPageMessage(tr('Wrong user level provided.'), 'error');
            return false;
        }

        $subject = cleanInput($subject);
        $userMessage = cleanInput($message);

        execQuery(
            '
                INSERT INTO tickets (
                    ticket_level, ticket_from, ticket_to, ticket_status, ticket_reply, ticket_urgency, ticket_date, ticket_subject, ticket_message
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ',
            [$userLevel, $userId, $adminId, 1, 0, $urgency, time(), $subject, $userMessage]
        );
        setPageMessage(tr('Your message has been successfully sent.'), 'success');
        static::sendTicketNotification($adminId, $subject, $userMessage, 0, $urgency);
        return true;
    }

    /**
     * Gets the content of the selected ticket and generates its output
     *
     * @param TemplateEngine $tpl Template engine
     * @param int $ticketId Id of the ticket to display
     * @param int $userId Id of the user
     * @return bool TRUE if ticket is found, FALSE otherwise
     */
    public static function showTicketContent(TemplateEngine $tpl, int $ticketId, int $userId): bool
    {
        # Always show last replies first
        static::showTicketReplies($tpl, $ticketId);

        $stmt = execQuery(
            '
                SELECT ticket_id, ticket_status, ticket_reply, ticket_urgency, ticket_date, ticket_subject, ticket_message
                FROM tickets
                WHERE ticket_id = ?
                AND (ticket_from = ? OR ticket_to = ?)
            ',
            [$ticketId, $userId, $userId]
        );

        if (!$stmt->rowCount()) {
            $tpl->assign('TICKET', '');
            setPageMessage(tr("Ticket with Id '%d' was not found.", $ticketId), 'error');
            return false;
        }

        $row = $stmt->fetch();

        if ($row['ticket_status'] == 0) {
            $trAction = tr('Open ticket');
            $action = 'open';
        } else {
            $trAction = tr('Close the ticket');
            $action = 'close';
        }

        $from = static::getTicketSender($ticketId);
        $tpl->assign([
            'TR_TICKET_ACTION'      => $trAction,
            'TICKET_ACTION_VAL'     => $action,
            'TICKET_DATE_VAL'       => date(Application::getInstance()->getConfig()['DATE_FORMAT'] . ' (H:i)', $row['ticket_date']),
            'TICKET_SUBJECT_VAL'    => toHtml($row['ticket_subject']),
            'TICKET_CONTENT_VAL'    => nl2br(toHtml($row['ticket_message'])),
            'TICKET_ID_VAL'         => $row['ticket_id'],
            'TICKET_URGENCY_VAL'    => static::getTicketUrgency($row['ticket_urgency']),
            'TICKET_URGENCY_ID_VAL' => $row['ticket_urgency'],
            'TICKET_FROM_VAL'       => toHtml($from)
        ]);
        $tpl->parse('TICKET_MESSAGE', '.ticket_message');
        return true;
    }

    /**
     * Updates a ticket with a new answer and informs the recipient
     *
     * @param int $ticketId id of the ticket's parent ticket
     * @param int $userId User unique identifier
     * @param int $urgency The parent ticket's urgency
     * @param String $subject The parent ticket's subject
     * @param String $message The ticket replys' message
     * @param int $ticketLevel The tickets's level (1 = user; 2 = super)
     * @param int $userLevel The user's level (1 = client; 2 = reseller; 3 = admin)
     * @return void
     */
    public static function updateTicket(int $ticketId, int $userId, int $urgency, string $subject, string $message, int $ticketLevel, int $userLevel): void
    {
        $db = Application::getInstance()->getDb();
        $subject = cleanInput($subject);
        $userMessage = cleanInput($message);
        $stmt = execQuery('SELECT ticket_from, ticket_to, ticket_status FROM tickets WHERE ticket_id = ? AND (ticket_from = ? OR ticket_to = ?)', [
            $ticketId, $userId, $userId
        ]);
        $stmt->rowCount() or View::showBadRequestErrorPage();
        $row = $stmt->fetch();

        try {
            /* Ticket levels:
            *  1: Client -> Reseller
            *  2: Reseller -> Admin
            *  NULL: Reply
            */
            if (($ticketLevel == 1 && $userLevel == 1) || ($ticketLevel == 2 && $userLevel == 2)) {
                $ticketTo = $row['ticket_to'];
                $ticketFrom = $row['ticket_from'];
            } else {
                $ticketTo = $row['ticket_from'];
                $ticketFrom = $row['ticket_to'];
            }

            $db->getDriver()->getConnection()->beginTransaction();

            execQuery(
                '
                    INSERT INTO tickets (
                        ticket_from, ticket_to, ticket_status, ticket_reply, ticket_urgency, ticket_date, ticket_subject, ticket_message
                    ) VALUES (
                        ?, ?, ?, ?, ?, ?, ?, ?
                    )
                ',
                [$ticketFrom, $ticketTo, NULL, $ticketId, $urgency, time(), $subject, $userMessage]
            );

            if ($userLevel != 2) {
                // Level User: Set ticket status to "client answered"
                if ($ticketLevel == 1 && ($row['ticket_status'] == 0 || $row['ticket_status'] == 3)) {
                    static::changeTicketStatus($ticketId, 4);
                    // Level Super: set ticket status to "reseller answered"
                } elseif ($ticketLevel == 2 && ($row['ticket_status'] == 0 || $row['ticket_status'] == 3)) {
                    static::changeTicketStatus($ticketId, 2);
                }
            } else {
                // Set ticket status to "reseller answered" or "client answered" depending on ticket
                if ($ticketLevel == 1 && ($row['ticket_status'] == 0 || $row['ticket_status'] == 3)) {
                    static::changeTicketStatus($ticketId, 2);
                } elseif ($ticketLevel == 2 && ($row['ticket_status'] == 0 || $row['ticket_status'] == 3)) {
                    static::changeTicketStatus($ticketId, 4);
                }
            }

            $db->getDriver()->getConnection()->commit();
            setPageMessage(tr('Your message has been successfully sent.'), 'success');
            static::sendTicketNotification($ticketTo, $subject, $userMessage, $ticketId, $urgency);
        } catch (\Exception $e) {
            $db->getDriver()->getConnection()->rollBack();
            throw $e;
        }
    }

    /**
     * Deletes a ticket
     *
     * @param int $ticketId Ticket unique identifier
     * @return void
     */
    public static function deleteTicket(int $ticketId): void
    {
        execQuery('DELETE FROM tickets WHERE ticket_id = ? OR ticket_reply = ?', [$ticketId, $ticketId]);
    }

    /**
     * Deletes all open/closed tickets that are belong to a user
     *
     * @param string $status Ticket status ('open' or 'closed')
     * @param int $userId The user's ID
     * @return void
     */
    public static function deleteTickets(string $status, int $userId): void
    {
        $condition = ($status == 'open') ? "ticket_status != '0'" : "ticket_status = '0'";
        execQuery("DELETE FROM tickets WHERE (ticket_from = ? OR ticket_to = ?) AND {$condition}", [$userId, $userId]);
    }

    /**
     * Generates a ticket list
     *
     * @param TemplateEngine $tpl Template engine
     * @param int $userId User unique identifier
     * @param int $start First ticket to show (pagination)
     * @param int $count Maximal count of shown tickets (pagination)
     * @param String $userLevel User level
     * @param String $status Status of the tickets to be showed: 'open' or 'closed'
     * @return void
     */
    public static function generateTicketList(TemplateEngine $tpl, int $userId, int $start, int $count, string $userLevel, string $status): void
    {
        $condition = $status == 'open' ? "ticket_status != 0" : 'ticket_status = 0';
        $rowsCount = execQuery("SELECT COUNT(ticket_id) FROM tickets WHERE (ticket_from = ? OR ticket_to = ?) AND ticket_reply = '0' AND $condition", [
            $userId, $userId
        ])->fetchColumn();

        if ($rowsCount > 0) {
            $stmt = execQuery(
                "
                    SELECT ticket_id, ticket_status, ticket_urgency, ticket_level, ticket_date, ticket_subject
                    FROM tickets WHERE (ticket_from = ? OR ticket_to = ?)
                    AND ticket_reply = 0
                    AND $condition
                    ORDER BY ticket_date DESC
                    LIMIT {$start}, {$count}
                ",
                [$userId, $userId]
            );

            $prevSi = $start - $count;

            if ($start == 0) {
                $tpl->assign('SCROLL_PREV', '');
            } else {
                $tpl->assign([
                    'SCROLL_PREV_GRAY' => '',
                    'PREV_PSI'         => $prevSi
                ]);
            }

            $nextSi = $start + $count;

            if ($nextSi + 1 > $rowsCount) {
                $tpl->assign('SCROLL_NEXT', '');
            } else {
                $tpl->assign([
                    'SCROLL_NEXT_GRAY' => '',
                    'NEXT_PSI'         => $nextSi
                ]);
            }

            while ($row = $stmt->fetch()) {
                if ($row['ticket_status'] == 1) {
                    $tpl->assign('TICKET_STATUS_VAL', tr('[New]'));
                } elseif ($row['ticket_status'] == 2 && (($row['ticket_level'] == 1 && $userLevel == 'client')
                        || ($row['ticket_level'] == 2 && $userLevel == 'reseller'))
                ) {
                    $tpl->assign('TICKET_STATUS_VAL', tr('[Re]'));
                } elseif ($row['ticket_status'] == 4 && (($row['ticket_level'] == 1 && $userLevel == 'reseller')
                        || ($row['ticket_level'] == 2 && $userLevel == 'admin'))
                ) {
                    $tpl->assign('TICKET_STATUS_VAL', tr('[Re]'));
                } else {
                    $tpl->assign('TICKET_STATUS_VAL', '[Read]');
                }

                $tpl->assign([
                    'TICKET_URGENCY_VAL'   => static::getTicketUrgency($row['ticket_urgency']),
                    'TICKET_FROM_VAL'      => toHtml(static::getTicketSender($row['ticket_id'])),
                    'TICKET_LAST_DATE_VAL' => static::ticketGetLastDate($row['ticket_id']),
                    'TICKET_SUBJECT_VAL'   => toHtml($row['ticket_subject']),
                    'TICKET_SUBJECT2_VAL'  => addslashes(cleanHtml($row['ticket_subject'])),
                    'TICKET_ID_VAL'        => $row['ticket_id']
                ]);
                $tpl->parse('TICKETS_ITEM', '.tickets_item');
            }

            return;
        }

        // no ticket to display
        $tpl->assign([
            'TICKETS_LIST' => '',
            'SCROLL_PREV'  => '',
            'SCROLL_NEXT'  => ''
        ]);

        if ($status == 'open') {
            setPageMessage(tr('You have no open tickets.'), 'static_info');
        } else {
            setPageMessage(tr('You have no closed tickets.'), 'static_info');
        }
    }

    /**
     * Closes the given ticket.
     *
     * @param int $ticketId Ticket id
     * @return bool TRUE on success, FALSE otherwise
     */
    public static function closeTicket(int $ticketId): bool
    {
        if (!static::changeTicketStatus($ticketId, 0)) {
            setPageMessage(tr("Unable to close the ticket with Id '%s'.", $ticketId), 'error');
            writeLog(sprintf("Unable to close the ticket with Id '%s'.", $ticketId), E_USER_ERROR);
            return false;
        }

        setPageMessage(tr('Ticket successfully closed.'), 'success');
        return true;
    }

    /**
     * Reopens the given ticket
     *
     * @param int $ticketId Ticket id
     * @return bool TRUE on success, FALSE otherwise
     */
    public static function reopenTicket(int $ticketId): bool
    {
        if (!static::changeTicketStatus($ticketId, 3)) {
            setPageMessage(tr("Unable to reopen ticket with Id '%s'.", $ticketId), 'error');
            writeLog(sprintf("Unable to reopen ticket with Id '%s'.", $ticketId), E_USER_ERROR);
            return false;
        }

        setPageMessage(tr('Ticket successfully reopened.'), 'success');
        return true;
    }

    /**
     * Returns ticket status
     *
     * Possible status values are:
     *  0 - closed
     *  1 - new
     *  2 - answered by reseller
     *  3 - read (if status was 2 or 4)
     *  4 - answered by client
     *
     * @param int $ticketId Ticket unique identifier
     * @return int ticket status identifier
     */
    public static function getTicketStatus(int $ticketId): int
    {
        $session = Application::getInstance()->getSession();
        $stmt = execQuery('SELECT ticket_status FROM tickets WHERE ticket_id = ? AND (ticket_from = ? OR ticket_to = ?)', [
            $ticketId, $session['user_id'], $session['user_id']
        ]);

        if (!$stmt->rowCount()) {
            setPageMessage(tr("Ticket with Id '%d' was not found.", $ticketId), 'error');
            return false;
        }

        return $stmt->fetchColumn();
    }

    /**
     * Changes ticket status
     *
     * Possible status values are:
     *
     *    0 - closed
     *    1 - new
     *    2 - answered by reseller
     *    3 - read (if status was 2 or 4)
     *    4 - answered by client
     *
     * @param int $ticketId Ticket unique identifier
     * @param int $ticketStatus New status identifier
     * @return bool TRUE if ticket status was changed, FALSE otherwise
     */
    public static function changeTicketStatus(int $ticketId, int $ticketStatus): bool
    {
        $session = Application::getInstance()->getSession();
        $stmt = execQuery('UPDATE tickets SET ticket_status = ? WHERE ticket_id = ? OR ticket_reply = ? AND (ticket_from = ? OR ticket_to = ?)', [
            $ticketStatus, $ticketId, $ticketId, $session['user_id'], $session['user_id']
        ]);

        return $stmt->rowCount() > 0;
    }

    /**
     * Reads the user's level from ticket info
     *
     * @param int $ticketId Ticket id
     * @return int User's level (1 = user, 2 = super) or FALSE if ticket is not found
     */
    public static function getUserLevel(int $ticketId): int
    {
        // Get info about the type of message
        $stmt = execQuery('SELECT ticket_level FROM tickets WHERE ticket_id = ?', [$ticketId]);
        if (!$stmt->rowCount()) {
            setPageMessage(tr("Ticket with Id '%d' was not found.", $ticketId), 'error');
            return false;
        }

        return $stmt->fetchColumn();
    }

    /**
     * Returns translated ticket priority
     *
     * @param int $ticketUrgency Values from 1 to 4
     * @return string Translated priority string
     */
    public static function getTicketUrgency(int $ticketUrgency): string
    {
        switch ($ticketUrgency) {
            case 1:
                return tr('Low');
            case 3:
                return tr('High');
            case 4:
                return tr('Very high');
            case 2:
            default:
                return tr('Medium');
        }
    }

    /**
     * Returns ticket'sender of a ticket answer
     *
     * @param int $ticketId Id of the ticket to display
     * @return string Formatted ticket sender
     */
    private static function getTicketSender(int $ticketId): string
    {
        $stmt = execQuery(
            '
                SELECT t2.admin_name, t2.fname, t2.lname, t2.admin_type
                FROM tickets t1
                LEFT JOIN admin AS t2 ON (t1.ticket_from = t2.admin_id)
                WHERE t1.ticket_id = ?
            ',
            [$ticketId]
        );
        $stmt->rowCount() or View::showBadRequestErrorPage();
        $row = $stmt->fetch();
        return $row['fname'] . ' ' . $row['lname'] . ' (' . ($row['admin_type'] == 'user' ? decodeIdna($row['admin_name']) : $row['admin_name']) . ')';
    }

    /**
     * Returns the last modification date of a ticket
     *
     * @param int $ticketId Ticket to get last date for
     * @return string Last modification date of a ticket
     */
    private static function ticketGetLastDate(int $ticketId): string
    {
        $stmt = execQuery('SELECT ticket_date FROM tickets WHERE ticket_reply = ? ORDER BY ticket_date DESC LIMIT 1', [$ticketId]);
        if (!$stmt->rowCount()) {
            return tr('Never');
        }

        return date(Application::getInstance()->getConfig()['DATE_FORMAT'], $stmt->fetchColumn());
    }

    /**
     * Gets the answers of the selected ticket and generates its output.
     *
     * @param TemplateEngine $tpl The Template object
     * @param int $ticketId Id of the ticket to display
     * @çeturn void
     */
    private static function showTicketReplies(TemplateEngine $tpl, int $ticketId): void
    {
        $stmt = execQuery(
            'SELECT ticket_id, ticket_urgency, ticket_date, ticket_message FROM tickets WHERE ticket_reply = ? ORDER BY ticket_date DESC', [$ticketId]
        );

        if (!$stmt->rowCount()) {
            return;
        }

        while ($row = $stmt->fetch()) {
            $tpl->assign([
                'TICKET_FROM_VAL'    => static::getTicketSender($row['ticket_id']),
                'TICKET_DATE_VAL'    => date(Application::getInstance()->getConfig()['DATE_FORMAT'] . ' (H:i)', $row['ticket_date']),
                'TICKET_CONTENT_VAL' => nl2br(toHtml($row['ticket_message']))
            ]);
            $tpl->parse('TICKET_MESSAGE', '.ticket_message');
        }
    }

    /**
     * Notify users for new tickets and ticket answers
     *
     * @param int $toId ticket recipient
     * @param string $ticketSubject ticket subject
     * @param string $ticketMessage ticket content / message
     * @param int $ticketStatus ticket status
     * @param int $urgency ticket urgency
     * @return bool TRUE on success, FALSE on failure
     */
    private static function sendTicketNotification(int $toId, string $ticketSubject, string $ticketMessage, int $ticketStatus, int $urgency): bool
    {
        $stmt = execQuery('SELECT admin_name, fname, lname, email, admin_name FROM admin WHERE admin_id = ?', [$toId]);
        $toData = $stmt->fetch();

        if ($ticketStatus == 0) {
            $message = tr('Dear {NAME},

You have a new support ticket:

==========================================================================
Priority: {PRIORITY}

{MESSAGE}
==========================================================================

You can login at {BASE_SERVER_VHOST_PREFIX}{BASE_SERVER_VHOST}{BASE_SERVER_VHOST_PORT} to answer.

Please do not reply to this email.

___________________________
i-MSCP Mailer');
        } else {
            $message = tr('Dear {NAME},

You have a new answer to a support ticket:

==========================================================================
Priority: {PRIORITY}

{MESSAGE}
==========================================================================

You can login at {BASE_SERVER_VHOST_PREFIX}{BASE_SERVER_VHOST}{BASE_SERVER_VHOST_PORT} to answer.

Please do not reply to this email.

___________________________
i-MSCP Mailer');
        }

        $ret = Mail::sendMail([
            'mail_id'      => 'support-ticket-notification',
            'fname'        => $toData['fname'],
            'lname'        => $toData['lname'],
            'username'     => $toData['admin_name'],
            'email'        => $toData['email'],
            'subject'      => "i-MSCP - [Ticket] $ticketSubject",
            'message'      => $message,
            'placeholders' => [
                '{PRIORITY}' => static::getTicketUrgency($urgency),
                '{MESSAGE}'  => $ticketMessage,
            ]
        ]);

        if (!$ret) {
            writeLog(sprintf("Couldn't send ticket notification to %s", $toData['admin_name']), E_USER_ERROR);
            return false;
        }

        return true;
    }
}
