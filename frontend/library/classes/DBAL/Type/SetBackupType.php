<?php

namespace iMSCP\DBAL;

use Doctrine\DBAL\Platforms\AbstractPlatform;
use Doctrine\DBAL\Types\Type;

/**
 * Class SetBackupType
 * @package MyProject\DBAL
 */
class SetBackupType extends Type
{
    const SET_BACKUP = 'setbackup';
    const MAIL_BACKUP = 'mail';
    const NO_BACKUP = '';
    const SQL_BACKUP = 'sql';
    const WEB_BACKUP = 'web';

    /**
     * @inheritdoc
     */
    public function getSQLDeclaration(array $fieldDeclaration, AbstractPlatform $platform)
    {
        return "SET('mail', 'sql', 'web') NOT NULL DEFAULT ''";
    }

    /**
     * @inheritdoc
     */
    public function convertToPHPValue($value, AbstractPlatform $platform)
    {
        return explode(',', $value);
    }

    /**
     * @inheritdoc
     */
    public function convertToDatabaseValue($value, AbstractPlatform $platform)
    {
        if (sizeof(array_diff_key($value, [self::MAIL_BACKUP, self::NO_BACKUP, self::SQL_BACKUP, self::SQL_BACKUP]) > 0)
            || sizeof($value) > 1 && in_array('', $value)
        ) {
            throw new \InvalidArgumentException("Invalid backup type");
        }

        return implode(',', $value);
    }

    /**
     * @inheritdoc
     */
    public function getName()
    {
        return self::SET_BACKUP;
    }

    /**
     * @inheritdoc
     */
    public function requiresSQLCommentHint(AbstractPlatform $platform)
    {
        return true;
    }
}
