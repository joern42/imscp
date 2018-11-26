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

/**
 * Class AdminForm
 * @package iMSCP\Form
 */
class AdminForm extends Form
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct($name, $options);

        $this->setAttribute('method', 'post');
        $this
            // Login data
            ->add([
                'type' => LoginDataFieldset::class,
                'name' => 'loginData'
            ])
            // Personal data
            ->add([
                'type' => PersonalDataFieldset::class,
                'name' => 'personalData'
            ])
            // CSRF
            ->add([
                'type'    => Element\Csrf::class,
                'name'    => 'csrf',
                'options' => [
                    'csrf_options' => [
                        'timeout' => 300,
                        'message' => tr('Validation token (CSRF) was expired. Please try again.')
                    ]
                ]
            ]);
    }

    /**
     * @inheritdoc
     */
    public function init()
    {
        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitAdminForm', $this);
    }
}
