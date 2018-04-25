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

namespace iMSCP;

use Zend\Session\Container;

/**
 * Class FlashMessenger
 * @package iMSCP
 */
class FlashMessenger implements \IteratorAggregate, \Countable
{
    /**
     * @var array Messages from previous request
     */
    static protected $messages = array();

    /**
     * @var \Zend\Session\Container
     */
    static protected $session = NULL;

    /**
     * @var boolean Wether a message has been previously added
     */
    static protected $messageAdded = false;

    /**
     * @var string Instance namespace, default is 'default'
     */
    protected $namespace = 'default';

    /**
     * FlashMessenger constructor.
     */
    public function __construct()
    {
        if (!static::$session instanceof Container) {
            static::$session = new Container('FlashMessenger');
            foreach (static::$session as $namespace => $messages) {
                static::$messages[$namespace] = $messages;
                unset(static::$session->{$namespace});
            }
        }
    }

    /**
     * postDispatch() - runs after action is dispatched, in this
     * case, it is resetting the namespace in case we have forwarded to a different
     * action, Flashmessage will be 'clean' (default namespace)
     *
     * @return FlashMessenger
     */
    public function postDispatch(): FlashMessenger
    {
        $this->resetNamespace();
        return $this;
    }

    /**
     * Change the namespace messages are added to, useful for per action controller messaging between requests
     *
     * @param  string $namespace
     * @return FlashMessenger
     */
    public function setNamespace(string $namespace = 'default'): FlashMessenger
    {
        $this->namespace = $namespace;
        return $this;
    }

    /**
     * Get current namepsace
     *
     * @return string
     */
    public function getNamespace(): string
    {
        return $this->namespace;
    }

    /**
     * Reset the namespace to the default
     *
     * @return FlashMessenger
     */
    public function resetNamespace(): FlashMessenger
    {
        $this->setNamespace();
        return $this;
    }

    /**
     * Add a message to flash messenger
     *
     * @param string $message
     * @param string $namespace
     * @return FlashMessenger
     */
    public function addMessage(string $message, string $namespace = NULL): FlashMessenger
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        if (static::$messageAdded === false) {
            static::$session->setExpirationHops(1);
        }

        if (!is_array(static::$session->{$namespace})) {
            static::$session->{$namespace} = array();
        }

        static::$session->{$namespace}[] = $message;
        static::$messageAdded = true;

        return $this;
    }

    /**
     * Wether a specific namespace has messages
     *
     * @param string $namespace
     * @return boolean
     */
    public function hasMessages(string $namespace = NULL): bool
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        return isset(self::$messages[$namespace]);
    }

    /**
     * Get messages from a specific namespace
     *
     * @param string $namespace
     * @return array
     */
    public function getMessages(string $namespace = NULL): array
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        if ($this->hasMessages($namespace)) {
            return self::$messages[$namespace];
        }

        return array();
    }

    /**
     * Clear all messages from the previous request and current namespace
     *
     * @param string $namespace
     * @return boolean TRUE if messages were cleared, FALSE if none existed
     */
    public function clearMessages(string $namespace = NULL): bool
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        if ($this->hasMessages($namespace)) {
            unset(static::$messages[$namespace]);
            return true;
        }

        return false;
    }

    /**
     * Check to see if messages have been added to current namespace within this request
     *
     * @param string $namespace
     * @return boolean
     */
    public function hasCurrentMessages(string $namespace = NULL): bool
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        return isset(static::$session->{$namespace});
    }

    /**
     * Get messages that have been added to the current namespace within this request
     *
     * @param string $namespace
     * @return array
     */
    public function getCurrentMessages(string $namespace = NULL): array
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        if ($this->hasCurrentMessages($namespace)) {
            return static::$session->{$namespace};
        }

        return array();
    }

    /**
     * Clear messages from the current request and current namespace
     *
     * @param string $namespace
     * @return boolean
     */
    public function clearCurrentMessages(string $namespace = NULL): bool
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        if ($this->hasCurrentMessages($namespace)) {
            unset(static::$session->{$namespace});
            return true;
        }

        return false;
    }

    /**
     * @inheritdoc
     */
    public function getIterator($namespace = NULL): \ArrayObject
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        if ($this->hasMessages($namespace)) {
            return new \ArrayObject($this->getMessages($namespace));
        }

        return new \ArrayObject();
    }

    /**
     * @inheritdoc
     */
    public function count(string $namespace = NULL): int
    {
        if (!is_string($namespace) || $namespace == '') {
            $namespace = $this->getNamespace();
        }

        if ($this->hasMessages($namespace)) {
            return count($this->getMessages($namespace));
        }

        return 0;
    }
}
