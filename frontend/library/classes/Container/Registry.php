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

namespace iMSCP\Container;

use iMSCP\Container\Exception\DataNotFoundException;
use Psr\Container\ContainerInterface;

/**
 * Class Registry
 * @package iMSCP
 */
class Registry implements ContainerInterface
{
    /**
     * @var array
     */
    private $data = [];

    /**
     * @inheritdoc
     */
    public function has($id)
    {
        if (array_key_exists($id, $this->data)) {
            return true;
        }

        return false;
    }
    
    /**
     * @inheritdoc
     */
    public function &get($id)
    {
        if (!$this->has($id)) {
            throw new DataNotFoundException(sprintf('Data by name %s not found', $id));

        }

        return $this->data[$id];
    }

    /**
     * Register the given data in the registry
     *
     * @param string $id
     * @param mixed $value
     * @return void
     */
    public function set(string $id, $value)
    {
        $this->data[$id] = $value;
    }
}
