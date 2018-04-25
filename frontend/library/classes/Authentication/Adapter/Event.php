<?php

namespace iMSCP\Authentication\Adapter;

use iMSCP\Authentication\AuthEvent;
use iMSCP\Events;
use Zend\Authentication\Adapter\AbstractAdapter;
use Zend\Authentication\Result;
use Zend\EventManager\EventManagerInterface;

/**
 * Class Event
 *
 * This adapter authenticate users by triggering the AuthEvent event.
 * Listeners of that event are authentication handlers which are responsible to implement authentication logic.
 *
 * Any authentication handler should set the appropriate AuthResult on the AuthEvent.
 * 
 * @package iMSCP\Authentication\Adapter
 */
class Event extends AbstractAdapter
{
    /**
     * @var EventManagerInterface
     */
    protected $events;

    /**
     * Event constructor.
     * @param EventManagerInterface $em
     */
    public function __construct(EventManagerInterface $em)
    {
        $this->events = $em;
    }

    /**
     * @inheritdoc
     */
    public function authenticate()
    {
        $authEvent = new AuthEvent($this);
        $authEvent->setTarget($this);
        $authEvent->setName(Events::onAuthentication);

        $responses = $this->events->triggerEvent($authEvent);

        if (!$responses->stopped()) {
            $authEvent->setName(Events::onAuthentication);
            $this->events->triggerEvent($authEvent);

            if ($authEvent->hasAuthenticationResult()) {
                $authResult = new Result(Result::FAILURE_UNCATEGORIZED, NULL, tr('Unknown reason.'));
                $authEvent->setAuthenticationResult($authResult);
            } else {
                $authResult = $authEvent->getAuthenticationResult();
            }
        } else {
            $authResult = new Result(Result::FAILURE_UNCATEGORIZED, NULL, $responses->last());
            $authEvent->setAuthenticationResult($authResult);
        }

        $authEvent->setTarget($this);
        $this->events->triggerEvent($authEvent);
        return $authResult;
    }
}
