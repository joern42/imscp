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
use Zend\Form\Fieldset;
use Zend\InputFilter\InputFilterProviderInterface;
use Zend\Validator;

/**
 * Class LoginDataFieldset
 * @package iMSCP\Form
 */
class LoginDataFieldset extends Fieldset implements InputFilterProviderInterface
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct($name, $options);

        $this
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'username',
                'options' => ['label' => tr('Username')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'password',
                'options' => ['label' => tr('Password')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'passwordConfirmation',
                'options' => ['label' => tr('Password confirmation')]
            ]);
    }

    /**
     * @inheritdoc
     */
    public function init()
    {
        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitLoginDataFieldset', $this);
    }

    /**
     * @inheritdoc
     */
    public function getInputFilterSpecification()
    {
        $minPasswordLength = Application::getInstance()->getConfig()['PASSWD_CHARS'] ?? 6;
        $specifications = [
            'username'              => [
                'required'   => true,
                'filters'    => [
                    ['name' => Filter\StringTrim::class]
                ],
                'validators' => [
                    [
                        'name'                   => Validator\NotEmpty::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'type'    => 'string',
                            'message' => tr('The username field cannot be empty.')
                        ]
                    ],
                    [
                        'name'                   => Validator\StringLength::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'min'     => 2,
                            'max'     => 30,
                            'message' => tr('The username must be between %d and %d characters.', 2, 30)
                        ]
                    ],
                    [
                        'name'                   => Validator\Regex::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'pattern' => '/^[[:alnum:]](?:(?<![-_])(?:-*|[_.])?(?![-_])[[:alnum:]]*)*?(?<![-_.])$/',
                            'message' => tr('Invalid username.')
                        ]
                    ],
                    [
                        'name'    => Validator\Callback::class,
                        'options' => [
                            'callback' => function ($username) {
                                return execQuery('SELECT COUNT(admin_id) FROM admin WHERE admin_name = ?', [$username])->fetchColumn() == 0;
                            },
                            'message'  => tr("The '%value%' username is not available.")
                        ]
                    ]
                ]
            ],
            'password'              => [
                'required'   => true,
                'filters'    => [
                    ['name' => Filter\StringTrim::class]
                ],
                'validators' => [
                    [
                        'name'                   => Validator\NotEmpty::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'type'    => 'string',
                            'message' => tr('The password field cannot be empty.')
                        ]
                    ],
                    [
                        'name'                   => Validator\StringLength::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'min'     => $minPasswordLength,
                            'max'     => 30,
                            'message' => tr('The password must be between %d and %d characters.', $minPasswordLength, 30)
                        ]
                    ],
                    [
                        'name'                   => Validator\Regex::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'pattern' => '/^[\x21-\x7e]+$/',
                            'message' => tr('The password contains unallowed characters.')
                        ]
                    ]
                ]
            ],
            'passwordConfirmation' => [
                'required'   => true,
                'filters'    => [
                    ['name' => Filter\StringTrim::class]
                ],
                'validators' => [
                    [
                        'name'                   => Validator\NotEmpty::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'type'    => 'string',
                            'message' => tr('The password confirmation field cannot be empty.')
                        ]
                    ],
                    [
                        'name'    => Validator\Identical::class,
                        'options' => [
                            'token'   => 'admin_pass',
                            'message' => tr('Passwords do not match.')
                        ]
                    ]
                ]
            ]
        ];

        if (Application::getInstance()->getConfig()['PASSWD_STRONG'] ?? false) {
            $specifications['password']['validators'][] = [
                'name'    => Validator\Regex::class,
                'options' => [
                    'pattern' => '/^(?=.*[a-zA-Z])(?=.*[0-9])/',
                    'message' => tr('The password must contain letters and digits.')
                ]
            ];
        }

        return $specifications;
    }
}
