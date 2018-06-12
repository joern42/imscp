<?php

namespace iMSCP\Form;

use iMSCP\Application;
use Zend\Filter;
use Zend\Form\Element;
use Zend\Form\Form;
use Zend\InputFilter\InputFilterProviderInterface;
use Zend\Validator;

/**
 * Class HostingPlan
 * @package iMSCP\Form
 */
class HostingPlan extends Form implements InputFilterProviderInterface
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct($name ?: 'hosting-plan-form', $options);

        $this->setAttribute('method', 'post');
        $this
            // Name
            ->add([
                'type'     => Element\Text::class,
                'name'     => 'name',
                'required' => true,
                'options'  => ['label' => tr('Name')]
            ])
            // Description
            ->add([
                'type'     => Element\Textarea::class,
                'name'     => 'description',
                'required' => true,
                'options'  => ['label' => tr('Description')]
            ])
            // Limits
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'subdomains_limit',
                'required'   => true,
                'options'    => ['label' => tr('Subdomains limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'domain_aliases_limit',
                'required'   => true,
                'options'    => ['label' => tr('Domain aliases limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'mail_accounts_limit',
                'required'   => true,
                'options'    => ['label' => tr('Mail accounts limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'mail_quota_limit',
                'required'   => true,
                'options'    => ['label' => tr('Mail quota limit [MiB]')],
                'attributes' => [
                    'min' => '0',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'ftp_accounts_limit',
                'required'   => true,
                'options'    => ['label' => tr('FTP account limits')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'sql_databases_limit',
                'required'   => true,
                'options'    => ['label' => tr('SQL databases limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'sql_users_limit',
                'required'   => true,
                'options'    => ['label' => tr('SQL users limit')],
                'attributes' => [
                    'min' => '-1',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'monthly_traffic_limit',
                'required'   => true,
                'options'    => ['label' => tr('Monthly traffic limit [MiB]')],
                'attributes' => [
                    'min' => '0',
                    'max' => '17592186044416'
                ]
            ])
            ->add([
                'type'       => Element\Number::class,
                'name'       => 'diskspace_limit',
                'required'   => true,
                'options'    => ['label' => tr('Diskpace limit [MiB]')],
                'attributes' => [
                    'min' => '0',
                    'max' => '17592186044416'
                ]
            ])
            // Feature
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'php',
                'required' => true,
                'options'  => ['label' => tr('PHP')]
            ])
            
            // TODO: We should have separate fieldset for PHP editor (client properties) which we could reuse - START
            
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'php_ini_system',
                'required' => true,
                'options'  => ['label' => tr('PHP editor')]
            ])
            ->add([
                'type'     => Element\MultiCheckbox::class,
                'name'     => 'phg_ini_config_level',
                'required' => true,
                'options'  => [
                    'label'         => tr('PHP configuration level'),
                    'value_options' => [
                        'per_site'   => tr('Per site'),
                        'per_domain' => tr('Per domain'),
                        'per_user'   => tr('Per user')
                    ],
                ]
            ])
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'php_ini_allow_url_fopen',
                'required' => true,
                'options'  => ['label' => tr('Allow URL fopen')]
            ])
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'php_ini_display_error',
                'required' => true,
                'options'  => ['label' => tr('Display errors')]
            ])
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'php_ini_disable_functions',
                'required' => true,
                'options'  => ['label' => tr('Disable functions')]
            ])
            ->add([
                'type'     => Element\Checkbox::class,
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
            ])

            // TODO: We should have separate fieldset for PHP editor (client properties) which we could reuse - END
            
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'cgi',
                'required' => true,
                'options'  => ['label' => tr('CGI')]
            ])
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'custom_dns',
                'required' => true,
                'options'  => ['label' => tr('Custom DNS records')]
            ])
            ->add([
                'type'     => Element\Checkbox::class,
                'name'     => 'external_mail_server',
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
                'type'     => Element\Checkbox::class,
                'name'     => 'web_folder_protection',
                'required' => true,
                'options'  => ['label' => tr('Web folder protection')]
            ])
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
    public function getInputFilterSpecification()
    {
        return [
            'name'        => [
                'required'   => true,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\NotEmpty::class,
                        'options' => [
                            'type'    => 'string',
                            'message' => tr('The name field cannot be empty.')
                        ]
                    ]
                ]
            ],
            'description' => [
                'required'   => true,
                'filters'    => [
                    ['name' => Filter\StringTrim::class],
                    ['name' => Filter\StripTags::class]
                ],
                'validators' => [
                    [
                        'name'    => Validator\NotEmpty::class,
                        'options' => [
                            'type'    => 'string',
                            'message' => tr('The description field cannot be empty.')
                        ]
                    ]
                ]
            ]
        ];
    }

    /**
     * @inheritdoc
     */
    public function isValid()
    {
        if(!parent::isValid()) {
            return false;
        }
        
        // Perform validation against reseller limits
        return validateHostingPlan($this->getData(), Application::getInstance()->getAuthService()->getIdentity()->getUserId());
    }
}
