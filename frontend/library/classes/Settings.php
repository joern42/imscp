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

use Doctrine\Common\Persistence\ObjectManager;
use iMSCP\Model\Store\Setting\SettingCollection;
use iMSCP\Model\Store\Setting\SettingInterface;

/**
 * Class Settings
 * @package iMSCP
 */
class Settings implements \IteratorAggregate
{
    /**
     * @var
     */
    private $objectManager;

    /**
     * @var SettingCollection
     */
    private $settings;

    /**
     * Settings constructor
     * @param ObjectManager $objectManager
     */
    public function __construct(ObjectManager $objectManager)
    {
        $this->objectManager = $objectManager;
    }

    /**
     * Get setting from setting collection
     *
     * @param string $name Setting name
     * @return SettingInterface
     */
    public function getSetting(string $name):  SettingInterface
    {
        return $this->getSettings()->getSetting($name);
    }


    /**
     * Add or replace a setting in setting collection
     *
     * @param SettingInterface $setting
     * @return Settings
     */
    public function addSetting(SettingInterface $setting): Settings
    {
        $this->getSettings()->addSetting($setting);
        return $this;
    }

    /**
     * Delete a setting from setting collection
     *
     * @param string $name
     * @return Settings
     */
    public function deleteSetting(string $name): Settings
    {
        $this->getSettings()->deleteSetting($name);
        return $this;
    }

    
    /**
     * Save setting collection
     */
    public function saveSettings()
    {
        foreach ($this as $setting) {
            $this->settings->addSetting(clone $setting);
        }

        $this->objectManager->persist($this->settings);
        $this->objectManager->flush();
    }

    /**
     * Return iterator to iterate through setting collection
     * @inheritdoc
     */
    public function getIterator()
    {
        return $this->getSettings()->getIterator();
    }

    /**
     * Get setting collection
     * @return SettingCollection|object
     */
    protected function getSettings() {
        if (NULL === $this->settings) {
            $this->settings = $this->objectManager->find(SettingCollection::class, SettingCollection::class);
        }

        return $this->settings;
    }
}
