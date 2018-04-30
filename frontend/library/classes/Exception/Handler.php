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
        // Must be registered first on event manager so that even if the
        // Browser exception writer raise an exception, mail will be sent
        Writer\Mail::class,
        Writer\Browser::class
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
        $event = new Event();
        $event->setTarget($this);
        $event->setException($e);

        try {
            foreach ($this->writers as $writer) {
                $this->getEventManager()->attach('onUncaughtException', new $writer);
            }

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
    <div style="text-align:center;font-size: x-large;font-weight: bold">Couldn't handle uncaught exception</div>
        <pre style="padding: 1.1em">
<b>Uncaught exception (thrown in file {$event->getException()->getFile()} at line {$event->getException()->getLine()}):</b>

<b>Message:</b> {$event->getException()->getMessage()}
<b>Stack trace:</b> {$event->getException()->getTraceAsString()}

<b>Last exception (thrown in file {$e->getFile()} at line {$e->getLine()}):</b>

<b>Message:</b> {$e->getMessage()}
<b>Stack trace:</b> {$e->getTraceAsString()}
        </pre>
    </body>
</html>
HTML;
            } else {
                $message = <<<TEXT
Couldn't handle uncaught exception:

Uncaught exception (thrown in file {$event->getException()->getFile()} at line {$event->getException()->getLine()}):

Message: {$event->getException()->getMessage()}
Stack trace: {$event->getException()->getTraceAsString()}

Last exception (thrown in file {$e->getFile()} at line {$e->getLine()}):

Message: {$e->getMessage()}
Stack trace: {$e->getTraceAsString()}
TEXT;
            }

            die($message);
        }
    }
}
