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

namespace iMSCP\Exception\Writer;

use iMSCP\Application;
use iMSCP\Exception\Event;
use iMSCP\Exception\Production;
use iMSCP\TemplateEngine;

/**
 * Class Browser
 *
 * This exception writer writes an exception messages to the client browser.
 *
 * @package iMSCP\Exception\Writer
 */
class Browser implements WriterInterface
{
    /**
     * @var string Template file
     */
    static $templateFile = 'message.tpl';

    /**
     * @var string message
     */
    protected $message;

    /**
     * @inheritdoc
     */
    public function __invoke(Event $event): void
    {
        $exception = $event->getException();

        try {
            $debug = Application::getInstance()->getConfig()['DEBUG'];
        } catch (\Throwable $e) {
            $debug = 1;
        }

        if ($debug) {
            $exception = $event->getException();
            $this->message = 'Exception: ' . preg_replace('/([\t\n]+|<br>)/', ' ', $exception->getMessage()) . "\n";
            $this->message .= "Stack trace:\n:" . $exception->getTraceAsString();
        } else {
            $exception = new Production($exception->getMessage(), $exception->getCode(), $exception);
            $this->message = $exception->getMessage();
        }

        // Flush output buffer (cover template context exceptions)
        ob_clean();

        if (self::$templateFile && NULL !== $tpl = $this->render()) {
            $event->setParams([
                'templateEngine' => $tpl,
                'layout'         => 'layout_browser_exception'
            ]);
            initLayout($event);
            $tpl->prnt();
            return;
        }

        # Fallback to inline template in case something goes wrong with template engine
        echo <<<HTML
<!DOCTYPE html>
<html>
    <head>
    <title>i-MSCP - internet Multi Server Control Panel - Fatal Error</title>
    <meta charset="UTF-8">
    <meta name="robots" content="nofollow, noindex">
    <link rel="icon" href="/themes/default/assets/images/favicon.ico">
    <link rel="stylesheet" href="/themes/default/assets/css/jquery-ui-black.css">
    <link rel="stylesheet" href="/themes/default/assets/css/simple.css">
    <!--[if (IE 7)|(IE 8)]>
        <link href="/themes/default/assets/css/ie78overrides.css?v=1425280612" rel="stylesheet">
    <![endif]-->
    <script src="/themes/default/assets/js/jquery/jquery.js"></script>
    <script src="/themes/default/assets/js/jquery/jquery-ui.js"></script>
    <script src="/themes/default/assets/js/imscp.js"></script>
    <script>
        $(function () { iMSCP.initApplication('simple'); });
    </script>
    </head>
    <body class="black">
        <div class="wrapper">
            <div id="content">
                <div id="message_container">
                    <h1>An unexpected error occurred</h1>
                    <pre>{$this->message}</pre>
                    <div class="buttons">
                        <a class="link_as_button" href="javascript:history.go(-1)" target="_self">Back</a>
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>
HTML;
    }

    /**
     * Render template
     *
     * @return null|TemplateEngine
     */
    protected function render(): ?TemplateEngine
    {
        try {
            $tpl = new TemplateEngine();
            # We need set specific template names because templates are cached
            # using the current URL and the template name to generate unique
            # identifier. Not doing this would lead to wrong template used.
            $tpl->define([
                'layout_browser_exception' => 'shared/layouts/simple.tpl',
                'page_browser_exception'   => self::$templateFile,
                'page_message'             => 'layout',
                'backlink_block'           => 'page'
            ]);
            $tpl->assign([
                'TR_PAGE_TITLE'     => 'i-MSCP - internet Multi Server Control Panel - Fatal Error',
                'HEADER_BLOCK'      => '',
                'BOX_MESSAGE_TITLE' => 'An unexpected error occurred',
                'PAGE_MESSAGE'      => '',
                'BOX_MESSAGE'       => $this->message,
                'TR_BACK'           => 'Back'
            ]);
            $tpl->parse('LAYOUT_CONTENT', 'page_browser_exception');
            return $tpl;
        } catch (\Throwable $e) {
            return NULL;
        }
    }
}
