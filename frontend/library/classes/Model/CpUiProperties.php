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

use Doctrine\ORM\Mapping as ORM;

/**
 * Class CpUiProperties
 * @ORM\Entity
 * @ORM\Table(name="imscp_cp_ui_properties", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class CpUiProperties
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $CpUiPropertiesID;

    /**
     * @ORM\ManyToOne(targetEntity="User")
     * @ORM\JoinColumn(name="userID", referencedColumnName="userID", onDelete="CASCADE")
     * @var User
     */
    private $user;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $lang = 'browser';

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $layout = 'default';

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $layoutColor = 'default';

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string|null
     */
    private $layoutLogo;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $showMenuLabels = false;

    /**
     * @return int
     */
    public function getCpUiPropertiesID(): int
    {
        return $this->CpUiPropertiesID;
    }

    /**
     * @return User
     */
    public function getUser(): User
    {
        return $this->user;
    }

    /**
     * @param User $user
     * @return CpUiProperties
     */
    public function setUser(User $user): CpUiProperties
    {
        $this->user = $user;
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
