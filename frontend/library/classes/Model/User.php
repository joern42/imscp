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
 * Class User
 * @package iMSCP\Model
 */
class User extends BaseModel
{
    /**
     * @var int
     */
    private $userID;

    /**
     * @var string
     */
    private $username;

    /**
     * @var string
     */
    private $passwordHash;

    /**
     * @var string
     */
    private $type;

    /**
     * @var string
     */
    private $email;

    /**
     * @var string
     */
    private $sysName;

    /**
     * @var int
     */
    private $sysUID;

    /**
     * @var string
     */
    private $sysGroupName;

    /**
     * @var int
     */
    private $sysGID;

    /**
     * @var \DateTimeImmutable|null
     */
    private $createdAt;

    /**
     * @var \DateTimeImmutable|null
     */
    private $updatedAt;

    /**
     * @var \DateTimeImmutable|null
     */
    private $expireAt;

    /**
     * @var string
     */
    private $customerID;

    /**
     * @var string
     */
    private $createdBy;

    /**
     * @var string
     */
    private $firstName;

    /**
     * @var string
     */
    private $lastName;

    /**
     * @var string
     */
    private $gender = 'U';

    /**
     * @var string
     */
    private $firm;

    /**
     * @var string
     */
    private $street1;

    /**
     * @var string
     */
    private $street2;

    /**
     * @var string
     */
    private $city;

    /**
     * @var string
     */
    private $zip;

    /**
     * @var string
     */
    private $country;

    /**
     * @var string
     */
    private $phone;

    /**
     * @var string
     */
    private $fax;

    /**
     * @var \DateTimeImmutable|null
     */
    private $lastLostPasswordRequestTime;

    /**
     * @var string|null
     */
    private $lostPasswordKey;

    /**
     * @var int
     */
    private $isActive = 1;

    /**
     * @return int
     */
    public function getUserID(): int
    {
        return $this->userID;
    }

    /**
     * @param int $userID
     * @return User
     */
    public function setUserID(int $userID): User
    {
        $this->userID = $userID;
        return $this;
    }

    /**
     * @return string
     */
    public function getUsername(): string
    {
        return $this->username;
    }

    /**
     * @param string $username
     * @return User
     */
    public function setUsername(string $username): User
    {
        $this->username = $username;
        return $this;
    }

    /**
     * @return string
     */
    public function getPasswordHash(): string
    {
        return $this->passwordHash;
    }

    /**
     * @param string $passwordHash
     * @return User
     */
    public function setPasswordHash(string $passwordHash): User
    {
        $this->passwordHash = $passwordHash;
        return $this;
    }

    /**
     * @return string
     */
    public function getType(): string
    {
        return $this->type;
    }

    /**
     * @param string $type
     * @return User
     */
    public function setType(string $type): User
    {
        $this->type = $type;
        return $this;
    }

    /**
     * @return string
     */
    public function getEmail(): string
    {
        return $this->email;
    }

    /**
     * @param string $email
     * @return User
     */
    public function setEmail(string $email): User
    {
        $this->email = $email;
        return $this;
    }

    /**
     * @return string
     */
    public function getSysName(): string
    {
        return $this->sysName;
    }

    /**
     * @param string $sysName
     * @return User
     */
    public function setSysName(string $sysName): User
    {
        $this->sysName = $sysName;
        return $this;
    }

    /**
     * @return int
     */
    public function getSysUID(): int
    {
        return $this->sysUID;
    }

    /**
     * @param int $sysUID
     * @return User
     */
    public function setSysUID(int $sysUID): User
    {
        $this->sysUID = $sysUID;
        return $this;
    }

    /**
     * @return string
     */
    public function getSysGroupName(): string
    {
        return $this->sysGroupName;
    }

    /**
     * @param string $sysGroupName
     * @return User
     */
    public function setSysGroupName(string $sysGroupName): User
    {
        $this->sysGroupName = $sysGroupName;
        return $this;
    }

    /**
     * @return int
     */
    public function getSysGID(): int
    {
        return $this->sysGID;
    }

    /**
     * @param int $sysGID
     * @return User
     */
    public function setSysGID(int $sysGID): User
    {
        $this->sysGID = $sysGID;
        return $this;
    }

    /**
     * @return \DateTimeImmutable|null
     */
    public function getCreatedAt(): ?\DateTimeImmutable
    {
        return $this->createdAt;
    }

    /**
     * @param \DateTimeImmutable|null $createdAt
     * @return User
     */
    public function setCreatedAt(?\DateTimeImmutable $createdAt): User
    {
        $this->createdAt = $createdAt;
        return $this;
    }

    /**
     * @return \DateTimeImmutable|null
     */
    public function getUpdatedAt(): ?\DateTimeImmutable
    {
        return $this->updatedAt;
    }

    /**
     * @param \DateTimeImmutable|null $updatedAt
     * @return User
     */
    public function setUpdatedAt(?\DateTimeImmutable $updatedAt): User
    {
        $this->updatedAt = $updatedAt;
        return $this;
    }

