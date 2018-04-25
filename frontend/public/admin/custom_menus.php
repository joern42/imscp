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

namespace iMSCP;

use iMSCP\Functions\Login;
use iMSCP\Functions\View;
use Zend\EventManager\Event;

/**
 * Generates menus list
 *
 * @param TemplateEngine $tpl Template engine instance
 * @return void
 */
function admin_generateMenusList(TemplateEngine $tpl)
{
    $stmt = execQuery('SELECT * FROM custom_menus');

    if (!$stmt->rowCount()) {
        $tpl->assign('MENUS_LIST_BLOCK', '');
        setPageMessage(tr('No custom menu found.'), 'static_info');
        return;
    }

    while ($row = $stmt->fetch()) {
        if ($row['menu_level'] == 'A') {
            $row['menu_level'] = tr('Administrator');
        } elseif ($row['menu_level'] == 'R') {
            $row['menu_level'] = tr('Reseller');
        } elseif ($row['menu_level'] == 'C') {
            $row['menu_level'] = tr('Customer');
        } elseif ($row['menu_level'] == 'AR') {
            $row['menu_level'] = tr('Administrator and reseller');
        } elseif ($row['menu_level'] == 'AC') {
            $row['menu_level'] = tr('Administrator and customer');
        } elseif ($row['menu_level'] == 'RC') {
            $row['menu_level'] = tr('Reseller and customer');
        } elseif ($row['menu_level'] == 'ARC') {
            $row['menu_level'] = tr('All');
        }

        $tpl->assign([
            'MENU_LINK'    => toHtml($row['menu_link']),
            'MENU_ID'      => $row['menu_id'],
            'LEVEL'        => toHtml($row['menu_level']),
            'ORDER'        => intval($row['menu_order'], 0),
            'MENU_NAME'    => toHtml($row['menu_name']),
            'MENU_NAME_JS' => toJs($row['menu_name']),
            'LINK'         => toHtml($row['menu_link'])
        ]);
        $tpl->parse('MENU_BLOCK', '.menu_block');
    }
}

/**
 * Generate form.
 *
 * @param TemplateEngine $tpl Template engine
 */
function admin_generateForm(TemplateEngine $tpl)
{
    $customMenu = [
        'menu_id'     => '',
        'menu_name'   => '',
        'menu_link'   => '',
        'menu_target' => '_self',
        'menu_level'  => 'a',
        'menu_order'  => 0
    ];

    if (empty($_POST) && isset($_GET['edit_id'])) {
        $stmt = execQuery('SELECT * FROM custom_menus WHERE menu_id = ?', [intval($_GET['edit_id'])]);
        if (!$stmt->rowCount()) {
            setPageMessage(tr("The menu you are trying to edit doesn't exist."), 'error');
            redirectTo('custom_menus.php');
        }
        $customMenu = $stmt->fetch();
    } elseif (!empty($_POST)) {
        $customMenu = $_POST;
    }

    if (isset($_REQUEST['edit_id'])) {
        $tpl->assign([
            'TR_DYNAMIC_TITLE' => toHtml(tr('Edit custom menu')),
            'TR_UPDATE'        => toHtml(tr('Update'), 'htmlAttr'),
            'EDIT_ID'          => toHtml($_REQUEST['edit_id'], 'htmlAttr'),
            'ADD_MENU'         => ''
        ]);
    } else {
        $tpl->assign([
            'TR_DYNAMIC_TITLE' => toHtml(tr('Add custom menu')),
            'TR_ADD'           => toHtml(tr('Add'), 'htmlAttr'),
            'EDIT_MENU'        => ''
        ]);
    }

    foreach (['_blank', '_parent', '_self', '_top'] as $target) {
        $tpl->assign([
            'TR_TARGET'       => toHtml(tr('%s page', str_replace('_', '', $target))),
            'TARGET_VALUE'    => $target,
            'SELECTED_TARGET' => ($customMenu['menu_target'] == $target) ? ' selected' : ''
        ]);
        $tpl->parse('MENU_TARGET_BLOCK', '.menu_target_block');
    }

    foreach ([
                 'A'   => toHtml(tr('Administrator level')),
                 'R'   => toHtml(tr('Reseller level')),
                 'C'   => toHtml(tr('Customer level')),
                 'AR'  => toHtml(tr('Administrator and Reseller levels')),
                 'AC'  => toHtml(tr('Administrator and customer levels')),
                 'RC'  => toHtml(tr('Reseller and customer levels')),
                 'ARC' => toHtml(tr('All levels'))
             ] as $level => $trLevel
    ) {
        $tpl->assign([
            'TR_LEVEL'       => $trLevel,
            'LEVEL_VALUE'    => $level,
            'SELECTED_LEVEL' => ($customMenu['menu_level'] == $level) ? ' selected' : ''
        ]);
        $tpl->parse('MENU_LEVEL_BLOCK', '.menu_level_block');
    }

    $tpl->assign([
        'MENU_NAME'  => toHtml($customMenu['menu_name']),
        'MENU_LINK'  => toHtml($customMenu['menu_link']),
        'MENU_ORDER' => $customMenu['menu_order']
    ]);
}

