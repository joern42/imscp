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

use iMSCP\Application;
use iMSCP\Crypt;
use iMSCP\Events;
use iMSCP\TemplateEngine;
use Zend\EventManager\Event;
use Zend\Navigation\Navigation;

/**
 * Retrieve GUI properties of the given user
 *
 * @param  int $userId User unique identifier
 * @return array
 */
function getUserGuiProperties($userId)
{
    $cfg = \iMSCP\Application::getInstance()->getConfig();
    $stmt = execQuery('SELECT lang, layout FROM user_gui_props WHERE user_id = ?', [$userId]);

    if (!$stmt->rowCount()) {
        return [$cfg['USER_INITIAL_LANG'], $cfg['USER_INITIAL_THEME']];
    }

    $row = $stmt->fetch();

    if (empty($row['lang']) && empty($row['layout'])) {
        return [$cfg['USER_INITIAL_LANG'], $cfg['USER_INITIAL_THEME']];
    }

    if (empty($row['lang'])) {
        return [$cfg['USER_INITIAL_LANG'], $row['layout']];
    }

    if (empty($row['layout'])) {
        return [$row['lang'], $cfg['USER_INITIAL_THEME']];
    }

    return [$row['lang'], $row['layout']];
}

/**
 * Sets a page message to display on client browser
 *
 * @param string $message $message Message to display
 * @param string $level Message level (static_)?(info|warning|error|success)
 * @return void
 */
function setPageMessage(string $message, string $level = 'info'): void
{
    Application::getInstance()->getFlashMessenger()->addMessage($message, strtolower($level));
}

/**
 * Generates page messages
 *
 * @param TemplateEngine $tpl
 * @return void
 */
function generatePageMessage(TemplateEngine $tpl)
{
    $flashMessenger = Application::getInstance()->getFlashMessenger();
    
    Application::getInstance()->getEventManager()->trigger(Events::onGeneratePageMessages, $flashMessenger);

    $tpl->assign('PAGE_MESSAGE', '');

    foreach (['success', 'error', 'warning', 'info', 'static_success', 'static_error', 'static_warning', 'static_info'] as $level) {
        // Get messages that have been added to the current namespace within this request and remove them from the flash messenger
        $messages = $flashMessenger->getCurrentMessages($level);
        $flashMessenger->clearCurrentMessages($level);

        //
        $messages = array_merge($messages, $flashMessenger->getMessages($level));
        $flashMessenger->clearMessages($level);

        if (empty($messages)) {
            continue;
        }

        print implode("<br>\n", array_unique($messages));
        continue;
        $tpl->assign([
            'MESSAGE_CLS' => $level,
            'MESSAGE'     => implode("<br>\n", array_unique($messages))
        ]);
        $tpl->parse('PAGE_MESSAGE', '.page_message');
    }
}

/**
 * format message(s) to be displayed on client browser as page message
 *
 * @param  string|array $messages Message or stack of messages to be concatenated
 * @return string Concatenated messages
 */
function formatMessage($messages)
{
    $string = '';

    if (is_array($messages)) {
        foreach ($messages as $message) {
            $string .= $message . "<br>\n";
        }
    } elseif (is_string($messages)) {
        $string = $messages;
    } else {
        throw new \Exception('set_page_message() expects a string or an array for $messages.');
    }

    return $string;
}

/**
 * Gets menu variables
 *
 * @param  string $menuLink Menu link
 * @return mixed
 */
function getMenuVariables($menuLink)
{
    if (strpos($menuLink, '}') === false || strpos($menuLink, '}') === false) {
        return $menuLink;
    }

    $session = Application::getInstance()->getSession();
    $row = execQuery('SELECT fname, lname, firm, zip, city, state, country, email, phone, fax, street1, street2 FROM admin WHERE admin_id = ?', [
        $session['user_id']
    ])->fetch();

    $search = [];
    $replace = [];

    $search [] = '{uid}';
    $replace[] = $session['user_id'];
    $search [] = '{uname}';
    $replace[] = toHtml($session['user_logged']);
    $search [] = '{fname}';
    $replace[] = toHtml($row['fname']);
    $search [] = '{lname}';
    $replace[] = toHtml($row['lname']);
    $search [] = '{company}';
    $replace[] = toHtml($row['firm']);
    $search [] = '{zip}';
    $replace[] = toHtml($row['zip']);
    $search [] = '{city}';
    $replace[] = toHtml($row['city']);
    $search [] = '{state}';
    $replace[] = toHtml($row['state']);
    $search [] = '{country}';
    $replace[] = toHtml($row['country']);
    $search [] = '{email}';
    $replace[] = toHtml($row['email']);
    $search [] = '{phone}';
    $replace[] = toHtml($row['phone']);
    $search [] = '{fax}';
    $replace[] = toHtml($row['fax']);
    $search [] = '{street1}';
    $replace[] = toHtml($row['street1']);
    $search [] = '{street2}';
    $replace[] = toHtml($row['street2']);

    $row = execQuery('SELECT domain_name, domain_admin_id FROM domain WHERE domain_admin_id = ?', [$session['user_id']])->fetch();
    $search [] = '{domain_name}';
    $replace[] = $row['domain_name'];
    return str_replace($search, $replace, $menuLink);
}

