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
 * Class CpUiProperties
 * @package iMSCP\Model
 */
class CpUiProperties extends BaseModel
{
    /**
     * @var int
     */
    private $CpUiPropertiesID;

    /**
     * @var int
     */
    private $userID;

    /**
     * @var string
     */
    private $lang = 'browser';

    /**
     * @var string
     */
    private $layout = 'default';

    /**
     * @var string
     */
    private $layoutColor = 'black';

    /**
     * @var string|null
     */
    private $layoutLogo;

    /**
     * @var int
     */
    private $showMenuLabels = 0;

    /**
     * @return int
     */
    public function getCpUiPropertiesID(): int
    {
        return $this->CpUiPropertiesID;
    }

    /**
     * @param int $CpUiPropertiesID
     * @return CpUiProperties
     */
    public function setCpUiPropertiesID(int $CpUiPropertiesID): CpUiProperties
    {
        $this->CpUiPropertiesID = $CpUiPropertiesID;
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
     * @return CpUiProperties
     */
    public function setUserID(int $userID): CpUiProperties
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return string
     */
    public function getLang(): string
    {
        return $this->lang;
    }

    /**
     * @param string $lang
     * @return CpUiProperties
     */
    public function setLang(string $lang): CpUiProperties
    {
        $this->lang = $lang;
        return $this;
    }

    /**
     * @return string
     */
    public function getLayout(): string
    {
        return $this->layout;
    }

    /**
     * @param string $layout
     * @return CpUiProperties
     */
    public function setLayout(string $layout): CpUiProperties
    {
        $this->layout = $layout;
        return $this;
    }

    /**
     * @return string
     */
    public function getLayoutColor(): string
    {
        return $this->layoutColor;
    }

    /**
     * @param string $layoutColor
     * @return CpUiProperties
     */
    public function setLayoutColor(string $layoutColor): CpUiProperties
    {
        $this->layoutColor = $layoutColor;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getLayoutLogo(): ?string
    {
        return $this->layoutLogo;
    }

    /**
     * @param string|null $layoutLogo
     * @return CpUiProperties
     */
    public function setLayoutLogo(string $layoutLogo = NULL): CpUiProperties
    {
        $this->layoutLogo = $layoutLogo;
        return $this;
    }

    /**
     * @return int
     */
    public function getShowMenuLabels(): int
    {
        return $this->showMenuLabels;
    }

    /**
     * @param int $showMenuLabels
     * @return CpUiProperties
     */
    public function setShowMenuLabels(int $showMenuLabels): CpUiProperties
    {
        $this->showMenuLabels = $showMenuLabels;
        return $this;
    }
}
