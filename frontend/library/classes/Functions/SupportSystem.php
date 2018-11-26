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
 * Class SupportSystem
 * @package iMSCP\Functions
 */
class SupportSystem
{
    /**
     * Creates a ticket and informs the recipient
     *
     * @param int $userID User unique identifier
     * @param int $adminID Creator unique identifier
     * @param int $urgency The ticket's urgency
     * @param String $subject Ticket's subject
     * @param String $message Ticket's message
     * @param int $userLevel User's level (client = 1; reseller = 2)
     * @return bool TRUE on success, FALSE otherwise
     */
    public static function createTicket(int $userID, int $adminID, int $urgency, string $subject, string $message, int $userLevel): bool
    {
        if ($userLevel < 1 || $userLevel > 2) {
            View::setPageMessage(tr('Wrong user level provided.'), 'error');
            return false;
        }

        $subject = cleanInput($subject);
        $userMessage = cleanInput($message);

        execQuery(
            '
                INSERT INTO tickets (
                    ticketLevel, ticketFrom, ticketTo, ticketStatus, ticketReply, ticketUrgency, ticketDate, ticketSubject, ticketMessage
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
            ',
            [$userLevel, $userID, $adminID, 1, 0, $urgency, time(), $subject, $userMessage]
        );
        View::setPageMessage(tr('Your message has been successfully sent.'), 'success');
        static::sendTicketNotification($adminID, $subject, $userMessage, 0, $urgency);
        return true;
    }

    /**
     * Gets the content of the selected ticket and generates its output
     *
     * @param TemplateEngine $tpl Template engine
     * @param int $ticketID Id of the ticket to display
     * @param int $userID User unique identifier
     * @return bool TRUE if ticket is found, FALSE otherwise
     */
    public static function showTicketContent(TemplateEngine $tpl, int $ticketID, int $userID): bool
    {
        # Always show last replies first
        static::showTicketReplies($tpl, $ticketID);

        $stmt = execQuery(
            '
                SELECT ticketID, ticketStatus, ticketReply, ticketUrgency, ticketDate, ticketSubject, ticketMessage
                FROM imscp_ticket
                WHERE ticketID = ?
                AND (ticketFrom = ? OR ticketTo = ?)
            ',
            [$ticketID, $userID, $userID]
        );

        if (!$stmt->rowCount()) {
            $tpl->assign('TICKET', '');
            View::setPageMessage(tr("Ticket with Id '%d' was not found.", $ticketID), 'error');
            return false;
        }

        $row = $stmt->fetch();

        if ($row['ticketStatus'] == 0) {
            $trAction = tr('Open ticket');
            $action = 'open';
        } else {
            $trAction = tr('Close the ticket');
            $action = 'close';
        }

        $from = static::getTicketSender($ticketID);
        $tpl->assign([
            'TR_TICKET_ACTION'      => $trAction,
            'TICKET_ACTION_VAL'     => $action,
            'TICKET_DATE_VAL'       => date(Application::getInstance()->getConfig()['DATE_FORMAT'] . ' (H:i)', $row['ticketDate']),
            'TICKET_SUBJECT_VAL'    => toHtml($row['ticketSubject']),
            'TICKET_CONTENT_VAL'    => nl2br(toHtml($row['ticketMessage'])),
            'TICKET_ID_VAL'         => $row['ticketID'],
            'TICKET_URGENCY_VAL'    => static::getTicketUrgency($row['ticketUrgency']),
            'TICKET_URGENCY_ID_VAL' => $row['ticketUrgency'],
            'TICKET_FROM_VAL'       => toHtml($from)
        ]);
        $tpl->parse('TICKET_MESSAGE', '.ticketMessage');
        return true;
    }

    /**
     * Updates a ticket with a new answer and informs the recipient
     *
     * @param int $ticketID id of the ticket's parent ticket
     * @param int $userID User unique identifier
     * @param int $urgency The parent ticket's urgency
     * @param String $subject The parent ticket's subject
     * @param String $message The ticket replys' message
     * @param int $ticketLevel The tickets's level (1 = user; 2 = super)
     * @param int $userLevel The user's level (1 = client; 2 = reseller; 3 = admin)
     * @return void
     */
    public static function updateTicket(int $ticketID, int $userID, int $urgency, string $subject, string $message, int $ticketLevel, int $userLevel): void
    {
        $db = Application::getInstance()->getDb();
        $subject = cleanInput($subject);
        $userMessage = cleanInput($message);
        $stmt = execQuery('SELECT ticketFrom, ticketTo, ticketStatus FROM imscp_ticket WHERE ticketID = ? AND (ticketFrom = ? OR ticketTo = ?)', [
            $ticketID, $userID, $userID
        ]);
        $stmt->rowCount() or View::showBadRequestErrorPage();
        $row = $stmt->fetch();

        try {
            /**
             * Ticket levels:
             *  1: Client -> Reseller
             *  2: Reseller -> Admin
             *  NULL: Reply
             */
            if (($ticketLevel == 1 && $userLevel == 1) || ($ticketLevel == 2 && $userLevel == 2)) {
                $ticketTo = $row['ticketTo'];
                $ticketFrom = $row['ticketFrom'];
            } else {
                $ticketTo = $row['ticketFrom'];
                $ticketFrom = $row['ticketTo'];
            }

            $db->getDriver()->getConnection()->beginTransaction();

            execQuery(
                '
                    INSERT INTO tickets (
                        ticketFrom, ticketTo, ticketStatus, ticketReply, ticketUrgency, ticketDate, ticketSubject, ticketMessage
                    ) VALUES (
                        ?, ?, ?, ?, ?, ?, ?, ?
                    )
                ',
                [$ticketFrom, $ticketTo, NULL, $ticketID, $urgency, time(), $subject, $userMessage]
            );

            if ($userLevel != 2) {
                // Level User: Set ticket status to "client answered"
                if ($ticketLevel == 1 && ($row['ticketStatus'] == 0 || $row['ticketStatus'] == 3)) {
                    static::changeTicketStatus($ticketID, 4);
                    // Level Super: set ticket status to "reseller answered"
                } elseif ($ticketLevel == 2 && ($row['ticketStatus'] == 0 || $row['ticketStatus'] == 3)) {
                    static::changeTicketStatus($ticketID, 2);
                }
            } else {
                // Set ticket status to "reseller answered" or "client answered" depending on ticket
                if ($ticketLevel == 1 && ($row['ticketStatus'] == 0 || $row['ticketStatus'] == 3)) {
                    static::changeTicketStatus($ticketID, 2);
                } elseif ($ticketLevel == 2 && ($row['ticketStatus'] == 0 || $row['ticketStatus'] == 3)) {
                    static::changeTicketStatus($ticketID, 4);
                }
            }

            $db->getDriver()->getConnection()->commit();
            View::setPageMessage(tr('Your message has been successfully sent.'), 'success');
            static::sendTicketNotification($ticketTo, $subject, $userMessage, $ticketID, $urgency);
        } catch (\Exception $e) {
            $db->getDriver()->getConnection()->rollBack();
            throw $e;
        }
    }

    /**
     * Deletes a ticket
     *
     * @param int $ticketID Ticket unique identifier
     * @return void
     */
    public static function deleteTicket(int $ticketID): void
    {
        execQuery('DELETE FROM imscp_ticket WHERE ticketID = ? OR ticketReply = ?', [$ticketID, $ticketID]);
    }

    /**
     * Deletes all open/closed tickets that are belong to a user
     *
     * @param string $status Ticket status ('open' or 'closed')
     * @param int $userID The user's ID
     * @return void
     */
    public static function deleteTickets(string $status, int $userID): void
    {
        $condition = ($status == 'open') ? "ticketStatus != '0'" : "ticketStatus = '0'";
        execQuery("DELETE FROM imscp_ticket WHERE (ticketFrom = ? OR ticketTo = ?) AND {$condition}", [$userID, $userID]);
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
    public static function generateTicketList(TemplateEngine $tpl, int $userID, int $start, int $count, string $userLevel, string $status): void
    {
        $condition = $status == 'open' ? "ticketStatus != 0" : 'ticketStatus = 0';
        $rowsCount = execQuery("SELECT COUNT(ticketID) FROM imscp_ticket WHERE (ticketFrom = ? OR ticketTo = ?) AND ticketReply = '0' AND $condition", [
            $userID, $userID
        ])->fetchColumn();

        if ($rowsCount > 0) {
            $stmt = execQuery(
                "
                    SELECT ticketID, ticketStatus, ticketUrgency, ticketLevel, ticketDate, ticketSubject
                    FROM imscp_ticket
                    WHERE (ticketFrom = ? OR ticketTo = ?)
                    AND ticketReply = 0
                    AND $condition
                    ORDER BY ticketDate DESC
                    LIMIT {$start}, {$count}
                ",
                [$userID, $userID]
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
                if ($row['ticketStatus'] == 1) {
                    $tpl->assign('TICKET_STATUS_VAL', tr('[New]'));
                } elseif ($row['ticketStatus'] == 2 && (($row['ticketLevel'] == 1 && $userLevel == 'client')
                        || ($row['ticketLevel'] == 2 && $userLevel == 'reseller'))
                ) {
                    $tpl->assign('TICKET_STATUS_VAL', tr('[Re]'));
                } elseif ($row['ticketStatus'] == 4 && (($row['ticketLevel'] == 1 && $userLevel == 'reseller')
                        || ($row['ticketLevel'] == 2 && $userLevel == 'admin'))
                ) {
                    $tpl->assign('TICKET_STATUS_VAL', tr('[Re]'));
                } else {
                    $tpl->assign('TICKET_STATUS_VAL', '[Read]');
                }

                $tpl->assign([
                    'TICKET_URGENCY_VAL'   => static::getTicketUrgency($row['ticketUrgency']),
                    'TICKET_FROM_VAL'      => toHtml(static::getTicketSender($row['ticketID'])),
                    'TICKET_LAST_DATE_VAL' => static::ticketGetLastDate($row['ticketID']),
                    'TICKET_SUBJECT_VAL'   => toHtml($row['ticketSubject']),
                    'TICKET_SUBJECT2_VAL'  => addslashes(cleanHtml($row['ticketSubject'])),
                    'TICKET_ID_VAL'        => $row['ticketID']
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
            View::setPageMessage(tr('You have no open tickets.'), 'static_info');
        } else {
            View::setPageMessage(tr('You have no closed tickets.'), 'static_info');
        }
    }

    /**
     * Closes the given ticket.
     *
     * @param int $ticketID Ticket id
     * @return bool TRUE on success, FALSE otherwise
     */
    public static function closeTicket(int $ticketID): bool
    {
        if (!static::changeTicketStatus($ticketID, 0)) {
            View::setPageMessage(tr("Unable to close the ticket with Id '%s'.", $ticketID), 'error');
            writeLog(sprintf("Unable to close the ticket with Id '%s'.", $ticketID), E_USER_ERROR);
            return false;
        }

        View::setPageMessage(tr('Ticket successfully closed.'), 'success');
        return true;
    }

    /**
     * Reopens the given ticket
     *
     * @param int $ticketID Ticket id
     * @return bool TRUE on success, FALSE otherwise
     */
    public static function reopenTicket(int $ticketID): bool
    {
        if (!static::changeTicketStatus($ticketID, 3)) {
            View::setPageMessage(tr("Unable to reopen ticket with Id '%s'.", $ticketID), 'error');
            writeLog(sprintf("Unable to reopen ticket with Id '%s'.", $ticketID), E_USER_ERROR);
            return false;
        }

        View::setPageMessage(tr('Ticket successfully reopened.'), 'success');
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
     * @param int $ticketID Ticket unique identifier
     * @return int ticket status identifier
     */
    public static function getTicketStatus(int $ticketID): int
    {
        $userID = Application::getInstance()->getAuthService()->getIdentity()->getUserId();
        $stmt = execQuery('SELECT ticketStatus FROM imscp_ticket WHERE ticketID = ? AND (ticketFrom = ? OR ticketTo = ?)', [
            $ticketID, $userID, $userID
        ]);

        if (!$stmt->rowCount()) {
            View::setPageMessage(tr("Ticket with Id '%d' was not found.", $ticketID), 'error');
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
     * @param int $ticketID Ticket unique identifier
     * @param int $ticketStatus New status identifier
     * @return bool TRUE if ticket status was changed, FALSE otherwise
     */
    public static function changeTicketStatus(int $ticketID, int $ticketStatus): bool
    {
        $userID = Application::getInstance()->getAuthService()->getIdentity()->getUserId();
        $stmt = execQuery('UPDATE tickets SET ticketStatus = ? WHERE ticketID = ? OR ticketReply = ? AND (ticketFrom = ? OR ticketTo = ?)', [
            $ticketStatus, $ticketID, $ticketID, $userID, $userID
        ]);

        return $stmt->rowCount() > 0;
    }

    /**
     * Reads the user's level from ticket info
     *
     * @param int $ticketID Ticket id
     * @return int User's level (1 = user, 2 = super) or FALSE if ticket is not found
     */
    public static function getUserLevel(int $ticketID): int
    {
        // Get info about the type of message
        $stmt = execQuery('SELECT ticketLevel FROM imscp_ticket WHERE ticketID = ?', [$ticketID]);
        if (!$stmt->rowCount()) {
            View::setPageMessage(tr("Ticket with Id '%d' was not found.", $ticketID), 'error');
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
     * @param int $ticketID Id of the ticket to display
     * @return string Formatted ticket sender
     */
    private static function getTicketSender(int $ticketID): string
    {
        $stmt = execQuery(
            '
                SELECT t2.username, t2.firstName, t2.lastName, t2.type
                FROM imscp_ticket AS t1
                JOIN imscp_user AS t2 ON (t1.ticketFrom = t2.userID)
                WHERE t1.ticketID = ?
            ',
            [$ticketID]
        );
        $stmt->rowCount() or View::showBadRequestErrorPage();
        $row = $stmt->fetch();
        return $row['firstName'] . ' ' . $row['lastName'] . ' (' . ($row['type'] == 'client' ? decodeIdna($row['username']) : $row['username']) . ')';
    }

    /**
     * Returns the last modification date of a ticket
     *
     * @param int $ticketID Ticket to get last date for
     * @return string Last modification date of a ticket
     */
    private static function ticketGetLastDate(int $ticketID): string
    {
        $stmt = execQuery('SELECT ticketDate FROM imscp_ticket WHERE ticketReply = ? ORDER BY ticketDate DESC LIMIT 1', [$ticketID]);
        if (!$stmt->rowCount()) {
            return tr('Never');
        }

        return date(Application::getInstance()->getConfig()['DATE_FORMAT'], $stmt->fetchColumn());
    }

    /**
     * Gets the answers of the selected ticket and generates its output.
     *
     * @param TemplateEngine $tpl The Template object
     * @param int $ticketID Id of the ticket to display
     * @çeturn void
     */
    private static function showTicketReplies(TemplateEngine $tpl, int $ticketID): void
    {
        $stmt = execQuery(
            'SELECT ticketID, ticketUrgency, ticketDate, ticketMessage FROM imscp_ticket WHERE ticketReply = ? ORDER BY ticketDate DESC',
            [$ticketID]
        );

        if (!$stmt->rowCount()) {
            return;
        }

        while ($row = $stmt->fetch()) {
            $tpl->assign([
                'TICKET_FROM_VAL'    => static::getTicketSender($row['ticketID']),
                'TICKET_DATE_VAL'    => date(Application::getInstance()->getConfig()['DATE_FORMAT'] . ' (H:i)', $row['ticketDate']),
                'TICKET_CONTENT_VAL' => nl2br(toHtml($row['ticketMessage']))
            ]);
            $tpl->parse('TICKET_MESSAGE', '.ticketMessage');
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
        $stmt = execQuery('SELECT username, firstName, lastName, email FROM imscp_user WHERE userID = ?', [$toId]);
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
            'fname'        => $toData['firstName'],
            'lname'        => $toData['lastName'],
            'username'     => $toData['username'],
            'email'        => $toData['email'],
            'subject'      => "i-MSCP - [Ticket] $ticketSubject",
            'message'      => $message,
            'placeholders' => [
                '{PRIORITY}' => static::getTicketUrgency($urgency),
                '{MESSAGE}'  => $ticketMessage,
            ]
        ]);

        if (!$ret) {
            writeLog(sprintf("Couldn't send ticket notification to %s", $toData['username']), E_USER_ERROR);
            return false;
        }

        return true;
    }
}
