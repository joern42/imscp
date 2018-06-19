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

namespace iMSCP\Model;

/**
 * Class WebErrorPage
 * @package iMSCP\Model
 */
class WebErrorPage extends BaseModel
{
    /**
     * @var int
     */
    private $errorPageID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var int
     */
    private $code;

    /**
     * @var string
     */
    private $content;

    /**
     * @return int
     */
    public function getErrorPageID(): int
    {
        return $this->errorPageID;
    }

    /**
     * @param int $errorPageID
     * @return WebErrorPage
     */
    public function setErrorPageID(int $errorPageID): WebErrorPage
    {
        $this->errorPageID = $errorPageID;
        return $this;
    }

    /**
     * @return int
     */
    public function getUserID(): int
    {
        return $this->userID;
    }

    /**
     * @param int $userID
     * @return WebErrorPage
     */
    public function setUserID(int $userID): WebErrorPage
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return int
     */
    public function getCode(): int
    {
        return $this->code;
    }

    /**
     * @param int $code
     * @return WebErrorPage
     */
    public function setCode(int $code): WebErrorPage
    {
        $this->code = $code;
        return $this;
    }

    /**
     * @return string
     */
    public function getContent(): string
    {
        return $this->content;
    }

    /**
     * @param string $content
     * @return WebErrorPage
     */
    public function setContent(string $content): WebErrorPage
    {
        $this->content = $content;
        return $this;
    }
}
