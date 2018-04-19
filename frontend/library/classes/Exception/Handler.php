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

namespace iMSCP\Exception;

use Zend\EventManager\EventManagerAwareInterface;
use Zend\EventManager\EventManagerAwareTrait;

/**
 * Class Handler
 * @package iMSCP\Exception
 */
class Handler implements EventManagerAwareInterface
{
    /**
     * @var string[] Exception writers
     */
    protected $writers = [
        Writer\Browser::class,
        Writer\Mail::class
    ];

    use EventManagerAwareTrait;

    /**
     * Handle uncaught exceptions
     *
     * @param \Throwable $e Uncaught exception
     * @return void
     */
    public function __invoke(\Throwable $e): void
    {
        try {
            foreach ($this->writers as $writer) {
                $this->getEventManager()->attach('onUncaughtException', new $writer);
            }

            $event = new Event();
            $event->setTarget($this);
            $event->setException($e);
            $this->getEventManager()->triggerEvent($event);
        } catch (\Throwable $e) {
            if (PHP_SAPI != 'cli') {
                $message = <<<HTML
<!DOCTYPE html>
<html>
    <head>
    <title>i-MSCP - internet Multi Server Control Panel - Fatal Error</title>
    <meta charset="UTF-8">
    <meta name="robots" content="nofollow, noindex">
    </head>
    <body>
        <pre>
Couldn't handle uncaught exception:

<b>Message:</b> {$e->getMessage()}
<b>Trace :</b> {$e->getTraceAsString()}
        </pre>
    </body>
</html>
HTML;
            } else {
                $message = sprintf("Couldn't handle uncaught exception:\n\n%s %s", $e->getMessage(), $e->getTraceAsString());
            }

            die($message);
        }
    }
}
