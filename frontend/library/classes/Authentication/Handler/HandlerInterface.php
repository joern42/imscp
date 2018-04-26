<?php

namespace iMSCP\Authentication\Handler;

use iMSCP\Authentication\AuthEvent;

/**
 * Interface HandlerInterface
 * @package iMSCP\Authentication\Handler
 */
interface HandlerInterface
{
    /**
     * Process authentication
     *
     * @param AuthEvent $event
     */
    public static function authenticate(AuthEvent $event): void;
}
