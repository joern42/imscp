<?php

namespace iMSCP\Form;

use iMSCP\Application;
use iMSCP\Functions\Counting;
use Zend\Filter;
use Zend\Form\Element;
use Zend\Form\Form;
use Zend\InputFilter\InputFilterProviderInterface;
use Zend\Validator;

/**
 * Class HostingPlan
 * @package iMSCP\Form
 */
class HostingPlanForm extends Form implements InputFilterProviderInterface
{
    /**
     * @inheritdoc
     */
    public function __construct($name = NULL, $options = [])
    {
        parent::__construct($name, $options);

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
                'type' => LimitsFieldset::class,
                'name' => 'limits',
            ])
            // Feature
            ->add([
                'type' => FeaturesFieldset::class,
                'name' => 'features',
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
            ])
            // Submit
            ->add([
                'type'    => Element\Submit::class,
                'name'    => 'submit',
                'options' => [
                    'label' => tr('Create') // Default label
                ]
            ]);
    }

    /**
     * @inheritdoc
     */
    public function init()
    {
        // Make 3rd-party components able to modify that form
        Application::getInstance()->getEventManager()->trigger('onInitHostingPlanForm', $this);
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
        $this->setValidationGroup();

        if (!parent::isValid()) {
            return false;
        }

        // Perform validation against reseller limits
        return validateHostingPlan($this->getData(), Application::getInstance()->getAuthService()->getIdentity()->getUserId());
    }

    /**
     * @inheritdoc
     */
    public function setValidationGroup()
    {
        $groups = [];

        // Limits
        if (!Counting::userHasFeature('web')) {
            $groups['limits'][] = 'domains';
        }

        if (!Counting::userHasFeature('mail')) {
            $groups['limits'][] = 'mail';
        }

        if (!Counting::userHasFeature('ftp')) {
            $groups['limits'][] = 'ftp';
        }

        if (!Counting::userHasFeature('sql')) {
            $groups['limits'][] = 'sql';
        }

        // Features (TODO)
    }
}
