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

use iMSCP\Authentication\AuthenticationService;
use iMSCP\Form\HostingPlanForm;
use iMSCP\Functions\Counting;
use iMSCP\Functions\View;
use Zend\EventManager\Event;
use Zend\Form\Form;

require_once 'application.php';

Application::getInstance()->getAuthService()->checkIdentity(AuthenticationService::RESELLER_IDENTITY_TYPE);
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptStart);

global $form;
($form = new HostingPlanForm('HostingPlan'))
    ->get('submit')
    ->setLabel( tr('Add'));

/*
if (Application::getInstance()->getRequest()->isPost() createHostingPlan()) {
    View::setPageMessage(tr('Hosting plan successfully created.'), 'success');
    redirectTo('hosting_plan.php');
}
*/

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                                  => 'shared/layouts/ui.tpl',
    'page'                                    => 'shared/partials/hosting_plan.phtml',
    'page_message'                            => 'layout',
]);
$tpl->assign([
    'TR_PAGE_TITLE'                 => toHtml(tr('Reseller / Hosting Plans / Add Hosting Plan')),
]);
/** @noinspection PhpUndefinedFieldInspection */
$tpl->form = $form;
View::generateNavigation($tpl);
View::generatePageMessages($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Application::getInstance()->getEventManager()->trigger(Events::onResellerScriptEnd, NULL, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();