    /**
     * @return \DateTimeImmutable|null
     */
    public function getExpireAt(): ?\DateTimeImmutable
    {
        return $this->expireAt;
    }

    /**
     * @param \DateTimeImmutable|null $expireAt
     * @return User
     */
    public function setExpireAt(?\DateTimeImmutable $expireAt): User
    {
        $this->expireAt = $expireAt;
        return $this;
    }

    /**
     * @return string
     */
    public function getCustomerID(): string
    {
        return $this->customerID;
    }

    /**
     * @param string $customerID
     * @return User
     */
    public function setCustomerID(string $customerID): User
    {
        $this->customerID = $customerID;
        return $this;
    }

    /**
     * @return string
     */
    public function getCreatedBy(): string
    {
        return $this->createdBy;
    }

    /**
     * @param string $createdBy
     * @return User
     */
    public function setCreatedBy(string $createdBy): User
    {
        $this->createdBy = $createdBy;
        return $this;
    }

    /**
     * @return string
     */
    public function getFirstName(): string
    {
        return $this->firstName;
    }

    /**
     * @param string $firstName
     * @return User
     */
    public function setFirstName(string $firstName): User
    {
        $this->firstName = $firstName;
        return $this;
    }

    /**
     * @return string
     */
    public function getLastName(): string
    {
        return $this->lastName;
    }

    /**
     * @param string $lastName
     * @return User
     */
    public function setLastName(string $lastName): User
    {
        $this->lastName = $lastName;
        return $this;
    }

    /**
     * @return string
     */
    public function getGender(): string
    {
        return $this->gender;
    }

    /**
     * @param string $gender
     * @return User
     */
    public function setGender(string $gender): User
    {
        $this->gender = $gender;
        return $this;
    }

    /**
     * @return string
     */
    public function getFirm(): string
    {
        return $this->firm;
    }

    /**
     * @param string $firm
     * @return User
     */
    public function setFirm(string $firm): User
    {
        $this->firm = $firm;
        return $this;
    }

    /**
     * @return string
     */
    public function getStreet1(): string
    {
        return $this->street1;
    }

    /**
     * @param string $street1
     * @return User
     */
    public function setStreet1(string $street1): User
    {
        $this->street1 = $street1;
        return $this;
    }

    /**
     * @return string
     */
    public function getStreet2(): string
    {
        return $this->street2;
    }

    /**
     * @param string $street2
     * @return User
     */
    public function setStreet2(string $street2): User
    {
        $this->street2 = $street2;
        return $this;
    }

    /**
     * @return string
     */
    public function getCity(): string
    {
        return $this->city;
    }

    /**
     * @param string $city
     * @return User
     */
    public function setCity(string $city): User
    {
        $this->city = $city;
        return $this;
    }

    /**
     * @return string
     */
    public function getZip(): string
    {
        return $this->zip;
    }

    /**
     * @param string $zip
     * @return User
     */
    public function setZip(string $zip): User
    {
        $this->zip = $zip;
        return $this;
    }

    /**
     * @return string
     */
    public function getCountry(): string
    {
        return $this->country;
    }

    /**
     * @param string $country
     * @return User
     */
    public function setCountry(string $country): User
    {
        $this->country = $country;
        return $this;
    }

    /**
     * @return string
     */
    public function getPhone(): string
    {
        return $this->phone;
    }

    /**
     * @param string $phone
     * @return User
     */
    public function setPhone(string $phone): User
    {
        $this->phone = $phone;
        return $this;
    }

    /**
     * @return string
     */
    public function getFax(): string
    {
        return $this->fax;
    }

    /**
     * @param string $fax
     * @return User
     */
    public function setFax(string $fax): User
    {
        $this->fax = $fax;
        return $this;
    }

    /**
     * @return \DateTimeImmutable|null
     */
    public function getLastLostPasswordRequestTime(): ?\DateTimeImmutable
    {
        return $this->lastLostPasswordRequestTime;
    }

    /**
     * @param \DateTimeImmutable|null $lastLostPasswordRequestTime
     * @return User
     */
    public function setLastLostPasswordRequestTime(\DateTimeImmutable $lastLostPasswordRequestTime = NULL): User
    {
        $this->lastLostPasswordRequestTime = $lastLostPasswordRequestTime;
        return $this;
    }

    /**
     * @return string|null
     */
    public function getLostPasswordKey(): ?string
    {
        return $this->lostPasswordKey;
    }

    /**
     * @param string $lostPasswordKey |null
     * @return User
     */
    public function setLostPasswordKey(string $lostPasswordKey = NULL): User
    {
        $this->lostPasswordKey = $lostPasswordKey;
        return $this;
    }

    /**
     * @return int
     */
    public function getIsActive(): int
    {
        return $this->isActive;
    }

    /**
     * @param int $isActive
     * @return User
     */
    public function setIsActive(int $isActive): User
    {
        $this->isActive = $isActive;
        return $this;
    }
}
