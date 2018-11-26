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

namespace iMSCP\Model\Store\Setting;

use Doctrine\ORM\Mapping as ORM;
use iMSCP\Model\Store\StoreCollectionAbstract;

/**
 * Class SettingCollection
 * @package iMSCP\Model\Store\Setting
 * @ORM\Entity
 * @ORM\Table(name="imscp_storage", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @ORM\ChangeTrackingPolicy("DEFERRED_EXPLICIT")
 */
class SettingCollection extends StoreCollectionAbstract
{
    /**
     * Return setting
     *
     * @param string $name
     * @return SettingInterface
     */
    public function getSetting(string $name)
    {
        $setting = $this->storageData[$name] ?? NULL;

        if (NULL === $setting) {
            throw new \RuntimeException(sprintf("Couldn't find setting by name: %s", $name));
        }

        return $setting;
    }

    /**
     * Add or replace a setting
     *
     * @param SettingInterface $setting
     * @return SettingCollection
     */
    public function addSetting(SettingInterface $setting): SettingCollection
    {
        $this->storageData[$setting->getName()] = $setting;
        return $this;
    }

    /**
     * Remove a setting by name
     *
     * @param string $name
     * @return SettingCollection
     */
    public function deleteSetting(string $name): SettingCollection
    {
        unset($this->storageData[$name]);
        return $this;
    }
}
