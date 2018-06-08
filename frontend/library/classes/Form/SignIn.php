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
use Zend\Filter;
use Zend\Form\Element;
use Zend\Form\Form;
use Zend\InputFilter\InputFilterProviderInterface;
use Zend\Validator;

/**
 * Class SignIn
 * @package iMSCP\Form
 */
class SignIn extends Form implements InputFilterProviderInterface
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct('sign-in-form');

        $this->setAttribute('method', 'post');
        $this->add([
            'type'     => Element\Text::class,
            'name'     => 'admin_name',
            'required' => true,
            'options'  => [
                'label' => toHtml(tr('Username'))
            ]
        ]);
        $this->add([
            'type'    => Element\Password::class,
            'name'    => 'admin_pass',
            'options' => [
                'label' => toHtml(tr('Password'))
            ]
        ]);
        $this->add([
            'type'    => Element\Csrf::class,
            'name'    => 'csrf',
            'options' => [
                'csrf_options' => [
                    'timeout' => 180
                ]
            ]
        ]);
        $this->add([
            'name'     => 'submit',
            'type'     => Element\Submit::class,
            'priority' => -100,
            'options'  => [
                'label' => toHtml('Sign In')
            ]
        ]);

        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitSignInForm', $this);
    }

    /**
     * @inheritdoc
     */
    public function getInputFilterSpecification()
    {
        return [
            'admin_name' => [
                'filters'  => [
                    ['name' => Filter\StringTrim::class],
                ],
                'required' => true
            ],
            'admin_pass' => [
                'required'   => true,
                'filters'    => [
                    ['name' => Filter\StringTrim::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min' => Application::getInstance()->getConfig()['PASSWD_CHARS'] ?? 6,
                            'max' => 30
                        ]
                    ]
                ]
            ]
        ];
    }
}