/**
 * Check if menu is valid
 *
 * @param string $menuName Menu name
 * @param string $menuLink Menu link
 * @param string $menuTarget Menu target
 * @param string $menuLevel Menu level
 * @param int $menuOrder Menu order
 * @return bool TRUE if menu data are valid, FALSE otherwise
 */
function admin_isValidMenu($menuName, $menuLink, $menuTarget, $menuLevel, $menuOrder)
{
    $errorFieldsStack = [];

    if (empty($menuName)) {
        setPageMessage(tr('Invalid name.'), 'error');
        $errorFieldsStack[] = 'menu_name';
    }

    if (empty($menuLink) || !filter_var($menuLink, FILTER_VALIDATE_URL, FILTER_FLAG_SCHEME_REQUIRED | FILTER_FLAG_HOST_REQUIRED)) {
        setPageMessage(tr('Invalid URL.'), 'error');
        $errorFieldsStack[] = 'menu_link';
    }

    if (!empty($menuTarget) && !in_array($menuTarget, ['_blank', '_parent', '_self', '_top'])) {
        setPageMessage(tr('Invalid target.'), 'error');
        $errorFieldsStack[] = 'menu_target';
    }

    in_array($menuLevel, ['A', 'R', 'C', 'AR', 'AC', 'RC', 'ARC']) or View::showBadRequestErrorPage();

    if ($menuOrder !== '' && !isNumber($menuOrder)) {
        setPageMessage(tr('Invalid menu order.'), 'error');
        $errorFieldsStack[] = 'menu_order';
    }

    if (!empty($errorFieldsStack)) {
        Application::getInstance()->getRegistry()->set('errorFieldsStack', $errorFieldsStack);
        return false;
    }

    return true;
}

/**
 * Add custom menu
 *
 * @return bool TRUE on success, FALSE otherwise
 */
function admin_addMenu()
{
    $menuName = isset($_POST['menu_name']) ? cleanInput($_POST['menu_name']) : '';
    $menuLink = isset($_POST['menu_link']) ? cleanInput($_POST['menu_link']) : '';
    $menuTarget = isset($_POST['menu_target']) ? cleanInput($_POST['menu_target']) : '';
    $visibilityLevel = isset($_POST['menu_level']) ? cleanInput($_POST['menu_level']) : '';
    $menuOrder = isset($_POST['menu_order']) ? cleanInput($_POST['menu_order']) : 0;

    if (!admin_isValidMenu($menuName, $menuLink, $menuTarget, $visibilityLevel, $menuOrder)) {
        return false;
    }

    execQuery('INSERT INTO custom_menus (menu_level, menu_order, menu_name, menu_link, menu_target) VALUES (?, ?, ?, ?, ?)', [
        $visibilityLevel, $menuOrder, $menuName, $menuLink, $menuTarget
    ]);
    setPageMessage(tr('Custom menu successfully added.'), 'success');
    return true;
}

/**
 * Update custom menu
 *
 * @param int $menuId menu unique identifier
 * @return bool TRUE on success, FALSE otherwise
 */
