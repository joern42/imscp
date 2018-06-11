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
 * Class UserPersonalDataFieldset
 * @package iMSCP\Form
 */
class UserPersonalDataFieldset extends Fieldset implements InputFilterProviderInterface
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct($name ?: 'user-personal-data-fieldset', $options);

        $this
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'fname',
                'options' => ['label' => tr('First name')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'lname',
                'options' => ['label' => tr('Last name')]
            ])
            ->add([
                'type'    => Element\Select::class,
                'name'    => 'gender',
                'options' => ['label' => tr('Gender')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'firm',
                'options' => ['label' => tr('Company')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'street1',
                'options' => ['label' => tr('Street 1')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'street2',
                'options' => ['label' => tr('Street 2')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'zip',
                'options' => ['label' => tr('Zip/Postal code')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'city',
                'options' => ['label' => tr('City')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'state',
                'options' => ['label' => tr('State/Province')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'country',
                'options' => ['label' => tr('Country')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'email',
                'options' => ['label' => tr('Email')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'phone',
                'options' => ['label' => tr('Phone')]
            ])
            ->add([
                'type'    => Element\Text::class,
                'name'    => 'fax',
                'options' => ['label' => tr('Fax')]
            ]);

        // Make 3rd-party components able to modify that fieldset
        Application::getInstance()->getEventManager()->trigger('onInitUserPersonalDataFieldset', $this);
    }

    /**
     * @inheritdoc
     */
    public function getInputFilterSpecification()
    {
        return [
            'fname'   => [
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'required'   => false,
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The first name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'lname'   => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The last name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'gender'  => [
                'validators' => [
                    [
                        'name'    => Validator\InArray::class,
                        'options' => [
                            'haystack' => ['M', 'F', 'U'],
                            'strict'   => true,
                            'message'  => tr('Invalid gender.')
                        ]
                    ]
                ]
            ],
            'firm'    => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The first name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'street1' => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The first name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'street2' => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The first name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'zip'     => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 10,
                            'message' => tr('The zipcode must be between %d and %d characters.', 1, 10)
                        ]
                    ]
                ]
            ],
            'city'    => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The city name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'state'   => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The state/province name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'country' => [
                'required'   => false,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\StringLength::class,
                        'options' => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The country name must be between %d and %d characters.', 1, 200)
                        ]
                    ]
                ]
            ],
            'email'   => [
                'required'   => true,
                'filters'    => [
                    ['name' => Filter\StringToLower::class]
                ],
                'validators' => [
                    [
                        'name'                   => Validator\NotEmpty::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'type'    => 'string',
                            'message' => tr('The email address field cannot be empty.')
                        ]
                    ],
                    [
                        'name'    => Validator\EmailAddress::class,
                        'options' => [
                            'message' => tr('Invalid email address.')
                        ]
                    ]
                ]
            ],
            'phone'   => [
                'required'   => false,
                'validators' => [
                    [
                        'name'                   => Validator\StringLength::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The phone number must be between %d and %d characters.', 1, 200)
                        ]
                    ],
                    [
                        'name'    => Validator\Regex::class,
                        'options' => [
                            'pattern' => '/^[0-9()\s.+-]+$/',
                            'message' => tr('Invalid phone.')
                        ]
                    ]
                ]
            ],
            'fax'     => [
                'required'   => false,
                'validators' => [
                    [
                        'name'                   => Validator\StringLength::class,
                        'break_chain_on_failure' => true,
                        'options'                => [
                            'min'     => 1,
                            'max'     => 200,
                            'message' => tr('The fax number must be between %d and %d characters.', 1, 200)
                        ]
                    ],
                    [
                        'name'    => Validator\Regex::class,
                        'options' => [
                            'pattern' => '/^[0-9()\s.+-]+$/',
                            'message' => tr('Invalid fax.')
                        ]
                    ]
                ]
            ]
        ];
    }
}
