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
use Zend\Form\Form;
use Zend\InputFilter\InputFilter;
use Zend\Validator;

/**
 * Class SignIn
 * @package iMSCP\Form
 */
class SignIn extends Form
{
    /**
     * @inheritdoc
     */
    public function __construct()
    {
        parent::__construct('sign-in-form');

        $this->setAttribute('method', 'post');
        $this->addElements();
        $this->addInputFilters();

        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitSignInForm', $this);
    }

    /**
     * Add elements
     *
     * @throws \Exception
     * @return void
     */
    protected function addElements()
    {
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
    }

    /**
     * Add input filters
     *
     * @return void
     */
    protected function addInputFilters()
    {
        $cfg = Application::getInstance()->getConfig();
        $minPasswordLength = intval($cfg['PASSWD_CHARS']);

        if ($minPasswordLength < 6) {
            $minPasswordLength = 6;
        }

        // Create main input filter
        $inputFilter = new InputFilter();
        $this->setInputFilter($inputFilter);
        $inputFilter->add([
            'name'     => 'admin_name',
            'filters'  => [
                [
                    'name' => 'StringTrim'
                ],
            ],
            'required' => true,
        ]);
        $inputFilter->add([
            'name'       => 'admin_pass',
            'required'   => true,
            'filters'    => [
                [
                    'name' => 'StringTrim'
                ]
            ],
            'validators' => [
                [
                    'name'    => Validator\StringLength::class,
                    'options' => [
                        'min' => $minPasswordLength,
                        'max' => 30
                    ]
                ]
            ]
        ]);
    }
}
