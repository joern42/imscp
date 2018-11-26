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

use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\ORM\Mapping as ORM;

/**
 * Class User
 * @ORM\Entity
 * @ORM\Table(name="imscp_user", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @ORM\HasLifecycleCallbacks()
 * @package iMSCP\Model
 */
class User 
{
    /**
     * @ORM\Id
     * @ORM\Column(type="uuid_binary_ordered_time", unique=true)
     * @ORM\GeneratedValue(strategy="CUSTOM")
     * @ORM\CustomIdGenerator(class="Ramsey\Uuid\Doctrine\UuidOrderedTimeGenerator")
     * @var string
     */
    private $userID;

    /**
     * @ORM\Column(type="string", unique=true)
     * @var string
     */
    private $username;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $passwordHash;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $type;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $email;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $sysName;

    /**
     * @ORM\Column(type="integer", nullable=true)
     * @var int
     */
    private $sysUID;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $sysGroupName;

    /**
     * @ORM\Column(type="integer", nullable=true)
     * @var int
     */
    private $sysGID;

    /**
     * @ORM\Column(type="datetime_immutable")
     * @var \DateTimeImmutable
     */
    private $createdAt;

    /**
     * @ORM\Column(type="datetime_immutable", nullable=true)
     * @var \DateTimeImmutable|null
     */
    private $updatedAt;

    /**
     * @ORM\Column(type="datetime_immutable", nullable=true)
     * @var \DateTimeImmutable|null
     */
    private $expireAt;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $customerID;

    /**
     * @ORM\ManyToOne(targetEntity="User", inversedBy="managedUsers")
     * @ORM\JoinColumn(name="managerID", referencedColumnName="userID", nullable=true)
     * @var User
     */
    private $manager;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $firstName;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $lastName;

    /**
     * @ORM\Column(type="string")
     * @var string
     */
    private $gender = 'U';

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $firm;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $street1;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $street2;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $city;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $zip;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $country;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $phone;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string
     */
    private $fax;

    /**
     * @ORM\Column(type="datetime_immutable", nullable=true)
     * @var \DateTimeImmutable|null
     */
    private $lastLostPasswordRequestTime;

    /**
     * @ORM\Column(type="string", nullable=true)
     * @var string|null
     */
    private $lostPasswordKey;

    /**
     * @ORM\Column(type="boolean")
     * @var bool
     */
    private $isActive = true;

    /**
     * @ORM\OneToMany(targetEntity="User", mappedBy="manager", fetch="EXTRA_LAZY")
     * @var User[]
     */
    public $managedUsers;

    /**
     * @ORM\Column(nullable=false)
     * @var string 
     */
    public $whatever = 'winner';

    /**
     * @return User[]
     */
    public function getManagedUsers(): array
    {
        return $this->managedUsers->toArray();
    }

    /**
     * @param User[] $managedUsers
     * @return User
     */
    public function setManagedUsers(array $managedUsers): User
    {
        $this->managedUsers = $managedUsers;
        return $this;
    }

    /**
     * User constructor.
     * @param string $username
     * @param string $passwordHash
     * @param string $type
     * @param string $email
     * @throws \Exception
     */
    public function __construct(string $username, string $passwordHash, string $type, string $email)
    {
        $this->setUsername($username);
        $this->setPasswordHash($passwordHash);
        $this->setType($type);
        $this->setEmail($email);
        $this->managedUsers = new ArrayCollection();
    }

    /**
     * @return int
     */
    public function getUserID(): int
    {
        return $this->userID;
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
     * @ORM\PrePersist()
     * @return User
     */
    public function setCreatedAt(): User
    {
        $this->createdAt = new \DateTimeImmutable();
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
     * @ORM\PreUpdate()
     * @return User
     */
    public function setUpdatedAt(): User
    {
        $this->updatedAt = new \DateTimeImmutable();
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
     * @return User
     */
    public function getManager(): User
    {
        return $this->manager;
    }

    /**
     * @param User $manager
     * @return User
     */
    public function setManager(User $manager): User
    {
        $this->manager = $manager;
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
     * @return bool
     */
    public function getIsActive(): bool
    {
        return $this->isActive;
    }

    /**
     * @param bool $isActive
     * @return User
     */
    public function setIsActive(bool $isActive): User
    {
        $this->isActive = $isActive;
        return $this;
    }
}
