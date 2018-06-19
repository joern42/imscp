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
 * Class UiProperties
 * @package iMSCP\Model
 */
class UiProperties extends BaseModel
{
    /**
     * @var int
     */
    private $uiPropsID;

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
    public function getUiPropsID(): int
    {
        return $this->uiPropsID;
    }

    /**
     * @param int $uiPropsID
     * @return UiProperties
     */
    public function setUiPropsID(int $uiPropsID): UiProperties
    {
        $this->uiPropsID = $uiPropsID;
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
     * @return UiProperties
     */
    public function setUserID(int $userID): UiProperties
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
     * @return UiProperties
     */
    public function setLang(string $lang): UiProperties
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
     * @return UiProperties
     */
    public function setLayout(string $layout): UiProperties
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
     * @return UiProperties
     */
    public function setLayoutColor(string $layoutColor): UiProperties
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
     * @return UiProperties
     */
    public function setLayoutLogo(string $layoutLogo = NULL): UiProperties
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
     * @return UiProperties
     */
    public function setShowMenuLabels(int $showMenuLabels): UiProperties
    {
        $this->showMenuLabels = $showMenuLabels;
        return $this;
    }
}
