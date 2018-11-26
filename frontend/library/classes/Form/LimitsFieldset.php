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

namespace iMSCP\Form;

use iMSCP\Application;
use Zend\Form\Element;
use Zend\Form\Fieldset;

/**
 * Class LimitsFieldset
 * @package iMSCP\Form
 */
class LimitsFieldset extends Fieldset
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct($name, $options);
        
        $this
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'domainsLimit',
                'required'   => true,
                'options'    => ['label' => tr('Domains limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'subdomainsLimit',
                'required'   => true,
                'options'    => ['label' => tr('Subdomains limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'domainAliasesLimit',
                'required'   => true,
                'options'    => ['label' => tr('Domain aliases limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'mailboxesLimit',
                'required'   => true,
                'options'    => ['label' => tr('Mail accounts limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'mailQuotaLimit',
                'required'   => true,
                'options'    => ['label' => tr('Mail quota limit [MiB]')],
                'attributes' => [
                    'min' => '0',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'ftpUsersLimit',
                'required'   => true,
                'options'    => ['label' => tr('FTP account limits')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'sqlDatabasesLimit',
                'required'   => true,
                'options'    => ['label' => tr('SQL databases limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'sqlUsersLimit',
                'required'   => true,
                'options'    => ['label' => tr('SQL users limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'monthlyTrafficLimit',
                'required'   => true,
                'options'    => ['label' => tr('Monthly traffic limit [MiB]')],
                'attributes' => [
                    'min' => '0',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'diskspaceLimit',
                'required'   => true,
                'options'    => ['label' => tr('Diskpace limit [MiB]')],
                'attributes' => [
                    'min' => '0',
                    'max' => '17592186044416',
                    'value' => '0'
                ]
            ]);
    }

    /**
     * @inheritdoc
     */
    public function init()
    {
        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitLimitsFieldset', $this);
    }
}