/**
 * Returns colors set for current layout
 *
 * @return array
 */
function getLayoutColorsSet()
{
    static $colorSet = NULL;

    if (NULL !== $colorSet) {
        return $colorSet;
    }

    $cfg = Application::getInstance()->getConfig();
    if (file_exists($cfg['ROOT_TEMPLATE_PATH'] . '/info.php')) {
        $themeInfo = include_once($cfg['ROOT_TEMPLATE_PATH'] . '/info.php');
        if (is_array($themeInfo)) {
            $colorSet = (array)$themeInfo['theme_color_set'];
        } else {
            throw new RuntimeException(sprintf("'theme_color'_set parameter missing in %s file", $cfg['ROOT_TEMPLATE_PATH'] . '/info.php'));
        }
    } else {
        throw new RuntimeException(sprintf("Couldn't read %s file", $cfg['ROOT_TEMPLATE_PATH'] . '/info.php'));
    }

    return $colorSet;
}

/**
 * Returns layout color for given user
 *
 * @param int $userId user unique identifier
 * @return string User layout color
 */
function getLayoutColor($userId)
{
    static $layoutColor = NULL;

    if (NULL !== $layoutColor) {
        return $layoutColor;
    }

    $session = Application::getInstance()->getSession();

    if (isset($session['user_theme_color'])) {
        $layoutColor = $session['user_theme_color'];
        return $layoutColor;
    }

    $allowedColors = getLayoutColorsSet();
    $layoutColor = execQuery('SELECT layout_color FROM user_gui_props WHERE user_id = ?', [$userId])->fetchColumn();

    if (!$layoutColor || !in_array($layoutColor, $allowedColors)) {
        $layoutColor = array_shift($allowedColors);
    }

    return $layoutColor;
}

/**
 * Init layout
 *
 * @param Event $event
 * @return void
 * @todo Use cookies to store user UI properties (Remember me implementation?)
 */
function initLayout(Event $event)
{
    $cfg = Application::getInstance()->getConfig();

    if ($cfg['DEBUG']) {
        $themesAssetsVersion = time();
    } else {
        $themesAssetsVersion = $cfg['THEME_ASSETS_VERSION'];
    }

    $session = Application::getInstance()->getSession();

    if (isset($session['user_theme_color'])) {
        $color = $session['user_theme_color'];
    } elseif (isset($session['user_id'])) {
        $userId = isset($session['logged_from_id']) ? $session['logged_from_id'] : $session['user_id'];
        $color = getLayoutColor($userId);
        $session['user_theme_color'] = $color;
    } else {
        $color = getLayoutColorsSet()[0];
    }

    /** @var $tpl TemplateEngine */
    $tpl = $event->getParam('templateEngine');
    $tpl->assign([
        'THEME_CHARSET'        => 'UTF-8',
        'THEME_ASSETS_PATH'    => '/themes/' . $cfg['USER_INITIAL_THEME'] . '/assets',
        'THEME_ASSETS_VERSION' => $themesAssetsVersion,
        'THEME_COLOR'          => $color,
        'ISP_LOGO'             => isset($session['user_id']) ? getUserLogo() : '',
        'JS_TRANSLATIONS'      => getJsTranslations()
    ]);
    $tpl->parse('LAYOUT', $event->getParam('layout') ?: 'layout');
}

/**
 * Sets given layout color for given user
 *
 * @param int $userId User unique identifier
 * @param string $color Layout color
 * @return bool TRUE on success false otherwise
 */
