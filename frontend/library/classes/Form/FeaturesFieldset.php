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
use Zend\Cache\Exception\LogicException;
use Zend\Form\Element;
use Zend\Form\ElementInterface;
use Zend\Form\Fieldset;
use Zend\Form\FieldsetInterface;

/**
 * Class FeaturesFieldset
 * @package iMSCP\Form
 */
class FeaturesFieldset extends Fieldset
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct($name, $options);

        $this
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'php',
                'required' => true,
                'options'  => [
                    'label'         => tr('PHP'),
                    'value_options' => [
                        '0' => tr('No'),
                        '1' => tr('Yes'),
                    ]
                ]
            ])
            ->add([
                'type' => ClientPhpEditorFieldset::class,
                'name' => 'phpEditor'
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'cgi',
                'required' => true,
                'options'  => [
                    'label'         => tr('CGI'),
                    'value_options' => [
                        '0' => tr('No'),
                        '1' => tr('Yes'),
                    ]
                ]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'dns',
                'required' => true,
                'options'  => [
                    'label'         => tr('Custom DNS records'),
                    'value_options' => [
                        '0' => tr('No'),
                        '1' => tr('Yes'),
                    ]
                ]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'dnsEditor',
                'required' => true,
                'options'  => [
                    'label'         => tr('DNS editor'),
                    'value_options' => [
                        '0' => tr('No'),
                        '1' => tr('Yes'),
                    ]
                ]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'externalMailServer',
                'required' => true,
                'options'  => ['label' => tr('External mail server')]
            ])
            
            ->add([
                'type'     => Element\MultiCheckbox::class,
                'name'     => 'backup',
                'required' => true,
                'options'  => [
                    'label'         => tr('Backup'),
                    'value_options' => [
                        'dmn'  => tr('Web data'),
                        'sql'  => tr('SQL data'),
                        'mail' => tr('Mail data')
                    ]
                ]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'supportSystem',
                'required' => true,
                'options'  => [
                    'label'         => tr('Support system'),
                    'value_options' => [
                        '0' => tr('No'),
                        '1' => tr('Yes'),
                    ]
                ]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'webFolderProtection',
                'required' => true,
                'options'  => [
                    'label'         => tr('Web folder protection'),
                    'value_options' => [
                        '0' => tr('No'),
                        '1' => tr('Yes'),
                    ]
                ]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'webstats',
                'required' => true,
                'options'  => [
                    'label'         => tr('Web statistics through AWStats'),
                    'value_options' => [
                        '0' => tr('No'),
                        '1' => tr('Yes')
                    ]
                ]
            ]);

        $this->setDefaults();
    }

    /**
     * @inheritdoc
     */
    public function init()
    {
        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitFeaturesFieldset', $this);
    }

    /**
     * Set defaults according current context (admin, reseller)
     *
     * @return void
     */
    protected function setDefaults(): void
    {
        // FIXME: Really?
        if(Application::getInstance()->getRequest()->isPost()) {
            return;
        }

        switch (Application::getInstance()->getAuthService()->getIdentity()->getUserType()) {
            case 'admin': // Administrator setting up features for a reseller
                /** @var ElementInterface $element */
                foreach($this->getElements() as $element) {
                    if($element instanceof Element\Radio) {
                        $element->setValue('1');
                        continue;
                    }
                    
                    if($element instanceof Element\MultiCheckbox) {
                        $element->setValue(['dmn', 'mail', 'sql']);
                    }
                }
                break;
            case 'reseller': // Reseller setting up features for a client
                // TODO: We need operate differently if reseller has not permissions on one of elements
                break;
            default:
                throw new LogicException('Attempt to set defaults from unexpected context');

        }
    }
}
