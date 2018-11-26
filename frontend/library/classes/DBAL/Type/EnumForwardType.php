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

namespace iMSCP\DBAL;

use Doctrine\DBAL\Platforms\AbstractPlatform;
use Doctrine\DBAL\Types\Type;

/**
 * Class EnumForwardType
 * @package MyProject\DBAL
 */
class EnumForwardType extends Type
{
    const ENUM_FORWARD = 'enumforwardtype';

    /**
     * @var array Allowed forward types
     */
    private $allowedForwardTypes = [
        '301',
        '302',
        '303',
        '307',
        '308',
        'proxy'
    ];

    /**
     * @inheritdoc
     */
    public function getSQLDeclaration(array $fieldDeclaration, AbstractPlatform $platform)
    {
        return 'ENUM(' . implode(',', $this->allowedForwardTypes) . ')';
    }

    /**
     * @inheritdoc
     */
    public function convertToPHPValue($value, AbstractPlatform $platform)
    {
        return $value;
    }

    /**
     * @inheritdoc
     */
    public function convertToDatabaseValue($value, AbstractPlatform $platform)
    {
        if (!in_array($value, $this->allowedForwardTypes)) {
            throw new \InvalidArgumentException("Invalid forward type");
        }

        return $value;
    }

    /**
     * @inheritdoc
     */
    public function getName()
    {
        return self::ENUM_FORWARD;
    }

    /**
     * @inheritdoc
     */
    public function requiresSQLCommentHint(AbstractPlatform $platform)
    {
        return true;
    }
}