function setLayoutColor($userId, $color)
{
    if (!in_array($color, getLayoutColorsSet())) {
        return false;
    }

    execQuery('UPDATE user_gui_props SET layout_color = ? WHERE user_id = ?', [$color, $userId]);

    // Dealing with sessions across multiple browsers for same user identifier - Begin

    $session = Application::getInstance()->getSession();
    $sessionId = $session->getManager()->getId();
    $stmt = execQuery('SELECT session_id FROM login WHERE user_name = ? AND session_id <> ?', [encodeIdna($sessionId['user_logged']), $sessionId]);

    if (!$stmt->rowCount()) {
        return true;
    }

    foreach ($stmt->fetchAll(\PDO::FETCH_COLUMN) as $otherSessionId) {
        $session->getManager()->writeClose();
        $session->getManager()->setId($otherSessionId);
        $sessionId['user_theme_color'] = $color; // Update user layout color
    }

    // Return back to the previous session
    $session->getManager()->writeClose();
    $session->getManager()->setId($sessionId);

    // Dealing with data across multiple sessions - End
    return true;
}

/**
 * Get user logo path
 *
 * Only administrators and resellers can have their own logo.
 *
 * Search is done in the following order: user logo -> user's creator logo -> theme logo --> isp logo
 *
 * @param bool $searchForCreator Tell whether or not search must be done for user's creator in case no logo is found for user
 * @param bool $returnDefault Tell whether or not default logo must be returned
 * @return string User logo path.
 * @todo cache issues
 */
