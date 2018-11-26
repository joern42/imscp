<?php

namespace iMSCP\Model;

use Doctrine\ORM\Mapping as ORM;

/**
 * Class ServerTraffic
 * @ORM\Entity
 * @ORM\Table(name="imscp_server_traffic", options={"charset":"utf8mb4", "collate":"utf8mb4_general_ci", "row_format":"DYNAMIC"})
 * @package iMSCP\Model
 */
class ServerTraffic
{

    /**
     * @ORM\Id
     * @ORM\Column(type="datetime_immutable")
     * @var \DateTimeImmutable
     */
    private $trafficTime;

    /**
     * @ORM\Id
     * @ORM\ManyToOne(targetEntity="Server"))
     * @ORM\JoinColumn(name="serverID", referencedColumnName="serverID")
     * @var Server
     */
    private $server;

    /**
     * @ORM\Column(type="bigint"))
     * @var 
     */
    private $bytesIn;
    private $bytesOut;
    private $bytesMailIn;
    private $bytesMailOut;
    private $bytesPopIn;
    private $bytesPopOut;
    private $bytesWebIn;
    private $bytesWebOut;
}
