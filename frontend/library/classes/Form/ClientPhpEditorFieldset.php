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
 * Class ClientPhpEditorFieldset
 * @package iMSCP\Form
 */
class ClientPhpEditorFieldset extends Fieldset
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
                'name'     => 'php_ini_system',
                'required' => true,
                'options'  => ['label' => tr('PHP editor')]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'phg_ini_config_level',
                'required' => true,
                'options'  => [
                    'label'         => tr('PHP configuration level'),
                    'value_options' => [
                        'per_site'   => tr('Per site'),
                        'per_domain' => tr('Per domain'),
                        'per_user'   => tr('Per user')
                    ]
                ]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'php_ini_allow_url_fopen',
                'required' => true,
                'options'  => ['label' => tr('Allow URL fopen')]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'php_ini_display_error',
                'required' => true,
                'options'  => ['label' => tr('Display errors')]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'php_ini_disable_functions',
                'required' => true,
                'options'  => ['label' => tr('Disable functions')]
            ])
            ->add([
                'type'     => Element\Radio::class,
                'name'     => 'php_ini_mail_function',
                'required' => true,
                'options'  => ['label' => tr('Mail function')]
            ])
            ->add([
                'type'     => Element\Number::class,
                'name'     => 'php_ini_post_max_size',
                'required' => true,
                'options'  => ['label' => tr('POST max size')]
            ])
            ->add([
                'type'     => Element\Number::class,
                'name'     => 'php_ini_upload_max_file_size',
                'required' => true,
                'options'  => ['label' => tr('Upload max file size')]
            ])
            ->add([
                'type'     => Element\Number::class,
                'name'     => 'php_ini_max_execution_time',
                'required' => true,
                'options'  => ['label' => tr('Max execution time')]
            ])
            ->add([
                'type'     => Element\Number::class,
                'name'     => 'php_ini_max_input_time',
                'required' => true,
                'options'  => ['label' => tr('Max input time')]
            ])
            ->add([
                'type'     => Element\Number::class,
                'name'     => 'php_ini_memory_limit',
                'required' => true,
                'options'  => ['label' => tr('Memory limit')]
            ]);
    }

    /**
     * @inheritdoc
     */
    public function init()
    {
        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitClientPhpEditorFieldset', $this);
    }
}