function getUserLogo($searchForCreator = true, $returnDefault = true)
{
    $cfg = Application::getInstance()->getConfig();
    $session = Application::getInstance()->getSession();

    // On switched level, we want show logo from logged user
    if (isset($session['logged_from_id']) && $searchForCreator) {
        $userId = $session['logged_from_id'];
        // Customers inherit the logo of their reseller
    } elseif ($session['user_type'] == 'user') {
        $userId = $session['user_created_by'];
    } else {
        $userId = $session['user_id'];
    }

    $stmt = execQuery('SELECT logo FROM user_gui_props WHERE user_id= ?', [$userId]);

    // No logo is found for the user, let see for it creator
    if (!$stmt->rowCount() && $searchForCreator && $userId != 1) {
        $stmt = execQuery('SELECT b.logo FROM admin a LEFT JOIN user_gui_props b ON (b.user_id = a.created_by) WHERE a.admin_id= ?', [$userId]);
    }

    $logo = $stmt->fetchColumn();

    // No user logo found
    if (!$logo || !file_exists($cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/ispLogos/' . $logo)) {
        if (!$returnDefault) {
            return '';
        }

        if (file_exists($cfg['ROOT_TEMPLATE_PATH'] . '/assets/images/imscp_logo.png')) {
            return '/themes/' . $session['user_theme'] . '/assets/images/imscp_logo.png';
        }

        // no logo available, we are using default
        return $cfg['ISP_LOGO_PATH'] . '/' . 'isp_logo.gif';
    }

    return $cfg['ISP_LOGO_PATH'] . '/' . $logo;
}

/**
 * Set user logo
 *
 * Note: Only administrators and resellers can have their own logo.
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function setUserLogo()
{
    $cfg = Application::getInstance()->getConfig();
    $session = Application::getInstance()->getSession();

    // closure that is run before move_uploaded_file() function - See the
    // Utils_UploadFile() function for further information about implementation
    // details
    $beforeMove = function ($cfg) use ($session) {
        $tmpFilePath = $_FILES['logoFile']['tmp_name'];

        // Checking file mime type
        if (!($fileMimeType = validateMimeType($tmpFilePath, ['image/gif', 'image/jpeg', 'image/pjpeg', 'image/png']))) {
            setPageMessage(tr('You can only upload images.'), 'error');
            return false;
        }

        // Retrieving file extension (gif|jpeg|png)
        if ($fileMimeType == 'image/pjpeg' || $fileMimeType == 'image/jpeg') {
            $fileExtension = 'jpeg';
        } else {
            $fileExtension = substr($fileMimeType, -3);
        }

        // Getting the image size
        list($imageWidth, $imageHeight) = getimagesize($tmpFilePath);

        // Checking image size
        if ($imageWidth > 500 || $imageHeight > 90) {
            setPageMessage(tr('Images have to be smaller than 500 x 90 pixels.'), 'error');
            return false;
        }

        // Building an unique file name
        $filename = sha1(Crypt::randomStr(15) . '-' . $session['user_id']) . '.' . $fileExtension;

        // Return destination file path
        return $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/ispLogos/' . $filename;
    };

    if (($logoPath = uploadFile('logoFile', [$beforeMove, $cfg])) === false) {
        return false;
    }

    if ($session['user_type'] == 'admin') {
        $userId = 1;
    } else {
        $userId = $session['user_id'];
    }

    // We must catch old logo before update
    $oldLogoFile = getUserLogo(false, false);

    execQuery('UPDATE user_gui_props SET logo = ? WHERE user_id = ?', [basename($logoPath), $userId]);

    // Deleting old logo (we are safe here) - We don't return FALSE on failure.
    // The administrator will be warned through logs.
    deleteUserLogo($oldLogoFile, true);
    return true;
}

/**
 * Deletes user logo
 *
 * @param string $logoFilePath OPTIONAL Logo file path
 * @param bool $onlyFile OPTIONAL Tell whether or not only logo file must be
 *                       deleted
 * @return bool TRUE on success, FALSE otherwise
 */
function deleteUserLogo($logoFilePath = NULL, $onlyFile = false)
{
    $cfg = Application::getInstance()->getConfig();
    $session = Application::getInstance()->getSession();

    if (NULL === $logoFilePath) {
        if ($session['user_type'] == 'admin') {
            $logoFilePath = getUserLogo(true);
        } else {
            $logoFilePath = getUserLogo(false);
        }
    }

    $userId = ($session['user_type'] == 'admin') ? 1 : $session['user_id'];
    if (!$onlyFile) {
        execQuery('UPDATE user_gui_props SET logo = ? WHERE user_id = ?', [NULL, $userId]);
    }

    if (strpos($logoFilePath, $cfg['ISP_LOGO_PATH']) === false) {
        return true;
    }

    $logoFilePath = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/ispLogos/' . basename($logoFilePath);
    if (file_exists($logoFilePath) && !@unlink($logoFilePath)) {
        writeLog(sprintf("Couldn't remove the %s file.", $logoFilePath), E_USER_WARNING);
        return false;
    }

    return true;
}

/**
 * Is user logo?
 *
 * @param string $logoPath Logo path to match against
 * @return bool TRUE if $logoPath is a user's logo, FALSE otherwise
 */
function isUserLogo($logoPath)
{
    if ($logoPath == '/themes/' . Application::getInstance()->getSession()['user_theme'] . '/assets/images/imscp_logo.png'
        || $logoPath == Application::getInstance()->getConfig()['ISP_LOGO_PATH'] . '/' . 'isp_logo.gif'
    ) {
        return false;
    }

    return true;
}

/**
 * Load navigation file for current UI level
 *
 * @return void
 */
function loadNavigation()
{
    $session = Application::getInstance()->getSession();

    if (!isset($session['user_type'])) {
        return;
    }

    switch ($session['user_type']) {
        case 'admin':
            $userLevel = 'admin';
            break;
        case 'reseller':
            $userLevel = 'reseller';
            break;
        default:
            $userLevel = 'client';
    }

    Application::getInstance()->getRegistry()->set(
        'navigation', new Navigation(include(Application::getInstance()->getConfig()['ROOT_TEMPLATE_PATH'] . "/$userLevel/navigation.php"))
    );

    // Set main menu labels visibility for the current environment
    Application::getInstance()->getEventManager()->attach(Events::onBeforeGenerateNavigation, 'setMainMenuLabelsVisibilityEvt');
}

/**
 * Tells whether or not main menu labels are visible for the given user
 *
 * @param int $userId User unique identifier
 * @return bool
 */
function isMainMenuLabelsVisible($userId)
{
    return (bool)execQuery('SELECT show_main_menu_labels FROM user_gui_props WHERE user_id = ?', [$userId])->fetchColumn();
}

/**
 * Sets main menu label visibility for the given user
 *
 * @param int $userId User unique identifier
 * @param int $visibility (0|1)
 * @return void
 */
function setMainMenuLabelsVisibility($userId, $visibility)
{
    $visibility = ($visibility) ? 1 : 0;
    execQuery('UPDATE user_gui_props SET show_main_menu_labels = ? WHERE user_id = ?', [$visibility, $userId]);

    $session = Application::getInstance()->getSession();
    if (!isset($session['logged_from_id'])) {
        $session['show_main_menu_labels'] = $visibility;
    }
}

/**
 * Sets main menu visibility for current environment
 *
 * @return void
 */
function setMainMenuLabelsVisibilityEvt()
{
    $session = Application::getInstance()->getSession();
    if (!isset($session['show_main_menu_labels']) && isset($session['user_type'])) {
        $userId = isset($session['logged_from_id']) ? $session['logged_from_id'] : $session['user_id'];
        $session['show_main_menu_labels'] = isMainMenuLabelsVisible($userId);
    }
}