function admin_updateMenu($menuId)
{
    $menuName = isset($_POST['menu_name']) ? cleanInput($_POST['menu_name']) : '';
    $menuLink = isset($_POST['menu_link']) ? cleanInput($_POST['menu_link']) : '';
    $menuTarget = isset($_POST['menu_target']) ? cleanInput($_POST['menu_target']) : '';
    $menuLevel = isset($_POST['menu_level']) ? cleanInput($_POST['menu_level']) : '';
    $menuOrder = isset($_POST['menu_order']) ? intval($_POST['menu_order'], 0) : NULL;

    if (!admin_isValidMenu($menuName, $menuLink, $menuTarget, $menuLevel, $menuOrder)) {
        return false;
    }

    execQuery('UPDATE custom_menus SET menu_level = ?, menu_order = ?, menu_name = ?, menu_link = ?, menu_target = ? WHERE menu_id = ?', [
        $menuLevel, $menuOrder, $menuName, $menuLink, $menuTarget, intval($menuId)
    ]);
    setPageMessage(tr('Custom menu successfully updated.'), 'success');
    return true;
}

/**
 * Delete custom menu
 *
 * @param int $menuId menu unique identifier
 * @return void
 */
function admin_deleteMenu($menuId)
{
    $stmt = execQuery('DELETE FROM custom_menus WHERE menu_id = ?', [intval($menuId)]);
    if ($stmt->rowCount()) {
        setPageMessage(tr('Custom menu successfully deleted.'), 'success');
    }
}

Login::checkLogin('admin');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptStart);

if (isset($_POST['uaction'])) {
    if ($_POST['uaction'] == 'menu_add') {
        if (admin_addMenu()) {
            redirectTo('custom_menus.php');
        }
    } elseif ($_POST['uaction'] == 'menu_update' && isset($_POST['edit_id'])) {
        if (admin_updateMenu($_POST['edit_id'])) {
            redirectTo('custom_menus.php');
        }
    } else {
        View::showBadRequestErrorPage();
    }
} elseif (isset($_GET['delete_id'])) {
    admin_deleteMenu($_GET['delete_id']);
}

$tpl = new TemplateEngine();
$tpl->define([
    'layout'            => 'shared/layouts/ui.tpl',
    'page'              => 'admin/custom_menus.tpl',
    'page_message'      => 'layout',
    'menus_list_block'  => 'page',
    'menu_block'        => 'menus_list_block',
    'menu_target_block' => 'page',
    'menu_level_block'  => 'page',
    'add_menu'          => 'page',
    'edit_menu'         => 'page'
]);
$tpl->assign([
    'TR_PAGE_TITLE'             => toHtml(tr('Admin / Settings / {TR_DYNAMIC_TITLE}')),
    'TR_CUSTOM_MENU_PROPERTIES' => toHtml(tr('Custom menu properties')),
    'TR_MENU_NAME'              => toHtml(tr('Name')),
    'TR_MENU_LINK'              => toHtml(tr('Link')),
    'TR_MENU_TARGET'            => toHtml(tr('Target')),
    'TR_VIEW_FROM'              => toHtml(tr('Show in')),
    'TR_MENU_NAME_AND_LINK'     => toHtml(tr('Custom menu name and link')),
    'TR_MENU_ORDER'             => toHtml(tr('Order')),
    'TR_OPTIONAL'               => toHtml(tr('Optional')),
    'TR_ACTIONS'                => toHtml(tr('Actions')),
    'TR_EDIT'                   => toHtml(tr('Edit')),
    'TR_DELETE'                 => toHtml(tr('Delete')),
    'TR_TH_LEVEL'               => toHtml(tr('Level')),
    'TR_TH_ORDER'               => toHtml(tr('Order')),
    'TR_CANCEL'                 => toHtml(tr('Cancel')),
    'TR_MESSAGE_DELETE_JS'      => toJs(tr('Are you sure you want to delete the %s menu?', '%s')),
    'ERR_FIELDS_STACK'          => Application::getInstance()->getRegistry()->has('errorFieldsStack')
        ?  json_encode(Application::getInstance()->getRegistry()->get('errorFieldsStack')) : '[]'
]);

Application::getInstance()->getEventManager()->attach(Events::onGetJsTranslations, function (Event $e) {
    $e->getParam('translations')->core['dataTable'] = View::getDataTablesPluginTranslations(false);
});
View::generateNavigation($tpl);
admin_generateMenusList($tpl);
admin_generateForm($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onAdminScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
